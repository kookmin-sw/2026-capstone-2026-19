from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status, permissions
from django.db import transaction
from .models import Trip, TripParticipant
from .serializers import TripSerializer


class TripCreateListView(APIView):
    permission_classes = [permissions.IsAuthenticated]



    def get(self, request):
        # 열려있는 핀 목록만 조회
        trips = Trip.objects.filter(status=Trip.StatusChoices.OPEN).order_by('-created_at')
        serializer = TripSerializer(trips, many=True, context={'request': request})
        return Response(serializer.data)

    def post(self, request):
        data = request.data
        flutter_seat = data.get('seat_position')

        # 1. 좌석 매핑 확인
        valid_seats = [choice[0] for choice in TripParticipant.SeatChoices.choices]

        if flutter_seat not in valid_seats:
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
                        seat_position=flutter_seat,
                        status=TripParticipant.StatusChoices.JOINED
                    )

                    kakaopay_link = data.get("kakaopay_link")

                    if kakaopay_link:
                        from settlements.models import PaymentChannel

                        PaymentChannel.objects.update_or_create(
                            trip=trip,
                            defaults={
                                "provider": "KAKAOPAY",
                                "kakaopay_link": kakaopay_link,
                                "updated_by": request.user,
                            },
                        )

                    return Response(serializer.data, status=status.HTTP_201_CREATED)
                return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        except Exception as e:
            return Response({'message': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class TripJoinView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        try:
            trip = Trip.objects.get(pk=pk)
        except Trip.DoesNotExist:
            return Response({"message": "존재하지 않는 핀입니다."}, status=status.HTTP_404_NOT_FOUND)

        # 🌟 1. 현재 참여 인원 계산 (시리얼라이저의 get_current_count 로직과 동일하게)
        current_joined_count = trip.trip_participants.filter(status="JOINED").count()

        # 2. 핀 상태 및 정원 검사
        if trip.status != Trip.StatusChoices.OPEN:
            return Response({"message": "이미 마감되거나 취소된 팀입니다."}, status=status.HTTP_400_BAD_REQUEST)

        if current_joined_count >= trip.capacity:
            return Response({"message": "정원이 모두 찼습니다."}, status=status.HTTP_400_BAD_REQUEST)

        # 3. 이미 참여 중인지 확인
        if TripParticipant.objects.filter(trip=trip, user=request.user).exists():
            return Response({"message": "이미 참여 중인 팀입니다."}, status=status.HTTP_400_BAD_REQUEST)

        # 4. 좌석 매핑 및 중복 검사
        flutter_seat = request.data.get('seat_position')
        django_seat = self.SEAT_MAP.get(flutter_seat)

        if not django_seat:
            return Response({'message': '올바른 좌석을 선택해주세요.'}, status=status.HTTP_400_BAD_REQUEST)

        if TripParticipant.objects.filter(trip=trip, seat_position=django_seat, status="JOINED").exists():
            return Response({'message': '이미 선택된 좌석입니다. 다른 좌석을 선택해주세요.'}, status=status.HTTP_400_BAD_REQUEST)

        # 5. 트랜잭션으로 참여자 등록
        try:
            with transaction.atomic():
                # 참여자 등록 (일반 탑승객: PASSENGER)
                TripParticipant.objects.create(
                    trip=trip,
                    user=request.user,
                    role=TripParticipant.RoleChoices.MEMBER,  # 일반 탑승객 역할
                    seat_position=django_seat,
                    status=TripParticipant.StatusChoices.JOINED  # 가입 완료 상태
                )

                # 만약 방금 내가 들어가서 정원이 다 찼다면, 핀 상태를 마감(CLOSED)으로 변경
                if (current_joined_count + 1) >= trip.capacity:
                    trip.status = Trip.StatusChoices.CLOSED
                    trip.save()

            return Response({"success": True, "message": "참여가 완료되었습니다."}, status=status.HTTP_200_OK)

        except Exception as e:
            return Response({'message': f'참여 처리 중 오류가 발생했습니다: {str(e)}'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

class MyTripListView(APIView):
    """내가 방장이거나, 멤버로 참여 중인 모든 동승 내역 조회"""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        # 현재 로그인한 유저가 'JOINED' 상태로 포함된 모든 트립
        trips = Trip.objects.filter(
            trip_participants__user=request.user,
            trip_participants__status=TripParticipant.StatusChoices.JOINED
        ).distinct().order_by('-depart_time')

        serializer = TripSerializer(trips, many=True, context={'request': request})
        return Response(serializer.data, status=status.HTTP_200_OK)

class TripStatusUpdateView(APIView):
    """방장이 동승의 상태를 변경하거나 핀을 삭제함"""
    permission_classes = [permissions.IsAuthenticated]

    # 1. 상태 변경 (PATCH) - service.dart의 updateTripStatus와 연결
    def patch(self, request, pk):
        try:
            trip = Trip.objects.get(pk=pk)
        except Trip.DoesNotExist:
            return Response({"message": "존재하지 않는 핀입니다."}, status=status.HTTP_404_NOT_FOUND)

        # 권한 확인: 방장만 상태 변경 가능
        if trip.leader_user != request.user:
            return Response({"message": "상태 변경 권한이 없습니다."}, status=status.HTTP_403_FORBIDDEN)

        new_status = request.data.get('status')

        # 모델의 StatusChoices에 정의된 값인지 확인
        valid_statuses = [choice[0] for choice in Trip.StatusChoices.choices]

        if new_status in valid_statuses:
            trip.status = new_status
            trip.save()
            return Response({"success": True, "status": trip.status}, status=status.HTTP_200_OK)

        return Response({"message": "잘못된 상태 값입니다."}, status=status.HTTP_400_BAD_REQUEST)

    # 2. 📍 핀 삭제 (DELETE) - service.dart의 deleteTrip과 연결되도록 추가됨!
    def delete(self, request, pk):
        try:
            trip = Trip.objects.get(pk=pk)
        except Trip.DoesNotExist:
            return Response({"message": "존재하지 않는 핀입니다."}, status=status.HTTP_404_NOT_FOUND)

        # 권한 확인: 방장만 삭제 가능
        if trip.leader_user != request.user:
            return Response({"message": "삭제 권한이 없습니다."}, status=status.HTTP_403_FORBIDDEN)

        # 핀(방) 삭제
        trip.delete()
        # 성공 시 204 No Content 반환 (service.dart에서 이 코드를 기다림)
        return Response(status=status.HTTP_204_NO_CONTENT)