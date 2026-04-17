from rest_framework import serializers
from .models import ChatRoom

class ChatRoomSerializer(serializers.ModelSerializer):
    trip_id = serializers.IntegerField(write_only=True)
    trip_title = serializers.SerializerMethodField()
    last_message = serializers.SerializerMethodField()
    unread_count = serializers.SerializerMethodField()

    class Meta:
        model = ChatRoom
        fields = [
            'id', 'trip_id', 'trip_title', 'last_message',
            'pinned_notice', 'created_at', 'unread_count'
        ]
        read_only_fields = ['id', 'created_at']

    def get_trip_title(self, obj):
        # Trip 모델의 출발지/목적지 필드명에 맞게 수정하세요 (예: depart_name)
        return f"{obj.trip.depart_name} -> {obj.trip.arrive_name}"

    def get_last_message(self, obj):
        last_msg = obj.messages.order_by('-sent_at').first()
        if last_msg:
            return last_msg.message
        return "채팅방이 생성되었습니다."

    def get_unread_count(self, obj):
        return 0

    def create(self, validated_data):
        return ChatRoom.objects.create(
            trip_id=validated_data['trip_id'],
            pinned_notice=validated_data.get('pinned_notice', "택시 번호 및 만날 위치를 꼭 공유해주세요!")
        )