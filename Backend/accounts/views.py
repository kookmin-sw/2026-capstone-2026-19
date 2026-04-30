from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from django.contrib.auth import authenticate
from .models import User, WithdrawalBlock
from .serializers import SignUpSerializer
from trips.models import TripParticipant
from rest_framework.permissions import IsAuthenticated
from rest_framework.parsers import MultiPartParser, FormParser
from django.utils import timezone
from datetime import timedelta

class SignupView(APIView):
    def post(self, request):
        # 2. View에 들어온 데이터를 Serializer(문지기)에게 넘겨줍니다. [연결 완료!]
        serializer = SignUpSerializer(data=request.data)

        # 3. 문지기가 검사해서 통과하면 (is_valid)
        if serializer.is_valid():
            serializer.save()  # 자동으로 User.objects.create_user()가 실행됨!
            return Response({'success': True, 'message': '회원가입 성공!'})

        # 4. 통과 실패하면 에러 반환
        return Response({'success': False, 'message': serializer.errors})

class LoginView(APIView):
    def post(self, request):
        # Flutter에서 '아이디'를 username 키로 보냅니다.
        username = request.data.get('username')
        password = request.data.get('password')

        # 1 & 2. 유저 탐색 + 비밀번호 검증 (Django 내장 authenticate 사용)
        # authenticate는 모델의 USERNAME_FIELD(여기선 username)와 password를 안전하게 검증해 줍니다.
        user = authenticate(username=username, password=password)

        if user is not None:
            return Response({
                'success': True,
                'token': 'this-is-a-fake-test-token-12345',
                'username': user.username  # 로그인한 유저의 아이디 반환
            }, status=status.HTTP_200_OK)
        else:
            return Response({
                'success': False,
                'message': '아이디 또는 비밀번호가 틀렸습니다.'
            }, status=status.HTTP_401_UNAUTHORIZED)


# --- SendCodeView, VerifyCodeView는 기존과 동일하게 유지 ---
class SendCodeView(APIView):
    def post(self, request):
        print(f"인증번호 발송 요청: {request.data.get('phone')}")
        return Response({'success': True})

class VerifyCodeView(APIView):
    def post(self, request):
        return Response({'success': True})


class ProfileImageUpdateView(APIView):
    permission_classes = [IsAuthenticated]
    parser_classes = (MultiPartParser, FormParser)

    def post(self, request):
        user = request.user
        if 'profile_image' in request.FILES:
            user.profile_img_url = request.FILES['profile_image']
            user.save()
            return Response({"message": "Profile image updated successfully"}, status=status.HTTP_200_OK)
        return Response({"error": "No image provided"}, status=status.HTTP_400_BAD_REQUEST)


class TripHistoryView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        participants = TripParticipant.objects.filter(user=request.user).select_related('trip').order_by(
            '-trip__depart_time')
        history_data = []
        for p in participants:
            trip = p.trip
            members_count = TripParticipant.objects.filter(trip=trip, status='JOINED').count()
            my_fare = int(trip.estimated_fare / members_count) if members_count > 0 else 0
            history_data.append({
                "date": trip.depart_time.strftime("%Y.%m.%d"),
                "status": trip.status,
                "team": f"{trip.depart_name} -> {trip.arrive_name}",
                "dept": trip.depart_name,
                "dest": trip.arrive_name,
                "members": members_count,
                "total": trip.estimated_fare,
                "my": my_fare,
            })
        return Response(history_data, status=status.HTTP_200_OK)


class RecentCompanionsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        my_trip_ids = TripParticipant.objects.filter(user=request.user).values_list('trip_id', flat=True)
        companions = TripParticipant.objects.filter(trip_id__in=my_trip_ids).exclude(user=request.user).select_related(
            'user', 'trip').order_by('-trip__depart_time')

        companion_data = []
        seen_user_ids = set()
        for c in companions:
            if c.user.id not in seen_user_ids:
                seen_user_ids.add(c.user.id)
                companion_data.append({
                    "id": str(c.user.id),
                    "nickname": c.user.nickname,
                    "ride_date": c.trip.depart_time.strftime("%Y.%m.%d"),
                    "route": f"{c.trip.depart_name} -> {c.trip.arrive_name}",
                    "profile_image": str(c.user.profile_img_url) if c.user.profile_img_url else ""
                })
        return Response(companion_data, status=status.HTTP_200_OK)


class WithdrawView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user = request.user
        reason = request.data.get('reason', '자진 탈퇴')
        is_blocked = False

        if user.trust_score < 3.0 or user.penalty_points > 0:
            is_blocked = True
            blocked_until = timezone.now() + timedelta(days=365)
            WithdrawalBlock.objects.create(
                withdrawn_user=user, phone_number=user.phone_number,
                blocked_until=blocked_until, trust_score_at_withdrawal=user.trust_score,
                reason=reason, status='BLOCKED'
            )

        user.is_active = False
        user.save()
        return Response({
            "is_blocked": is_blocked,
            "message": "탈퇴 처리가 완료되었습니다." if not is_blocked else "탈퇴 완료 (1년 재가입 제한)"
        }, status=status.HTTP_200_OK)