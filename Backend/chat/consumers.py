# chat/consumers.py
import json
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async

class ChatConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        # URL에서 trip_id를 가져옵니다 (예: ws/chat/<trip_id>/)
        self.trip_id = self.scope['url_route']['kwargs']['trip_id']
        # 매 탑승 세션마다 독립된 그룹 이름을 생성합니다.
        self.room_group_name = f'chat_{self.trip_id}'

        # Redis 채널 레이어 그룹에 합류
        await self.channel_layer.group_add(
            self.room_group_name,
            self.channel_name
        )

        # 웹소켓 연결 승인
        await self.accept()

    async def disconnect(self, close_code):
        # 연결 종료 시 그룹에서 탈퇴
        await self.channel_layer.group_discard(
            self.room_group_name,
            self.channel_name
        )

    # 클라이언트(Flutter)로부터 메시지를 받았을 때
    async def receive(self, text_data):
        text_data_json = json.loads(text_data)
        message = text_data_json['message']
        sender = self.scope['user'].nickname if self.scope['user'].is_authenticated else "익명"

        # 같은 그룹(동일한 trip_id를 가진 사람들) 전체에 메시지 전송
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                'type': 'chat_message',
                'message': message,
                'sender': sender
            }
        )

    # Redis 그룹에서 메시지를 보낼 때 호출되는 메서드
    async def chat_message(self, event):
        message = event['message']
        sender = event['sender']

        # 실제 웹소켓을 통해 프론트엔드로 전달
        await self.send(text_data=json.dumps({
            'message': message,
            'sender': sender
        }))