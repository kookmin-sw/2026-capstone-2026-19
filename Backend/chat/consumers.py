# chat/consumers.py
import json
from channels.generic.websocket import AsyncWebsocketConsumer


class ChatConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.room_id = self.scope["url_route"]["kwargs"]["trip_id"]
        self.room_group_name = f"chat_{self.room_id}"

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

    async def receive(self, text_data):
        data = json.loads(text_data)

        message_type = data.get("type", "chat_message")
        sender = (
            self.scope["user"].nickname
            if self.scope["user"].is_authenticated
            else "익명"
        )

        if message_type == "settlement_request":
            await self.channel_layer.group_send(
                self.room_group_name,
                {
                    "type": "broadcast_message",
                    "message_type": "settlement_request",
                    "sender": sender,
                    "settlement": data.get("settlement"),
                    "message": data.get("message", "정산 요청이 도착했습니다."),
                },
            )
            return

        await self.channel_layer.group_send(
            self.room_group_name,
            {
                "type": "broadcast_message",
                "message_type": "chat_message",
                "message": data.get("message", ""),
                "sender": sender,
            },
        )

    async def broadcast_message(self, event):
        await self.send(
            text_data=json.dumps(
                {
                    "type": event.get("message_type", "chat_message"),
                    "message": event.get("message", ""),
                    "sender": event.get("sender", "익명"),
                    "settlement": event.get("settlement"),
                },
                ensure_ascii=False,
            )
        )