from django.urls import path
# 1. views.py에 정의된 정확한 클래스 이름(TripCreateListView)을 가져옵니다.
from .views import TripCreateListView

urlpatterns = [

    path('', TripCreateListView.as_view(), name='trip-list-create'),


    # 기능을 구현한 후에 하나씩 주석을 풀고 views.py에서 import 하세요!
    # path('<int:pk>/', TripDetailView.as_view(), name='trip-detail'),
    # path('participants/', ParticipantCreateView.as_view(), name='participant-create'),
]