from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from .models import User

class SignupView(APIView):
    def post(self, request):
        data = request.data

        try:
            # 1. 중복 검사 (아이디, 전화번호 등)
            if User.objects.filter(username=data['username']).exists():
                return Response({'success': False, 'message': '이미 사용 중인 아이디입니다.'}, status=status.HTTP_400_BAD_REQUEST)

            # 2. 유저 생성 (비밀번호 암호화를 위해 create_user 사용 필수!)
            user = User.objects.create_user(
                username=data['username'],
                password=data['password'],
                nickname=data['nickname'], # 플러터에서 넘겨준 name이 여기로 들어옴
                phone_number=data['phone_number'],
                gender=data['gender']
            )

            return Response({'success': True, 'message': '회원가입 성공!'}, status=status.HTTP_201_CREATED)

        except Exception as e:
            return Response({'success': False, 'message': str(e)}, status=status.HTTP_400_BAD_REQUEST)

# 인증번호 전송/확인은 지금은 간단히 성공 메시지만 보내도록 틀만 잡아두세요.
class SendCodeView(APIView):
    def post(self, request):
        # 실제로는 여기서 SMS 발송 로직이 들어갑니다.
        print(f"인증번호 발송 요청: {request.data.get('phone')}")
        return Response({'success': True})

class VerifyCodeView(APIView):
    def post(self, request):
        # 실제로는 DB에 저장된 번호와 비교합니다.
        return Response({'success': True})