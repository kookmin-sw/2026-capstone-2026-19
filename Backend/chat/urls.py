from django.urls import path
# 1. 뷰 파일(views.py)에 실제 있는 이름인 'ChatRoomListCreateView'를 가져와야 합니다.
from .views import ChatRoomListCreateView

urlpatterns = [
    # 2. 가져온 이름과 똑같은 이름을 여기서 사용합니다.
    path('', ChatRoomListCreateView.as_view(), name='chat-room-create'),
]