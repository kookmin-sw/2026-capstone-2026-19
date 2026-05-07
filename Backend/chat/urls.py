from django.urls import path
from .views import ChatRoomListCreateView, ChatRoomMessageListView

urlpatterns = [
    path('chat/rooms/', ChatRoomListCreateView.as_view(), name='chat-room-list-create'),
    path('chat/rooms/<int:room_id>/messages/', ChatRoomMessageListView.as_view(), name='chat-room-message-list'),
]