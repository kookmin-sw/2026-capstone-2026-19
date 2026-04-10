from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from django.contrib.auth import authenticate
from .models import User

class SignupView(APIView):
    def post(self, request):
        data = request.data

        try:
            # 1. 중복 검사 (아이디가 nickname 필드에 있으므로 nickname으로 중복 체크!)
            if User.objects.filter(nickname=data['nickname']).exists():
                return Response({
                    'success': False,
                    'message': '이미 사용 중인 아이디입니다.'
                }, status=status.HTTP_400_BAD_REQUEST)

            # 2. 유저 생성
            # Flutter에서 username 자리에 '이름'을, nickname 자리에 '아이디'를 보냈습니다.
            user = User.objects.create_user(
                username=data['username'],      # 여기에는 '실명'이 저장됨
                nickname=data['nickname'],      # 여기에는 '아이디'가 저장됨
                password=data['password'],
                phone_number=data['phone_number'],
                gender=data['gender']
            )

            return Response({'success': True, 'message': '회원가입 성공!'}, status=status.HTTP_201_CREATED)

        except Exception as e:
            return Response({'success': False, 'message': f"오류 발생: {str(e)}"}, status=status.HTTP_400_BAD_REQUEST)


class LoginView(APIView):
    def post(self, request):
        # Flutter에서 '아이디'를 nickname이라는 키로 보냈으므로 여기서도 nickname으로 받습니다.
        nickname = request.data.get('nickname')
        password = request.data.get('password')

        # 1. 아이디(nickname 필드)로 유저를 먼저 찾습니다.
        user = User.objects.filter(nickname=nickname).first()

        # 2. 유저가 존재하고 비밀번호가 맞는지 확인합니다.
        if user and user.check_password(password):
            return Response({
                'success': True,
                'token': 'this-is-a-fake-test-token-12345',
                'nickname': user.nickname  # 로그인한 유저의 '아이디' 반환
            }, status=status.HTTP_200_OK)
        else:
            return Response({
                'success': False,
                'message': '아이디 또는 비밀번호가 틀렸습니다.'
            }, status=status.HTTP_401_UNAUTHORIZED)

# --- 나머지 View (SendCode, VerifyCode)는 동일 ---
class SendCodeView(APIView):
    def post(self, request):
        print(f"인증번호 발송 요청: {request.data.get('phone')}")
        return Response({'success': True})

class VerifyCodeView(APIView):
    def post(self, request):
        return Response({'success': True})