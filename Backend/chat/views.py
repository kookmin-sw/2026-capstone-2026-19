from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from django.db.models import Q
from .models import ChatRoom
from .serializers import ChatRoomSerializer
from trips.models import Trip, TripParticipant


class ChatRoomListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    # 🌟 [변경됨] DB 수정 없이 Trip과의 관계를 이용해 목록 가져오기
    def get(self, request):
        user = request.user

        # 내가 리더인 트립
        leader_trip_ids = Trip.objects.filter(
            leader_user=user
        ).values_list("id", flat=True)

        # 내가 참여 중인 트립
        participant_trip_ids = TripParticipant.objects.filter(
            user=user,
            status="JOINED",
        ).values_list("trip_id", flat=True)

        rooms = ChatRoom.objects.filter(
            Q(trip_id__in=leader_trip_ids) |
            Q(trip_id__in=participant_trip_ids)
        ).distinct().order_by("-created_at")

        serializer = ChatRoomSerializer(rooms, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)

    # 채팅방 개설 (참여자 추가 로직 삭제됨)
    def post(self, request):
        serializer = ChatRoomSerializer(data=request.data)
        if serializer.is_valid():
            chat_room = serializer.save()
            # DB 수정(participants 필드)을 안 하므로, 여기서는 그냥 방만 만듭니다.
            return Response({"id": chat_room.id}, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    
class ChatRoomCreateView(APIView):
    def post(self, request):
        return Response(
            {"message": "Chat room create endpoint is temporarily available."},
            status=status.HTTP_201_CREATED,
        )