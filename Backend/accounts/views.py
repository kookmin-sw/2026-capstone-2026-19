from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from .models import User, WithdrawalBlock
from .serializers import PhoneCheckSerializer, SignUpSerializer


# [POST] /accounts/phonecheck/
class PhoneCheckView(APIView):
    def post(self, request):
        serializer = PhoneCheckSerializer(data=request.data)
        if serializer.is_valid():
            phone = serializer.validated_data['phone_number']

            # 1. 탈퇴 차단 기록 확인
            if WithdrawalBlock.objects.filter(phone_number=phone, status="ACTIVE").exists():
                return Response({
                    "success": False,
                    "message": "재가입이 제한된 번호입니다."
                }, status=status.HTTP_400_BAD_REQUEST)

            # 2. 이미 가입된 유저인지 확인
            if User.objects.filter(phone_number=phone).exists():
                return Response({
                    "success": False,
                    "message": "이미 가입된 번호입니다."
                }, status=status.HTTP_400_BAD_REQUEST)

            return Response({
                "success": True,
                "message": "사용 가능한 번호입니다."
            }, status=status.HTTP_200_OK)

        return Response({"success": False, "message": "데이터 형식이 잘못되었습니다."}, status=status.HTTP_400_BAD_REQUEST)


# [POST] /account/
class SignUpView(APIView):
    def post(self, request):
        serializer = SignUpSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save()  # User 객체 생성
            return Response({
                "success": True,
                "message": "회원가입이 완료되었습니다."
            }, status=status.HTTP_201_CREATED)

        return Response({
            "success": False,
            "message": serializer.errors
        }, status=status.HTTP_400_BAD_REQUEST)