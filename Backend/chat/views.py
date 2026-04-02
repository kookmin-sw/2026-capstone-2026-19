from django import db
from django.http import JsonResponse
from rest_framework.decorators import api_view
from .models import ChatRoom
from trips.models import Trip


@api_view(['POST'])
def create_new_chatroom(request):
    trip_id = request.data.get('trip_id')

    try:
        trip = Trip.objects.get(id=trip_id)

        # 1. 기존에 이 Trip에 연결된 방이 있다면 삭제 (항상 새로 만들기 위해)
        ChatRoom.objects.filter(trip=trip).delete()

        # 2. 새 방 생성
        room = ChatRoom.objects.create(trip=trip)

        # 3. Flutter에게 필요한 최소한의 정보 전달
        return JsonResponse({
            'status': 'success',
            'room_id': room.id,
            'trip_id': trip.id,
            # Flutter가 이 주소로 바로 WebSocket 연결을 시도함
            'ws_url': f"ws://your-server-domain/ws/chat/{trip.id}/"
        })

    except Trip.DoesNotExist:
        return JsonResponse({'error': '해당 여행 정보가 없습니다.'}, status=404)