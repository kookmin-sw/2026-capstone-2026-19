from rest_framework import serializers
from .models import Trip, TripParticipant

class TripParticipantSerializer(serializers.ModelSerializer):
    nickname = serializers.ReadOnlyField(source='user.nickname')

    class Meta:
        model = TripParticipant
        fields = ['user', 'nickname', 'role', 'seat_position', 'status']

class TripSerializer(serializers.ModelSerializer):
    current_count = serializers.SerializerMethodField()
    # 참여자 상세 정보도 같이 보고 싶을 때 사용
    participants = TripParticipantSerializer(source='trip_participants', many=True, read_only=True)

    class Meta:
        model = Trip
        fields = [
            'id', 'depart_name', 'depart_lat', 'depart_lng',
            'arrive_name', 'arrive_lat', 'arrive_lng',
            'depart_time', 'capacity', 'status', 'estimated_fare',
            'current_count', 'participants'
        ]

    def get_current_count(self, obj):
        # JOINED 상태인 멤버만 카운트
        return obj.trip_participants.filter(status="JOINED").count()