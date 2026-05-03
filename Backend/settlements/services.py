import re

from django.db import transaction
from django.utils import timezone
from rest_framework.exceptions import PermissionDenied, ValidationError

from trips.models import TripParticipant
from .models import PaymentChannel, Receipt, Settlement, SettlementProof
import base64
import json
import mimetypes
import time
import uuid
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from django.conf import settings


def _validate_trip_leader(*, trip, user):
    if trip.leader_user_id != user.id:
        raise PermissionDenied("방장만 수행할 수 있습니다.")


def _validate_trip_participant(*, trip, user):
    exists = TripParticipant.objects.filter(
        trip=trip,
        user=user,
        status="JOINED",
    ).exists()
    if not exists:
        raise PermissionDenied("현재 참가 중인 사용자만 수행할 수 있습니다.")


@transaction.atomic
def upsert_payment_channel(*, trip, user, validated_data):
    _validate_trip_leader(trip=trip, user=user)

    channel, _ = PaymentChannel.objects.update_or_create(
        trip=trip,
        defaults={
            "provider": validated_data.get("provider", "KAKAOPAY"),
            "kakaopay_link": validated_data.get("kakaopay_link"),
            "updated_by": user,
        },
    )
    return channel

def extract_total_amount_from_text(raw_text: str):
    """
    OCR 원문에서 결제 금액 후보를 추출한다.
    MVP에서는 완전한 진위 검증이 아니라 금액 자동 입력 보조 기능으로 사용한다.
    """
    if not raw_text:
        return None

    text = raw_text.replace("\n", " ")

    patterns = [
        r"(?:결제\s*금액|총\s*결제\s*금액|총\s*금액|합계|결제금액|택시요금|운임)[^\d]{0,20}([\d,]{4,})\s*원?",
        r"([\d,]{4,})\s*원",
    ]

    candidates = []

    for pattern in patterns:
        matches = re.findall(pattern, text)
        for match in matches:
            amount = int(match.replace(",", ""))
            if 1000 <= amount <= 300000:
                candidates.append(amount)

    if not candidates:
        return None

    return max(candidates)


def run_ocr_for_receipt(receipt: Receipt) -> str:
    """
    Naver CLOVA OCR API를 호출하여 영수증/이용내역 이미지의 전체 텍스트를 반환한다.
    반환된 원문에서 금액 추출은 extract_total_amount_from_text()가 담당한다.
    """
    ocr_url = getattr(settings, "CLOVA_OCR_URL", "")
    ocr_secret = getattr(settings, "CLOVA_OCR_SECRET", "")

    if not ocr_url or not ocr_secret:
        raise ValidationError("CLOVA OCR URL 또는 Secret Key가 설정되지 않았습니다.")

    if not receipt.image:
        raise ValidationError("현재 CLOVA OCR 테스트는 업로드된 이미지 파일 기준으로 처리합니다.")

    file_name = receipt.image.name
    mime_type, _ = mimetypes.guess_type(file_name)
    image_format = "jpg"

    if mime_type:
        image_format = mime_type.split("/")[-1]
        if image_format == "jpeg":
            image_format = "jpg"

    receipt.image.open("rb")
    try:
        image_bytes = receipt.image.read()
    finally:
        receipt.image.close()

    image_base64 = base64.b64encode(image_bytes).decode("utf-8")

    request_body = {
        "version": "V2",
        "requestId": str(uuid.uuid4()),
        "timestamp": int(time.time() * 1000),
        "images": [
            {
                "format": image_format,
                "name": "receipt",
                "data": image_base64,
            }
        ],
    }

    request_data = json.dumps(request_body).encode("utf-8")

    request = Request(
        ocr_url,
        data=request_data,
        headers={
            "Content-Type": "application/json",
            "X-OCR-SECRET": ocr_secret,
        },
        method="POST",
    )

    try:
        with urlopen(request, timeout=15) as response:
            response_body = response.read().decode("utf-8")
            result = json.loads(response_body)

    except HTTPError as e:
        error_body = e.read().decode("utf-8", errors="ignore")
        raise ValidationError(f"CLOVA OCR 호출 실패: HTTP {e.code} / {error_body}")

    except URLError as e:
        raise ValidationError(f"CLOVA OCR 연결 실패: {e.reason}")

    except Exception as e:
        raise ValidationError(f"CLOVA OCR 처리 중 오류가 발생했습니다: {str(e)}")

    images = result.get("images", [])
    if not images:
        raise ValidationError("CLOVA OCR 응답에 이미지 분석 결과가 없습니다.")

    fields = images[0].get("fields", [])
    texts = [
        field.get("inferText", "")
        for field in fields
        if field.get("inferText")
    ]

    raw_text = " ".join(texts).strip()

    if not raw_text:
        raise ValidationError("CLOVA OCR에서 인식된 텍스트가 없습니다.")

    return raw_text


@transaction.atomic
def analyze_receipt_ocr(*, receipt: Receipt, actor):
    """
    리더가 업로드한 영수증/이용내역 이미지에서 OCR을 실행하고,
    추출된 금액을 receipt.extracted_total_amount에 저장한다.
    """
    trip = receipt.trip
    _validate_trip_leader(trip=trip, user=actor)

    if not receipt.image and not receipt.image_url:
        raise ValidationError("분석할 영수증 이미지가 없습니다.")

    raw_text = run_ocr_for_receipt(receipt)
    extracted_amount = extract_total_amount_from_text(raw_text)

    receipt.ocr_raw_text = raw_text
    receipt.extracted_total_amount = extracted_amount

    if extracted_amount is None:
        receipt.ocr_status = "NEEDS_REVIEW"
    else:
        receipt.ocr_status = "SUCCESS"

    receipt.save(
        update_fields=[
            "ocr_raw_text",
            "extracted_total_amount",
            "ocr_status",
            "updated_at",
        ]
    )

    return receipt

@transaction.atomic
def create_receipt(*, trip, user, validated_data):
    _validate_trip_leader(trip=trip, user=user)

    if hasattr(trip, "receipt"):
        raise ValidationError("이미 영수증이 등록된 트립입니다.")

    receipt = Receipt.objects.create(
        trip=trip,
        uploaded_by=user,
        image=validated_data.get("image"),
        image_url=validated_data.get("image_url"),
        total_amount=validated_data.get("total_amount"),
        ocr_status="PENDING",
        status="PENDING",
    )
    return receipt

@transaction.atomic
def confirm_receipt_amount(*, receipt: Receipt, actor, total_amount: int):
    """
    OCR로 추출된 금액 또는 리더가 수정한 금액을 최종 정산 금액으로 확정한다.
    """
    trip = receipt.trip
    _validate_trip_leader(trip=trip, user=actor)

    if total_amount is None:
        raise ValidationError("최종 결제 금액이 필요합니다.")

    if total_amount < 0:
        raise ValidationError("결제 금액은 0원 이상이어야 합니다.")

    if total_amount > 300000:
        raise ValidationError("택시 요금으로 보기 어려운 금액입니다.")

    receipt.total_amount = total_amount
    receipt.status = "CONFIRMED"
    receipt.confirmed_at = timezone.now()
    receipt.save(
        update_fields=[
            "total_amount",
            "status",
            "confirmed_at",
            "updated_at",
        ]
    )

    return receipt


@transaction.atomic
def create_settlements_for_receipt(*, receipt: Receipt, actor):
    trip = receipt.trip
    _validate_trip_leader(trip=trip, user=actor)

    if receipt.total_amount is None:
        raise ValidationError("최종 결제 금액이 확정되지 않았습니다.")

    if not hasattr(trip, "payment_channel"):
        raise ValidationError("먼저 결제 링크를 등록해야 합니다.")

    participants = list(
        TripParticipant.objects.filter(
            trip=trip,
            status="JOINED",
        ).select_related("user")
    )

    if len(participants) < 2:
        raise ValidationError("정산하려면 최소 2명 이상의 참가자가 필요합니다.")

    payee_user = receipt.uploaded_by
    participant_user_ids = {p.user_id for p in participants}

    if payee_user.id not in participant_user_ids:
        raise ValidationError("영수증 업로더는 현재 참가자여야 합니다.")

    if receipt.settlements.exists():
        raise ValidationError("이미 정산이 생성된 영수증입니다.")

    headcount = len(participants)
    base_amount = receipt.total_amount // headcount
    remainder = receipt.total_amount % headcount

    created = []
    for participant in participants:
        if participant.user_id == payee_user.id:
            continue

        share_amount = base_amount
        if remainder > 0:
            share_amount += 1
            remainder -= 1

        settlement = Settlement.objects.create(
            trip=trip,
            receipt=receipt,
            payer_user=participant.user,
            payee_user=payee_user,
            share_amount=share_amount,
            status="REQUEST",
        )
        created.append(settlement)

    return created

@transaction.atomic
def mark_settlement_link_opened(*, settlement: Settlement, user):
    """
    참여자가 이용내역 확인 체크박스 선택 후 송금 링크를 열었음을 기록한다.
    실제 송금 완료가 아니라 링크 이동 기록만 남긴다.
    """
    if settlement.payer_user_id != user.id:
        raise PermissionDenied("본인 정산만 처리할 수 있습니다.")

    if settlement.status not in ["REQUEST", "LINK_OPENED"]:
        raise ValidationError("현재 송금 링크를 열 수 없는 상태입니다.")

    settlement.status = "LINK_OPENED"
    settlement.link_opened_at = timezone.now()
    settlement.save(update_fields=["status", "link_opened_at"])
    return settlement

@transaction.atomic
def mark_settlement_paid_self(*, settlement: Settlement, user):
    if settlement.payer_user_id != user.id:
        raise PermissionDenied("본인 정산만 송금 완료 처리할 수 있습니다.")

    if settlement.status not in ["REQUEST", "LINK_OPENED"]:
        raise ValidationError("현재 송금 완료 처리할 수 없는 상태입니다.")

    settlement.status = "PAID_SELF"
    settlement.paid_self_at = timezone.now()
    settlement.save(update_fields=["status", "paid_self_at"])
    return settlement


@transaction.atomic
def upload_settlement_proof(*, settlement: Settlement, user, image_url: str):
    if settlement.payer_user_id != user.id:
        raise PermissionDenied("본인 정산에만 증빙을 업로드할 수 있습니다.")

    if settlement.status not in ["REQUEST", "PAID_SELF", "DISPUTED"]:
        raise ValidationError("현재 증빙을 업로드할 수 없는 상태입니다.")

    proof = SettlementProof.objects.create(
        settlement=settlement,
        uploaded_by=user,
        image_url=image_url,
    )
    return proof


@transaction.atomic
def confirm_settlement(*, settlement: Settlement, user):
    if settlement.payee_user_id != user.id:
        raise PermissionDenied("수취인만 정산을 확인할 수 있습니다.")

    if settlement.status != "PAID_SELF":
        raise ValidationError("먼저 상대방이 송금 완료 처리를 해야 합니다.")

    has_proof = settlement.proofs.exists()

    settlement.status = "CONFIRMED"
    settlement.confirmed_at = timezone.now()
    settlement.verified_by = user
    settlement.verification_method = "PROOF_IMAGE" if has_proof else "MANUAL"
    settlement.save(
        update_fields=[
            "status",
            "confirmed_at",
            "verified_by",
            "verification_method",
        ]
    )
    return settlement


@transaction.atomic
def dispute_settlement(*, settlement: Settlement, user):
    if user.id not in [settlement.payer_user_id, settlement.payee_user_id]:
        raise PermissionDenied("정산 당사자만 이의제기할 수 있습니다.")

    if settlement.status not in ["REQUEST", "PAID_SELF"]:
        raise ValidationError("현재 이의제기할 수 없는 상태입니다.")

    settlement.status = "DISPUTED"
    settlement.save(update_fields=["status"])
    return settlement