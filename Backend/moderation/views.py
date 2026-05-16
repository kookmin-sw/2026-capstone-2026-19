from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework import status
import re
from trips.models import Trip, TripParticipant

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

    ALLOWED_REASONS = {
        "노쇼",
        "정산 지연",
        "비매너 행위",
        "부적절한 채팅",
        "허위 정보 또는 허위 정산",
        "기타",
    }

    DANGEROUS_PATTERNS = [
        r"<\s*script",
        r"<\s*/\s*script",
        r"<\s*iframe",
        r"<\s*object",
        r"<\s*embed",
        r"<\s*link",
        r"<\s*meta",
        r"javascript\s*:",
        r"on\w+\s*=",
        r"data\s*:",
    ]

    def _contains_dangerous_text(self, text):
        if not text:
            return False

        if re.search(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]", text):
            return True

        lowered = text.lower()
        return any(re.search(pattern, lowered, re.IGNORECASE) for pattern in self.DANGEROUS_PATTERNS)

    def _normalize_reasons(self, request):
        raw_reasons = request.data.get("reasons")

        if isinstance(raw_reasons, list):
            reasons = [str(reason).strip() for reason in raw_reasons if str(reason).strip()]
        else:
            raw_reason = str(request.data.get("reason", "")).strip()
            reasons = [reason.strip() for reason in raw_reason.split(",") if reason.strip()]

        return reasons

    def post(self, request):
        target_id = request.data.get("target_id")
        trip_id = request.data.get("trip_id")
        reasons = self._normalize_reasons(request)
        detail = str(request.data.get("detail", "")).strip()

        if not target_id or not trip_id:
            return Response(
                {"success": False, "message": "신고 대상과 여정 정보가 필요합니다."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if not reasons:
            return Response(
                {"success": False, "message": "신고 사유를 선택해주세요."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        invalid_reasons = [reason for reason in reasons if reason not in self.ALLOWED_REASONS]
        if invalid_reasons:
            return Response(
                {"success": False, "message": "올바르지 않은 신고 사유가 포함되어 있습니다."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if "기타" in reasons:
            if not detail:
                return Response(
                    {"success": False, "message": "기타 신고 사유를 작성해주세요."},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            if len(detail) > 500:
                return Response(
                    {"success": False, "message": "기타 신고 사유는 500자 이내로 작성해주세요."},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            if self._contains_dangerous_text(detail):
                return Response(
                    {"success": False, "message": "허용되지 않는 문자가 포함되어 있습니다."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
        else:
            detail = ""

        trip = Trip.objects.filter(id=trip_id).first()
        if not trip:
            return Response(
                {"success": False, "message": "존재하지 않는 여정입니다."},
                status=status.HTTP_404_NOT_FOUND,
            )

        reporter_participated = TripParticipant.objects.filter(
            trip=trip,
            user=request.user,
        ).exists()

        if not reporter_participated:
            return Response(
                {"success": False, "message": "참여한 여정의 이용자만 신고할 수 있습니다."},
                status=status.HTTP_403_FORBIDDEN,
            )

        target_participated = TripParticipant.objects.filter(
            trip=trip,
            user_id=target_id,
        ).exclude(
            user=request.user,
        ).exists()

        if not target_participated:
            return Response(
                {"success": False, "message": "해당 여정의 동승자만 신고할 수 있습니다."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        reason_text = ", ".join(reasons)

        if len(reason_text) > 50:
            detail = f"선택 사유: {reason_text}\n{detail}".strip()
            reason_text = "복수 신고 사유"

        Report.objects.create(
            reporter_user=request.user,
            reported_user_id=target_id,
            trip=trip,
            reason=reason_text,
            detail=detail,
            status="OPEN",
        )

        return Response(
            {"success": True, "message": "신고가 성공적으로 접수되었습니다."},
            status=status.HTTP_201_CREATED,
        )