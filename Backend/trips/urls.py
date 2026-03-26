from django.urls import path
from .views import TripListCreateView, ParticipantCreateView, TripDetailView

urlpatterns = [
    # 여행 생성 및 목록 조회
    path('trips/', TripListCreateView.as_view(), name='trip-list-create'),

    # 여행 상세 조회/수정/삭제
    path('trips/<int:pk>/', TripDetailView.as_view(), name='trip-detail'),

    # 나중에 따로 참여자 등록할 때 호출
    path('participants/', ParticipantCreateView.as_view(), name='participant-create'),
]