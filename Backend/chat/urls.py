from django.urls import path
from .views import ChatRoomListCreateView, ChatRoomMessageListView, ChatImageMessageCreateView

urlpatterns = [
    path('chat/rooms/', ChatRoomListCreateView.as_view(), name='chat-room-list-create'),
    path('chat/rooms/<int:room_id>/messages/', ChatRoomMessageListView.as_view(), name='chat-room-message-list'),
    path("chat/rooms/<int:room_id>/images/", ChatImageMessageCreateView.as_view(), name="chat-image-message-create"),
]