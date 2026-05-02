from django.urls import path
from .views import ChatRoomListCreateView

urlpatterns = [
    path('chat/rooms/', ChatRoomListCreateView.as_view(), name='chat-room-list-create'),
]