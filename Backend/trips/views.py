from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.generics import ListCreateAPIView, RetrieveUpdateDestroyAPIView
from .models import Trip, TripParticipant
from .serializers import TripSerializer, TripParticipantSerializer

# 1. 여행(Trip) 관련 View
class TripListCreateView(ListCreateAPIView):
    """
    GET: 전체 여행 목록 조회
    POST: 새로운 여행 생성 (시리얼라이저 내부 로직으로 리더가 자동 등록됨)
    """
    queryset = Trip.objects.all().order_by('-created_at')
    serializer_class = TripSerializer

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        if serializer.is_valid():
            # serializer.save() 호출 시 시리얼라이저의 create() 메서드가 실행됨
            trip = serializer.save()
            # 저장된 데이터를 다시 직렬화해서 Flutter로 응답
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


# 2. 참여자(Participant) 관련 View
class ParticipantCreateView(APIView):
    """
    POST: 특정 여행에 새로운 참여자 등록 (나중에 따로 올 때 호출)
    """
    def post(self, request):
        serializer = TripParticipantSerializer(data=request.data)
        if serializer.is_valid():
            # validate()에서 정원 초과/중복 여부를 체크한 뒤 저장
            participant = serializer.save()
            # "OOO님이 참여했습니다"와 같은 응답을 Flutter로 보냄
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


# 3. 여행 상세 및 수정/삭제 View (선택 사항)
class TripDetailView(RetrieveUpdateDestroyAPIView):
    queryset = Trip.objects.all()
    serializer_class = TripSerializer