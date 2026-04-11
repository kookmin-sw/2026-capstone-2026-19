from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from django.contrib.auth import authenticate
from .models import User
from .serializers import SignUpSerializer

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