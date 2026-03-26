from rest_framework import serializers
from django.db import transaction
from .models import Trip, TripParticipant


# 1. 참여자용 시리얼라이저 (상세 정보 포함)
class TripParticipantSerializer(serializers.ModelSerializer):
    user_name = serializers.ReadOnlyField(source='user.username')
    joined_at = serializers.DateTimeField(format="%Y-%m-%d %H:%M:%S", read_only=True)

    class Meta:
        model = TripParticipant
        fields = [
            'id', 'trip', 'user', 'user_name',
            'role', 'status', 'joined_at'
        ]
        read_only_fields = ['id', 'joined_at']

    def validate(self, data):
        """비즈니스 로직 검증"""
        trip = data['trip']
        user = data['user']

        # 1. 정원 초과 확인
        if trip.trip_participants.filter(status='JOINED').count() >= trip.capacity:
            raise serializers.ValidationError("이 여행은 이미 정원이 초과되었습니다.")

        # 2. 이미 참여 중인지 확인 (UniqueConstraint가 모델에 있지만, 여기서 에러 메시지 커스텀 가능)
        if TripParticipant.objects.filter(trip=trip, user=user).exists():
            raise serializers.ValidationError("이미 이 여행에 참여하고 있습니다.")

        return data


# 2. 여행 생성 및 전체 조회용 시리얼라이저
class TripSerializer(serializers.ModelSerializer):
    created_at = serializers.DateTimeField(format="%Y-%m-%d %H:%M:%S", read_only=True)
    # 현재 참여자 목록을 상세히 보고 싶을 때 사용
    participants = TripParticipantSerializer(source='trip_participants', many=True, read_only=True)

    class Meta:
        model = Trip
        fields = '__all__'
        read_only_fields = ['id', 'created_at']

    def create(self, validated_data):
        """여행 생성 시 리더를 참여자 테이블에 즉시 등록"""
        with transaction.atomic():
            # 여행 정보 생성
            trip = Trip.objects.create(**validated_data)

            # 리더(생성자) 정보 등록
            TripParticipant.objects.create(
                trip=trip,
                user=validated_data['leader_user'],
                role='LEADER',
                status='JOINED'
            )
            return trip