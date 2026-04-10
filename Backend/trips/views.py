from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status, permissions
from django.db import transaction
from .models import Trip, TripParticipant
from .serializers import TripSerializer


class TripCreateListView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    # 좌석 이름 매핑 사전 (Flutter -> Django Model)
    SEAT_MAP = {
        '조수석': TripParticipant.SeatChoices.FRONT_PASSENGER,
        '왼쪽 창가': TripParticipant.SeatChoices.REAR_LEFT,
        '가운데': TripParticipant.SeatChoices.REAR_MIDDLE,
        '오른쪽 창가': TripParticipant.SeatChoices.REAR_RIGHT,
    }

    def get(self, request):
        # 열려있는 핀 목록만 조회
        trips = Trip.objects.filter(status=Trip.StatusChoices.OPEN).order_by('-created_at')
        serializer = TripSerializer(trips, many=True)
        return Response(serializer.data)

    def post(self, request):
        data = request.data
        flutter_seat = data.get('seat_position')

        # 1. 좌석 매핑 확인
        django_seat = self.SEAT_MAP.get(flutter_seat)
        if not django_seat:
            return Response({'message': '올바른 좌석을 선택해주세요.'}, status=status.HTTP_400_BAD_REQUEST)

        # 2. 트랜잭션 처리 (Trip 생성과 Participant 생성을 한 번에)
        try:
            with transaction.atomic():
                # Trip 생성 (creator와 leader를 현재 유저로 설정)
                serializer = TripSerializer(data=data)
                if serializer.is_valid():
                    trip = serializer.save(
                        creator_user=request.user,
                        leader_user=request.user
                    )

                    # 호스트를 참여자로 등록
                    TripParticipant.objects.create(
                        trip=trip,
                        user=request.user,
                        role=TripParticipant.RoleChoices.LEADER,
                        seat_position=django_seat,
                        status=TripParticipant.StatusChoices.JOINED
                    )

                    return Response(serializer.data, status=status.HTTP_201_CREATED)
                return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        except Exception as e:
            return Response({'message': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)