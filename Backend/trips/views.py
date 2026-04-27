from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status, permissions
from django.db import transaction
from .models import Trip, TripParticipant
from .serializers import TripSerializer


class TripCreateListView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    # 좌석 이름 매핑 사전 (Flutter -> Django Model)
    SEAT_MAP = {
        '조수석': TripParticipant.SeatChoices.FRONT_PASSENGER,
        '왼쪽 창가': TripParticipant.SeatChoices.REAR_LEFT,
        '가운데': TripParticipant.SeatChoices.REAR_MIDDLE,
        '오른쪽 창가': TripParticipant.SeatChoices.REAR_RIGHT,
    }

    def get(self, request):
        # 열려있는 핀 목록만 조회
        trips = Trip.objects.filter(status=Trip.StatusChoices.OPEN).order_by('-created_at')
        serializer = TripSerializer(trips, many=True)
        return Response(serializer.data)

    def post(self, request):
        data = request.data
        flutter_seat = data.get('seat_position')

        # 1. 좌석 매핑 확인
        django_seat = self.SEAT_MAP.get(flutter_seat)
        if not django_seat:
            return Response({'message': '올바른 좌석을 선택해주세요.'}, status=status.HTTP_400_BAD_REQUEST)

        # 2. 트랜잭션 처리 (Trip 생성과 Participant 생성을 한 번에)
        try:
            with transaction.atomic():
                # Trip 생성 (creator와 leader를 현재 유저로 설정)
                serializer = TripSerializer(data=data)
                if serializer.is_valid():
                    trip = serializer.save(
                        creator_user=request.user,
                        leader_user=request.user
                    )

                    # 호스트를 참여자로 등록
                    TripParticipant.objects.create(
                        trip=trip,
                        user=request.user,
                        role=TripParticipant.RoleChoices.LEADER,
                        seat_position=django_seat,
                        status=TripParticipant.StatusChoices.JOINED
                    )

                    return Response(serializer.data, status=status.HTTP_201_CREATED)
                return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        except Exception as e:
            return Response({'message': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class TripJoinView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    # 좌석 이름 매핑 사전 (생성 View와 동일하게 유지)
    SEAT_MAP = {
        '조수석': TripParticipant.SeatChoices.FRONT_PASSENGER,
        '왼쪽 창가': TripParticipant.SeatChoices.REAR_LEFT,
        '가운데': TripParticipant.SeatChoices.REAR_MIDDLE,
        '오른쪽 창가': TripParticipant.SeatChoices.REAR_RIGHT,
    }

    def post(self, request, pk):
        try:
            trip = Trip.objects.get(pk=pk)
        except Trip.DoesNotExist:
            return Response({"message": "존재하지 않는 핀입니다."}, status=status.HTTP_404_NOT_FOUND)

        # 🌟 1. 현재 참여 인원 계산 (시리얼라이저의 get_current_count 로직과 동일하게)
        current_joined_count = trip.trip_participants.filter(status="JOINED").count()

        # 2. 핀 상태 및 정원 검사
        if trip.status != Trip.StatusChoices.OPEN:
            return Response({"message": "이미 마감되거나 취소된 팀입니다."}, status=status.HTTP_400_BAD_REQUEST)

        if current_joined_count >= trip.capacity:
            return Response({"message": "정원이 모두 찼습니다."}, status=status.HTTP_400_BAD_REQUEST)

        # 3. 이미 참여 중인지 확인
        if TripParticipant.objects.filter(trip=trip, user=request.user).exists():
            return Response({"message": "이미 참여 중인 팀입니다."}, status=status.HTTP_400_BAD_REQUEST)

        # 4. 좌석 매핑 및 중복 검사
        flutter_seat = request.data.get('seat_position')
        django_seat = self.SEAT_MAP.get(flutter_seat)

        if not django_seat:
            return Response({'message': '올바른 좌석을 선택해주세요.'}, status=status.HTTP_400_BAD_REQUEST)

        if TripParticipant.objects.filter(trip=trip, seat_position=django_seat, status="JOINED").exists():
            return Response({'message': '이미 선택된 좌석입니다. 다른 좌석을 선택해주세요.'}, status=status.HTTP_400_BAD_REQUEST)

        # 5. 트랜잭션으로 참여자 등록
        try:
            with transaction.atomic():
                # 참여자 등록 (일반 탑승객: PASSENGER)
                TripParticipant.objects.create(
                    trip=trip,
                    user=request.user,
                    role=TripParticipant.RoleChoices.PASSENGER,  # 일반 탑승객 역할
                    seat_position=django_seat,
                    status="JOINED"  # 가입 완료 상태
                )

                # 만약 방금 내가 들어가서 정원이 다 찼다면, 핀 상태를 마감(CLOSED)으로 변경
                if (current_joined_count + 1) >= trip.capacity:
                    trip.status = Trip.StatusChoices.CLOSED
                    trip.save()

            return Response({"success": True, "message": "참여가 완료되었습니다."}, status=status.HTTP_200_OK)

        except Exception as e:
            return Response({'message': f'참여 처리 중 오류가 발생했습니다: {str(e)}'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)