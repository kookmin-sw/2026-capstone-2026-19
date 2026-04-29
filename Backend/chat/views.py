from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from django.db.models import Q
from .models import ChatRoom
from .serializers import ChatRoomSerializer


class ChatRoomListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    # 🌟 [변경됨] DB 수정 없이 Trip과의 관계를 이용해 목록 가져오기
    def get(self, request):
        user = request.user

        # 💡 중요: 여기서는 Trip 모델에서 유저가 참여 중인지 판단하는 기준을 적어야 합니다.
        # 아래는 예시입니다. 본인의 Trip 모델 구조에 맞춰서 필드명을 변경해주세요!
        # 예: 내가 방장(host)이거나, 동승객(passengers) 테이블에 내가 있는 경우
        rooms = ChatRoom.objects.filter(
            Q(trip__host=user) | Q(trip__passengers=user)  # <-- 이 부분을 실제 DB 필드에 맞게 수정!
        ).distinct().order_by('-created_at')

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