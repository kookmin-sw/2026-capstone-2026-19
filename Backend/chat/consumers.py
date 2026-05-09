# chat/consumers.py
import json
from urllib.parse import parse_qs

from asgiref.sync import sync_to_async
from channels.generic.websocket import AsyncWebsocketConsumer
from django.contrib.auth.models import AnonymousUser
from rest_framework.authtoken.models import Token

from .models import ChatRoom, ChatMessage


class ChatConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.trip_id = self.scope["url_route"]["kwargs"]["trip_id"]
        self.room_group_name = f"chat_{self.trip_id}"

        self.user = await self._get_user_from_query_token()

        await self.channel_layer.group_add(
            self.room_group_name,
            self.channel_name,
        )

        await self.accept()

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard(
            self.room_group_name,
            self.channel_name,
        )

    @sync_to_async
    def _get_user_from_query_token(self):
        query_string = self.scope.get("query_string", b"").decode("utf-8")
        query_params = parse_qs(query_string)
        token_key = query_params.get("token", [""])[0]

        if not token_key:
            return AnonymousUser()

        try:
            return Token.objects.select_related("user").get(key=token_key).user
        except Token.DoesNotExist:
            return AnonymousUser()

    @sync_to_async
    def _save_chat_message(self, message):
        if not self.user.is_authenticated:
            return None

        room = ChatRoom.objects.get(trip_id=self.trip_id)

        chat_message = ChatMessage.objects.create(
            room=room,
            sender_user=self.user,
            message=message,
        )

        return {
            "id": chat_message.id,
            "sender_user_id": self.user.id,
            "sender": self.user.username,
            "message": chat_message.message,
            "sent_at": chat_message.sent_at.isoformat(),
        }

    async def receive(self, text_data):
        data = json.loads(text_data)

        message_type = data.get("type", "chat_message")

        sender = (
            self.user.username
            if self.user.is_authenticated
            else "익명"
        )

        if message_type == "settlement_request":
            await self.channel_layer.group_send(
                self.room_group_name,
                {
                    "type": "broadcast_message",
                    "message_type": "settlement_request",
                    "sender": sender,
                    "sender_user_id": self.user.id if self.user.is_authenticated else None,
                    "settlement": data.get("settlement"),
                    "message": data.get("message", "정산 요청이 도착했습니다."),
                },
            )
            return
        
        if message_type == "settlement_completed":
            await self.channel_layer.group_send(
                self.room_group_name,
                {
                    "type": "broadcast_message",
                    "message_type": "settlement_completed",
                    "sender": sender,
                    "sender_user_id": self.user.id if self.user.is_authenticated else None,
                    "message": data.get("message", "정산이 완료되었습니다."),
                    "pinned_notice": data.get("pinned_notice"),
                    "expires_at": data.get("expires_at"),
                },
            )
            return

        message = data.get("message", "")
        saved_message = await self._save_chat_message(message)

        await self.channel_layer.group_send(
            self.room_group_name,
            {
                "type": "broadcast_message",
                "message_type": "chat_message",
                "message": message,
                "sender": sender,
                "sender_user_id": self.user.id if self.user.is_authenticated else None,
                "message_id": saved_message["id"] if saved_message else None,
                "sent_at": saved_message["sent_at"] if saved_message else None,
            },
        )

    async def broadcast_message(self, event):
        await self.send(
            text_data=json.dumps(
                {
                    "type": event.get("message_type", "chat_message"),
                    "message": event.get("message", ""),
                    "sender": event.get("sender", "익명"),
                    "sender_user_id": event.get("sender_user_id"),
                    "message_id": event.get("message_id"),
                    "sent_at": event.get("sent_at"),
                    "settlement": event.get("settlement"),
                    "image_url": event.get("image_url"),
                    "pinned_notice": event.get("pinned_notice"),
                    "expires_at": event.get("expires_at"),
                },
                ensure_ascii=False,
            )
        )
