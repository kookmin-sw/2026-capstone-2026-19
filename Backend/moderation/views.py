from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework import status

# 모델 임포트
from .models import TrustScoreLog, Report

class TrustScoreLogView(APIView):
    permission_classes = [IsAuthenticated]
    def get(self, request):
        logs = TrustScoreLog.objects.filter(user=request.user).order_by('-created_at')
        log_data = []
        for log in logs:
            sign = "+" if log.direction == "GAIN" else "-"
            log_data.append({
                "event_type": log.event_type,
                "direction": log.direction,
                "applied_delta": f"{sign}{log.applied_delta}",
                "reason_detail": log.reason_detail,
                "score_after": log.score_after,
                "created_at": log.created_at.isoformat(),
            })
        return Response(log_data, status=status.HTTP_200_OK)

class ReportUserView(APIView):
    permission_classes = [IsAuthenticated]
    def post(self, request):
        Report.objects.create(
            reporter_user=request.user,
            reported_user_id=request.data.get('target_id'),
            trip_id=request.data.get('trip_id'),
            reason=request.data.get('reason'),
            detail=request.data.get('detail'),
            status='PENDING'
        )
        return Response({"message": "Report submitted successfully"}, status=status.HTTP_201_CREATED)