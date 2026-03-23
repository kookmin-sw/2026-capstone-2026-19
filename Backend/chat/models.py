from django.conf import settings
from django.db import models

from trips.models import Trip


class ChatRoom(models.Model):
    trip = models.OneToOneField(
        Trip,
        on_delete=models.CASCADE,
        related_name="chat_room",
    )
    pinned_notice = models.TextField(
        blank=True,
        null=True,
        default="택시 번호 및 만날 위치를 공유해주세요!",
    )
    created_at = models.DateTimeField(auto_now_add=True)

    expires_at = models.DateTimeField(blank=True, null=True)
    is_archived = models.BooleanField(default=False)
    
    def __str__(self):
        return f"ChatRoom for Trip {self.trip_id}"


class ChatMessage(models.Model):
    room = models.ForeignKey(
        ChatRoom,
        on_delete=models.CASCADE,
        related_name="messages",
    )
    sender_user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="chat_messages_sent",
    )
    message = models.TextField()
    sent_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Message {self.id} in Room {self.room_id}"