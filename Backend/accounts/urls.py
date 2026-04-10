from django.urls import path
# views.py에서 실제로 만든 4개의 클래스만 가져옵니다.
from .views import SignupView, LoginView, SendCodeView, VerifyCodeView

urlpatterns = [
    # 1. 회원가입 및 본인인증 관련
    path('signup/', SignupView.as_view(), name='signup'),
    path('send-code/', SendCodeView.as_view(), name='send_code'),
    path('verify-code/', VerifyCodeView.as_view(), name='verify_code'),

    # 2. 로그인
    path('login/', LoginView.as_view(), name='login'),
]