# accounts/urls.py
from django.contrib.auth.views import LoginView, LogoutView
from django.urls import path
from .views import SignupView

urlpatterns = [
    # 회원가입
    path('send-code/', SendCodeView.as_view(), name='send_code'),
    path('verify-code/', VerifyCodeView.as_view(), name='verify_code'),
    path('signup/', SignupView.as_view(), name='signup'),
    # 로그인
    path("login/", LoginView.as_view(), name="login"),
    # 로그아웃
    path("logout/", LogoutView.as_view(), name="logout"),
    # 토큰 재발급
    path("refresh/", TokenRefreshView.as_view(), name="token_refresh"),
    # 현재 사용자 정보
    path("me/", MeView.as_view(), name="me"),
    # 이메일 인증
    path("email/send-code/", SendEmailCodeView.as_view(), name="send_email_code"),

    path("email/verify-code/", VerifyEmailCodeView.as_view(), name="verify_email_code"),

    path("password/reset/", PasswordResetView.as_view()),

    path("password/reset-confirm/", PasswordResetConfirmView.as_view()),

]