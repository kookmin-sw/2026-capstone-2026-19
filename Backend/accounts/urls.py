from django.urls import path
from .views import SignupView, LoginView, IssueCodeView, VerifyCodeView
from . import views

urlpatterns = [
    # 1. 회원가입 및 OCTOMO 본인인증 관련
    path('signup/', SignupView.as_view(), name='signup'),
    path('issue-code/', IssueCodeView.as_view(), name='issue_code'),
    path('verify-code/', VerifyCodeView.as_view(), name='verify_code'),
    path('profile/image/', views.ProfileImageUpdateView.as_view(), name='update-profile-image'),
    path('history/', views.TripHistoryView.as_view(), name='trip-history'),
    path('recent-companions/', views.RecentCompanionsView.as_view(), name='recent-companions'),
    path('withdraw/', views.WithdrawView.as_view(), name='withdraw'),

    # 2. 로그인
    path('login/', LoginView.as_view(), name='login'),
]