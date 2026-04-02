// ============================================================
// lib/screens/tabs/active_tab.dart
// ============================================================
import 'dart:io';
import 'package:flutter/foundation.dart';  // 웹에서 실행 시 예외
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/colors.dart';
import 'message_tab.dart';

// ============================================================
// 열거형 & 모델
// ============================================================

enum PinPhase { open, closed, departed }

enum RidePhase { riding, settled, receiptShared, completed }

class ActiveRidePin {
  final String id, hostId, dept, dest, time, date;
  final int max, cur;
  final bool isMyRide;
  final String? kakaoPayLink;
  final RidePhase phase;
  final PinPhase pinPhase;

  const ActiveRidePin({
    required this.id,
    required this.hostId,
    required this.dept,
    required this.dest,
    required this.time,
    required this.date,
    required this.max,
    required this.cur,
    this.isMyRide = false,
    this.kakaoPayLink,
    this.phase = RidePhase.riding,
    this.pinPhase = PinPhase.open,
  });

  bool get isFull => cur >= max;

  ActiveRidePin copyWith({
    bool? isMyRide,
    PinPhase? pinPhase,
    RidePhase? phase,
  }) =>
      ActiveRidePin(
        id: id,
        hostId: hostId,
        dept: dept,
        dest: dest,
        time: time,
        date: date,
        max: max,
        cur: cur,
        isMyRide: isMyRide ?? this.isMyRide,
        kakaoPayLink: kakaoPayLink,
        phase: phase ?? this.phase,
        pinPhase: pinPhase ?? this.pinPhase,
      );
}

class ActiveRideState extends ChangeNotifier {
  ActiveRidePin _activeRide = const ActiveRidePin(
    id: 'active1',
    hostId: 'taxi_kim',
    dept: '강남역 2번출구',
    dest: '김포공항',
    time: '14:35',
    date: '오늘',
    max: 4,
    cur: 3,
    isMyRide: true,
    kakaoPayLink: 'https://qr.kakaopay.com/FVVO3QHxL',
    phase: RidePhase.riding,
    pinPhase: PinPhase.open,
  );

  RidePhase _sharedPhase = RidePhase.riding;
  DateTime _now = DateTime.now();

  ActiveRidePin get activeRide => _activeRide;
  RidePhase get sharedPhase => _sharedPhase;
  DateTime get now => _now;

  DateTime get departureTime {
    final parts = _activeRide.time.split(':');
    final today = DateTime.now();
    return DateTime(today.year, today.month, today.day,
        int.parse(parts[0]), int.parse(parts[1]));
  }

  bool get isPastDeparture => _now.isAfter(departureTime);

  void addTime(Duration d) {
    _now = _now.add(d);
    notifyListeners();
  }

  void resetTime() {
    _now = DateTime.now();
    _sharedPhase = RidePhase.riding;
    notifyListeners();
  }

  void setPhase(RidePhase p) {
    _sharedPhase = p;
    notifyListeners();
  }

  void switchToHost() {
    _activeRide = _activeRide.copyWith(isMyRide: true);
    _sharedPhase = RidePhase.riding;
    _now = DateTime.now();
    notifyListeners();
  }

  void switchToMember() {
    _activeRide = _activeRide.copyWith(isMyRide: false);
    _sharedPhase = RidePhase.riding;
    _now = DateTime.now();
    notifyListeners();
  }

  void closePinRecruit() {
    _activeRide = _activeRide.copyWith(pinPhase: PinPhase.closed);
    notifyListeners();
  }
}

final globalActiveRideState = ActiveRideState();

const _waitingPins = [
  ActiveRidePin(
    id: 'w1', hostId: 'seoul_lee',
    dept: '홍대입구역', dest: '인천공항 T1',
    time: '18:00', date: '오늘', max: 3, cur: 2,
    kakaoPayLink: 'https://qr.kakaopay.com/FVVO3QHxL',
  ),
  ActiveRidePin(
    id: 'w2', hostId: 'go_choi',
    dept: '신촌역', dest: '판교역',
    time: '09:00', date: '내일', max: 2, cur: 1,
    kakaoPayLink: 'https://qr.kakaopay.com/host_go_choi',
  ),
];

const _myPins = [
  ActiveRidePin(
    id: 'm1', hostId: '나',
    dept: '잠실역 8번출구', dest: '강남역',
    time: '23:50', date: '오늘', max: 4, cur: 3,
  ),
  ActiveRidePin(
    id: 'm2', hostId: '나',
    dept: '신촌역', dest: '판교역',
    time: '16:00', date: '내일', max: 2, cur: 0,
  ),
];

// ============================================================
// 정산 메시지 클래스
// ============================================================
class SettlementMessage {
  final int totalFare, perPerson, memberCount;
  final String? kakaoPayLink;
  final String hostId;
  final File? imageFile;

  SettlementMessage({
    required this.totalFare,
    required this.perPerson,
    required this.memberCount,
    this.kakaoPayLink,
    required this.hostId,
    this.imageFile,
  });
}

final settlementMessageNotifier =
ValueNotifier<SettlementMessage?>(null);

// ============================================================
// 이용 중 시트
// ============================================================
class ActiveRideSheet extends StatefulWidget {
  final ActiveRideState state;
  final VoidCallback onClose;
  final VoidCallback? onGoToChat;

  const ActiveRideSheet({
    super.key,
    required this.state,
    required this.onClose,
    this.onGoToChat,
  });

  @override
  State<ActiveRideSheet> createState() => _ActiveRideSheetState();
}

class _ActiveRideSheetState extends State<ActiveRideSheet> {
  final DraggableScrollableController _sheetCtrl = DraggableScrollableController();

  ActiveRideState get _s => widget.state;

  ActiveRidePin? get _departedWaitingPin {
    for (final pin in _waitingPins) {
      if (pin.date != '오늘') continue;
      final parts = pin.time.split(':');
      final today = DateTime.now();
      final dep = DateTime(today.year, today.month, today.day,
          int.parse(parts[0]), int.parse(parts[1]));
      if (_s.now.isAfter(dep)) return pin;
    }
    return null;
  }

  ActiveRidePin get _currentActiveRide =>
      _departedWaitingPin ?? _s.activeRide;

  @override
  void dispose() {
    _sheetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _s,
      builder: (_, __) => GestureDetector(
        onTap: widget.onClose,
        child: Container(
          color: Colors.black.withOpacity(0.4),
          child: DraggableScrollableSheet(
            controller: _sheetCtrl,
            initialChildSize: 0.55,
            minChildSize: 0.4,
            maxChildSize: 0.85,
            snap: true,
            snapSizes: const [0.4, 0.55, 0.85],
            builder: (context, scrollController) {
              return GestureDetector(
                onTap: () {},
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    children: [
                      _buildHeader(),
                      _buildDebugPanel(),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(20),
                          children: [
                            _buildTeamCard(),
                            const SizedBox(height: 14),
                            _buildMemberCard(),
                            const SizedBox(height: 14),
                            _buildActionButtons(context),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: widget.onClose,  // 닫기 버튼과 동일한 동작
            behavior: HitTestBehavior.translucent,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          Row(
            children: [
              const RidingBadge(),
              const Spacer(),
              GestureDetector(
                onTap: widget.onClose,
                child: const Icon(Icons.close, color: AppColors.gray, size: 22),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDebugPanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🛠 테스트용 — 출시 전 삭제',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.orange)),
          const SizedBox(height: 6),
          Text(
            '가상 현재: ${_s.now.hour.toString().padLeft(2, '0')}:${_s.now.minute.toString().padLeft(2, '0')}'
                '  |  이용 중: @${_currentActiveRide.hostId}'
                '  |  내 핀: ${_currentActiveRide.isMyRide}'
                '  |  정산: ${_s.sharedPhase.name}',
            style: const TextStyle(fontSize: 11, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('시점:', style: TextStyle(fontSize: 11, color: Colors.black54)),
              const SizedBox(width: 8),
              _debugBtn('대표자', _s.activeRide.isMyRide, AppColors.primary,
                  _s.switchToHost),
              const SizedBox(width: 6),
              _debugBtn('참여자', !_s.activeRide.isMyRide, AppColors.accent,
                  _s.switchToMember),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _timeBtn('+1분', const Duration(minutes: 1)),
              const SizedBox(width: 6),
              _timeBtn('+10분', const Duration(minutes: 10)),
              const SizedBox(width: 6),
              _timeBtn('+1시간', const Duration(hours: 1)),
              const Spacer(),
              if (!_currentActiveRide.isMyRide &&
                  _s.sharedPhase == RidePhase.riding &&
                  _s.isPastDeparture) ...[
                _simBtn('탑승완료 시뮬', AppColors.primary,
                        () => _s.setPhase(RidePhase.settled)),
                const SizedBox(width: 6),
              ],
              if (!_currentActiveRide.isMyRide &&
                  _s.sharedPhase == RidePhase.settled) ...[
                _simBtn('공유완료 시뮬', Colors.green, () {
                  _s.setPhase(RidePhase.receiptShared);
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (mounted) _goToChatDialog(context);
                  });
                }),
                const SizedBox(width: 6),
              ],
              GestureDetector(
                onTap: _s.resetTime,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('초기화',
                      style: TextStyle(fontSize: 11, color: Colors.black54)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _debugBtn(String label, bool active, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color : color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : color)),
      ),
    );
  }

  Widget _timeBtn(String label, Duration d) {
    return GestureDetector(
      onTap: () => _s.addTime(d),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 11, color: Colors.deepOrange, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _simBtn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildTeamCard() {
    final ride = _s.activeRide;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('팀 정보',
              style: TextStyle(
                  fontSize: 12, color: AppColors.gray, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            children: [
              _profileCircle(44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('@${ride.hostId}',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.secondary)),
                    const SizedBox(height: 4),
                    _routeRow(ride),
                  ],
                ),
              ),
              _timeBox(ride.time, ride.date),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard() {
    final ride = _s.activeRide;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('인원 현황',
              style: TextStyle(
                  fontSize: 12, color: AppColors.gray, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            children: [
              ..._seatIndicators(ride),
              const SizedBox(width: 8),
              Text('${ride.cur}/${ride.max}명 탑승',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondary)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ride.cur / ride.max,
              backgroundColor: AppColors.primaryLight,
              color: AppColors.primary,
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(ride.cur, (i) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                      color: AppColors.bg,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border)),
                  child: const Icon(Icons.person, color: AppColors.gray, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  i == 0 ? '@${ride.hostId} (방장)' : '@member_$i',
                  style: TextStyle(
                    fontSize: 13,
                    color: i == 0 ? AppColors.primary : AppColors.secondary,
                    fontWeight: i == 0 ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }


  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        if (_s.sharedPhase == RidePhase.riding) ...[
          const SizedBox(height: 10),
          if (_currentActiveRide.isMyRide)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _s.isPastDeparture
                      ? AppColors.primary
                      : AppColors.gray.withOpacity(0.3),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _s.isPastDeparture ? () => _confirmBoarding(context) : null,
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: Text(
                  _s.isPastDeparture ? '탑승 확인 완료' : '출발 시각 이후 활성화',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            )
          else
            _waitingBox(_s.isPastDeparture
                ? '대표자의 탑승 확인을 기다리는 중...'
                : '출발 시각(${_currentActiveRide.time}) 이후 정산이 시작됩니다'),
        ] else if (_s.sharedPhase == RidePhase.settled) ...[
          const SizedBox(height: 10),
          if (_currentActiveRide.isMyRide) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _goToReceiptShare(context),
                icon: const Icon(Icons.receipt_long_outlined, size: 16),
                label: const Text('결제 내역 공유하기',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
          ] else
            _waitingBox('대표자의 결제 내역 공유를 기다리는 중...'),
        ] else if (_s.sharedPhase == RidePhase.receiptShared) ...[
          const SizedBox(height: 10),
          if (_currentActiveRide.isMyRide) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: const Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 14, color: AppColors.primary),
                    SizedBox(width: 6),
                    Text('결제 내역 공유 완료',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _goToChatDialog(context),
                icon: const Icon(Icons.chat_bubble_outline, size: 16),
                label: const Text('채팅방으로 이동',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '대표자가 정산을 요청했습니다.\n채팅방으로 이동하여 정산해주세요.',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _goToChatDialog(context),
                icon: const Icon(Icons.chat_bubble_outline, size: 16),
                label: const Text('채팅방으로 이동',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _waitingBox(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.bg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: Center(
      child: Text(text,
          style: const TextStyle(fontSize: 12, color: AppColors.gray)),
    ),
  );

  void _confirmBoarding(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('탑승 확인',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('모든 인원이 탑승했나요?\n확인하면 정산 단계로 넘어갑니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('아직이요')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0),
            onPressed: () {
              Navigator.pop(context);
              _s.setPhase(RidePhase.settled);
            },
            child: const Text('탑승 완료'),
          ),
        ],
      ),
    );
  }

  void _goToReceiptShare(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReceiptShareScreen(
          activeRide: _s.activeRide,
          onSent: () => _s.setPhase(RidePhase.receiptShared),
        ),
      ),
    );
  }

  void _goToChatDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('채팅방으로 이동',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('채팅방으로 이동하여 정산하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0),
            onPressed: () {
              Navigator.pop(context);
              widget.onClose();
              widget.onGoToChat?.call();
            },
            child: const Text('이동하기'),
          ),
        ],
      ),
    );
  }

  Widget _profileCircle(double size) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
        color: AppColors.bg,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border)),
    child: Icon(Icons.person, color: AppColors.gray, size: size * 0.55),
  );

  Widget _routeRow(ActiveRidePin pin) => Row(
    children: [
      Flexible(
        child: Text(pin.dept,
            style: const TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Text('→',
            style: TextStyle(
                color: AppColors.textSub, fontWeight: FontWeight.w700)),
      ),
      Flexible(
        child: Text(pin.dest,
            style: const TextStyle(
                fontSize: 12, color: AppColors.secondary),
            overflow: TextOverflow.ellipsis),
      ),
    ],
  );

  Widget _timeBox(String time, String date) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(10)),
    child: Column(
      children: [
        Text(date,
            style: const TextStyle(fontSize: 9, color: Colors.white70)),
        Text(time,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
      ],
    ),
  );

  List<Widget> _seatIndicators(ActiveRidePin pin) => List.generate(
    pin.max,
        (j) => Container(
      width: 22, height: 22,
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: j < pin.cur ? AppColors.primary : AppColors.bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: j < pin.cur ? AppColors.primary : AppColors.border),
      ),
      child: j < pin.cur
          ? const Icon(Icons.person, color: Colors.white, size: 13)
          : null,
    ),
  );
}

// ============================================================
// 결제 내역 공유 화면
// ============================================================
class ReceiptShareScreen extends StatefulWidget {
  final ActiveRidePin activeRide;
  final VoidCallback onSent;

  const ReceiptShareScreen({
    super.key,
    required this.activeRide,
    required this.onSent,
  });

  @override
  State<ReceiptShareScreen> createState() => _ReceiptShareScreenState();
}

class _ReceiptShareScreenState extends State<ReceiptShareScreen> {
  // Mobile 앱만 지원 (File 사용하는게 더 효율적)
  File? _receiptImage;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _totalCtrl = TextEditingController(text: '25000');
  late TextEditingController _perPersonCtrl;
  bool _sent = false;

  int get _memberCount => widget.activeRide.cur;
  int get _totalFare => int.tryParse(_totalCtrl.text.replaceAll(',', '')) ?? 0;
  int get _perPerson =>
      _memberCount > 0 ? (_totalFare / _memberCount).ceil() : 0;

  @override
  void initState() {
    super.initState();
    _perPersonCtrl = TextEditingController(
        text: _perPerson.toString());
  }

  void _recalc() {
    setState(() {
      _perPersonCtrl.text = _perPerson.toString();
    });
  }

  @override
  void dispose() {
    _totalCtrl.dispose();
    _perPersonCtrl.dispose();
    super.dispose();
  }

  // 이미지 선택 메서드 (Mobile 앱용-> 웹에서는 사용 불가)
  Future<void> _pickReceiptImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (picked != null) {
        setState(() => _receiptImage = File(picked.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('사진을 불러올 수 없습니다. 권한을 확인해 주세요.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // 이미지 선택 바텀시트
  void _showImagePickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '영수증 사진 선택',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.secondary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library_outlined,
                      color: AppColors.primary, size: 22),
                ),
                title: const Text('갤러리에서 선택',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: const Text('앨범에서 사진을 가져옵니다',
                    style: TextStyle(fontSize: 11, color: AppColors.gray)),
                onTap: () {
                  Navigator.pop(context);
                  _pickReceiptImage(ImageSource.gallery);
                },
              ),
              const Divider(color: AppColors.border, height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt_outlined,
                      color: Color(0xFF4A6FFF), size: 22),
                ),
                title: const Text('카메라로 촬영',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: const Text('지금 바로 사진을 촬영합니다',
                    style: TextStyle(fontSize: 11, color: AppColors.gray)),
                onTap: () {
                  Navigator.pop(context);
                  _pickReceiptImage(ImageSource.camera);
                },
              ),
              if (_receiptImage != null) ...[
                const Divider(color: AppColors.border, height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delete_outline,
                        color: AppColors.red, size: 22),
                  ),
                  title: const Text('영수증 사진 삭제',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.red,
                      )),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _receiptImage = null);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              color: Colors.white,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios,
                        color: AppColors.secondary, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text('결제 내역 공유',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.secondary)),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionCard(
                      child: Row(
                        children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.local_taxi,
                                color: AppColors.primary, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${widget.activeRide.dept} → ${widget.activeRide.dest}',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.secondary),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${widget.activeRide.date} ${widget.activeRide.time} 출발  •  총 ${widget.activeRide.cur}명',
                                  style: const TextStyle(
                                      fontSize: 11, color: AppColors.gray),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Mobile 앱에서만 표시 (Web은 숨김)
                    if (!kIsWeb) ...[
                      const Text('영수증 사진',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.secondary)),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: _showImagePickerSheet,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: double.infinity,
                          height: 140,
                          decoration: BoxDecoration(
                            color: _receiptImage != null
                                ? AppColors.primaryLight
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _receiptImage != null
                                  ? AppColors.primary
                                  : AppColors.border,
                              width: _receiptImage != null ? 1.5 : 1,
                            ),
                          ),
                          child: _receiptImage != null
                              ? Stack(
                            alignment: Alignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                // Image.file() 사용 (Mobile 앱용)
                                child: Image.file(_receiptImage!, fit: BoxFit.cover),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.receipt_long,
                                      color: Colors.white, size: 36),
                                  SizedBox(height: 8),
                                  Text('영수증 첨부됨',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700)),
                                  SizedBox(height: 4),
                                  Text('탭하여 변경',
                                      style: TextStyle(
                                          fontSize: 11, color: Colors.white70)),
                                ],
                              ),
                            ],
                          )
                              : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.add_photo_alternate_outlined,
                                  color: AppColors.gray, size: 36),
                              SizedBox(height: 8),
                              Text('영수증 사진 첨부',
                                  style: TextStyle(
                                      fontSize: 13, color: AppColors.gray)),
                              SizedBox(height: 4),
                              Text('탭하여 사진 선택',
                                  style: TextStyle(
                                      fontSize: 11, color: AppColors.gray)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    const Text('정산 금액',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.secondary)),
                    const SizedBox(height: 10),
                    _sectionCard(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                flex: 2,
                                child: Text('총 택시 요금',
                                    style: TextStyle(
                                        fontSize: 13, color: AppColors.secondary)),
                              ),
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: _totalCtrl,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.right,
                                  onChanged: (_) => _recalc(),
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.secondary),
                                  decoration: InputDecoration(
                                    suffixText: '원',
                                    suffixStyle: const TextStyle(
                                        fontSize: 13, color: AppColors.gray),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(
                                            color: AppColors.border)),
                                    enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(
                                            color: AppColors.border)),
                                    focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(
                                            color: AppColors.primary)),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Divider(color: AppColors.border),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Expanded(
                                flex: 2,
                                child: Text('탑승 인원',
                                    style: TextStyle(
                                        fontSize: 13, color: AppColors.secondary)),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  '${_memberCount}명',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.secondary),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Divider(color: AppColors.border),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('1인당 정산 금액',
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: AppColors.secondary,
                                            fontWeight: FontWeight.w700)),
                                    SizedBox(height: 2),
                                    Text('직접 수정 가능',
                                        style: TextStyle(
                                            fontSize: 10, color: AppColors.gray)),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: _perPersonCtrl,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary),
                                  decoration: InputDecoration(
                                    suffixText: '원',
                                    suffixStyle: const TextStyle(
                                        fontSize: 13, color: AppColors.primary),
                                    filled: true,
                                    fillColor: AppColors.primaryLight,
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(
                                            color: AppColors.primary)),
                                    enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(
                                            color: AppColors.primary,
                                            width: 1.5)),
                                    focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(
                                            color: AppColors.primaryDark,
                                            width: 2)),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // 유효성 검사
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _sent ? AppColors.gray : AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _sent ? null : () => _sendSettlementRequest(context),
                  icon: Icon(_sent ? Icons.check : Icons.send_outlined, size: 18),
                  label: Text(
                    _sent ? '정산 요청 전송 완료' : '채팅방에 정산 요청 보내기',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({required Widget child}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );

  // 유효성 검사 (Mobile 앱용, Web은 스킵)
  void _sendSettlementRequest(BuildContext context) async {
    // Web에서는 이미지 검사 스킵, Mobile에서만 체크
    if (!kIsWeb && _receiptImage == null) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('사진 첨부 필요',
              style: TextStyle(fontWeight: FontWeight.w700)),
          content: const Text('영수증 사진을 첨부해주세요.'),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ],
        ),
      );
      return;
    }

    final perPerson =
        int.tryParse(_perPersonCtrl.text.replaceAll(',', '')) ?? _perPerson;
    final total =
        int.tryParse(_totalCtrl.text.replaceAll(',', '')) ?? _totalFare;

    settlementMessageNotifier.value = SettlementMessage(
      totalFare: total,
      perPerson: perPerson,
      memberCount: _memberCount,
      kakaoPayLink: widget.activeRide.kakaoPayLink,
      hostId: widget.activeRide.hostId,
      imageFile: _receiptImage,
    );

    setState(() => _sent = true);
    widget.onSent();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('정산 요청을 채팅방에 전송했습니다!'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) Navigator.pop(context);
    });
  }
}

// ============================================================
// 이용 중 버튼
// ============================================================
class ActiveRideButton extends StatelessWidget {
  final ActiveRideState state;
  final VoidCallback onTap;

  const ActiveRideButton({
    super.key,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (_, __) {
        if (state.sharedPhase == RidePhase.completed) {
          return const SizedBox.shrink();
        }

        ActiveRidePin current = state.activeRide;
        for (final pin in _waitingPins) {
          if (pin.date != '오늘') continue;
          final parts = pin.time.split(':');
          final today = DateTime.now();
          final dep = DateTime(today.year, today.month, today.day,
              int.parse(parts[0]), int.parse(parts[1]));
          if (state.now.isAfter(dep)) {
            current = pin;
            break;
          }
        }

        return GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const RidingBadge(),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(current.dept,
                            style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                                fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text('→',
                            style: TextStyle(
                                color: Colors.white54,
                                fontWeight: FontWeight.w700)),
                      ),
                      Flexible(
                        child: Text(current.dest,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white70),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.keyboard_arrow_up,
                    color: Colors.white, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================
// 펄스 뱃지
// ============================================================
class RidingBadge extends StatefulWidget {
  const RidingBadge({super.key});

  @override
  State<RidingBadge> createState() => _RidingBadgeState();
}

class _RidingBadgeState extends State<RidingBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.55, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _pulse,
          builder: (_, __) => Container(
            width: 7, height: 7,
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(_pulse.value),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.success.withOpacity(0.35 * _pulse.value),
                  blurRadius: 5,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: AppColors.success.withOpacity(0.35)),
          ),
          child: const Text('이용 중',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.success)),
        ),
      ],
    );
  }
}

// ============================================================
// ActiveTab 본체
// ============================================================
class ActiveTab extends StatefulWidget {
  const ActiveTab({super.key});

  @override
  State<ActiveTab> createState() => _ActiveTabState();
}

class _ActiveTabState extends State<ActiveTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  String? _selectedCardId;
  bool _showActiveDetail = false;

  final _state = globalActiveRideState;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() => setState(() => _selectedCardId = null));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _state,
      builder: (_, __) => Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildHeader(),
                  _buildTabBar(),
                  Expanded(
                    child: TabBarView(
                      controller: _tabCtrl,
                      children: [_buildWaitingList(), _buildMyPinList()],
                    ),
                  ),
                  ActiveRideButton(
                    state: _state,
                    onTap: () => setState(() => _showActiveDetail = true),
                  ),
                ],
              ),
              if (_showActiveDetail)
                ActiveRideSheet(
                  state: _state,
                  onClose: () => setState(() => _showActiveDetail = false),
                  onGoToChat: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ActiveTabChatBridge(
                          hostId: _state.activeRide.hostId,
                          dept: _state.activeRide.dept,
                          dest: _state.activeRide.dest,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() => Container(
    decoration: const BoxDecoration(color: Colors.white),
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
    child: const Align(
      alignment: Alignment.centerLeft,
      child: Text('이용 중',
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.secondary)),
    ),
  );

  Widget _buildTabBar() => Container(
    color: Colors.white,
    child: TabBar(
      controller: _tabCtrl,
      labelColor: AppColors.primary,
      unselectedLabelColor: AppColors.gray,
      labelStyle:
      const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      unselectedLabelStyle:
      const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      indicatorColor: AppColors.primary,
      indicatorWeight: 2.5,
      indicatorSize: TabBarIndicatorSize.tab,
      tabs: [
        Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('참여 중'),
              if (_waitingPins.isNotEmpty) ...[
                const SizedBox(width: 6),
                _countBadge(_waitingPins.length),
              ],
            ],
          ),
        ),
        Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('내가 만든 핀'),
              if (_myPins.isNotEmpty) ...[
                const SizedBox(width: 6),
                _countBadge(_myPins.length),
              ],
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildWaitingList() {
    if (_waitingPins.isEmpty) {
      return _emptyState(
        icon: Icons.bookmark_border_outlined,
        title: '참여 신청한 팀이 없어요',
        sub: '홈에서 마음에 드는 팀에 신청해보세요!',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _waitingPins.length,
      itemBuilder: (_, i) => GestureDetector(
        onTap: () => setState(() =>
        _selectedCardId =
        _selectedCardId == _waitingPins[i].id ? null : _waitingPins[i].id),
        child: _buildWaitingCard(_waitingPins[i]),
      ),
    );
  }

  Widget _buildMyPinList() {
    if (_myPins.isEmpty) {
      return _emptyState(
        icon: Icons.location_on_outlined,
        title: '생성한 핀이 없어요',
        sub: '매칭 탭에서 새 핀을 만들어보세요!',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _myPins.length,
      itemBuilder: (_, i) => GestureDetector(
        onTap: () => setState(() =>
        _selectedCardId =
        _selectedCardId == _myPins[i].id ? null : _myPins[i].id),
        child: _buildMyPinCard(_myPins[i]),
      ),
    );
  }

  Widget _buildWaitingCard(ActiveRidePin pin) {
    final isSelected = _selectedCardId == pin.id;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primaryLight : Colors.white,
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: isSelected ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _profileCircle(44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('@${pin.hostId}',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.secondary)),
                        const SizedBox(width: 6),
                        _badge('신청 대기',
                            AppColors.accent.withOpacity(0.1),
                            AppColors.accent.withOpacity(0.3),
                            AppColors.accent),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _routeRow(pin),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _timeBox(pin.time, pin.date),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ..._seatIndicators(pin),
              const SizedBox(width: 6),
              Text('${pin.cur}/${pin.max}명',
                  style:
                  const TextStyle(fontSize: 11, color: AppColors.gray)),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            child: isSelected
                ? Column(
              children: [
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _showCancelDialog(pin),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.red,
                      side:
                      const BorderSide(color: AppColors.red),
                      padding:
                      const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('신청 취소',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildMyPinCard(ActiveRidePin pin) {
    final isSelected = _selectedCardId == pin.id;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primaryLight : Colors.white,
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: isSelected ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _profileCircle(44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('@${pin.hostId}',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.secondary)),
                        const SizedBox(width: 6),
                        _badge('내 핀', AppColors.primaryLight,
                            AppColors.primary.withOpacity(0.3),
                            AppColors.primary),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _routeRow(pin),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _timeBox(pin.time, pin.date),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ..._seatIndicators(pin),
              const SizedBox(width: 6),
              Text('${pin.cur}/${pin.max}명',
                  style:
                  const TextStyle(fontSize: 11, color: AppColors.gray)),
            ],
          ),
          if (pin.pinPhase == PinPhase.closed)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.gray.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.gray.withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline,
                      size: 12, color: AppColors.gray),
                  SizedBox(width: 4),
                  Text('마감 완료된 핀',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.gray,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            child: isSelected
                ? Column(
              children: [
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _showFinishDialog(pin),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryDark,
                      side: const BorderSide(
                          color: AppColors.primaryDark),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(12)),
                    ),
                    child: const Text('모집 완료',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 5),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _showDeleteDialog(pin),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.red,
                      side: const BorderSide(
                          color: AppColors.red),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(12)),
                    ),
                    child: const Text('핀 삭제',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(ActiveRidePin pin) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('신청 취소',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('${pin.dept} → ${pin.dest}\n참여 신청을 취소할까요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('돌아가기')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red,
                foregroundColor: Colors.white,
                elevation: 0),
            onPressed: () => Navigator.pop(context),
            child: const Text('신청 취소'),
          ),
        ],
      ),
    );
  }

  void _showFinishDialog(ActiveRidePin pin) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('핀 모집 완료',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('${pin.dept} → ${pin.dest}\n해당 핀의 모집을 완료할까요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('돌아가기')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                elevation: 0),
            onPressed: () {
              Navigator.pop(context);
              _state.closePinRecruit();
            },
            child: const Text('완료하기'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(ActiveRidePin pin) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('핀 삭제',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('${pin.dept} → ${pin.dest}\n생성한 핀을 삭제할까요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('돌아가기')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red,
                foregroundColor: Colors.white,
                elevation: 0),
            onPressed: () => Navigator.pop(context),
            child: const Text('삭제하기'),
          ),
        ],
      ),
    );
  }

  Widget _profileCircle(double size) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
        color: AppColors.bg,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border)),
    child: Icon(Icons.person, color: AppColors.gray, size: size * 0.55),
  );

  Widget _routeRow(ActiveRidePin pin) => Row(
    children: [
      Flexible(
        child: Text(pin.dept,
            style: const TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Text('→',
            style: TextStyle(
                color: AppColors.textSub, fontWeight: FontWeight.w700)),
      ),
      Flexible(
        child: Text(pin.dest,
            style: const TextStyle(
                fontSize: 12, color: AppColors.secondary),
            overflow: TextOverflow.ellipsis),
      ),
    ],
  );

  Widget _timeBox(String time, String date) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(10)),
    child: Column(
      children: [
        Text(date,
            style: const TextStyle(fontSize: 9, color: Colors.white70)),
        Text(time,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
      ],
    ),
  );

  List<Widget> _seatIndicators(ActiveRidePin pin) => List.generate(
    pin.max,
        (j) => Container(
      width: 22, height: 22,
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: j < pin.cur ? AppColors.primary : AppColors.bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: j < pin.cur ? AppColors.primary : AppColors.border),
      ),
      child: j < pin.cur
          ? const Icon(Icons.person, color: Colors.white, size: 13)
          : null,
    ),
  );

  Widget _badge(
      String text, Color bg, Color borderColor, Color textColor) =>
      Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: borderColor),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 9,
                color: textColor,
                fontWeight: FontWeight.w700)),
      );

  Widget _countBadge(int count) => Container(
    width: 18, height: 18,
    decoration: BoxDecoration(
      color: AppColors.gray.withOpacity(0.2),
      shape: BoxShape.circle,
    ),
    child: Center(
      child: Text('$count',
          style: const TextStyle(
              color: AppColors.gray,
              fontSize: 10,
              fontWeight: FontWeight.w800)),
    ),
  );

  Widget _emptyState(
      {required IconData icon,
        required String title,
        required String sub}) =>
      Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72, height: 72,
              decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle),
              child: Icon(icon, color: AppColors.primary, size: 36),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.secondary)),
            const SizedBox(height: 6),
            Text(sub,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.gray)),
          ],
        ),
      );
}

// ============================================================
// 이용 중 탭 → 채팅방 브릿지
// ============================================================
class ActiveTabChatBridge extends StatefulWidget {
  final String hostId, dept, dest;
  const ActiveTabChatBridge({
    super.key,
    required this.hostId,
    required this.dept,
    required this.dest,
  });

  @override
  State<ActiveTabChatBridge> createState() => _ActiveTabChatBridgeState();
}

class _ActiveTabChatBridgeState extends State<ActiveTabChatBridge> {
  final List<Map<String, dynamic>> _messages = [
    {'isMe': false, 'userId': 'travel_kim', 'text': '안녕하세요! 강남역 2번 출구에서 14:30 출발 예정입니다.', 'time': '14:10', 'isSettlement': false},
    {'isMe': false, 'userId': 'seoul_lee',  'text': '네 참여할게요! 카카오페이 링크 부탁드려요.', 'time': '14:12', 'isSettlement': false},
    {'isMe': true,  'userId': '나', 'text': '카카오페이 링크입니다 😊', 'time': '14:13', 'isSettlement': false},
  ];

  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final msg = settlementMessageNotifier.value;
      if (msg != null) {
        _injectSettlement(msg);
      }
      settlementMessageNotifier.addListener(_onSettlement);
    });
  }

  @override
  void dispose() {
    settlementMessageNotifier.removeListener(_onSettlement);
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onSettlement() {
    final msg = settlementMessageNotifier.value;
    if (msg != null) _injectSettlement(msg);
  }

  void _injectSettlement(SettlementMessage msg) {
    final alreadyHas = _messages.any((m) => m['isSettlement'] == true);
    if (alreadyHas) return;
    setState(() {
      _messages.add({
        'isMe': true,
        'userId': msg.hostId,
        'text': '정산 요청',
        'time': TimeOfDay.now().format(context),
        'isSettlement': true,
        'settlement': msg,
      });
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F8F6),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios,
                        color: AppColors.secondary, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                        color: AppColors.bg,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border)),
                    child: const Icon(Icons.person, color: AppColors.gray, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${widget.dept} → ${widget.dest}',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis),
                        const Text('● 탑승 중',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.success)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                itemCount: _messages.length,
                itemBuilder: (_, i) => _buildBubble(_messages[i]),
              ),
            ),

            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: AppColors.border)),
                      child: TextField(
                        controller: _inputCtrl,
                        minLines: 1, maxLines: 4,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.secondary),
                        decoration: const InputDecoration(
                          hintText: '메시지 입력...',
                          hintStyle: TextStyle(
                              fontSize: 13, color: AppColors.gray),
                          border: InputBorder.none, isDense: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _inputCtrl,
                    builder: (_, val, __) => GestureDetector(
                      onTap: () {
                        final text = _inputCtrl.text.trim();
                        if (text.isEmpty) return;
                        setState(() {
                          _messages.add({
                            'isMe': true,
                            'userId': '나',
                            'text': text,
                            'time': TimeOfDay.now().format(context),
                            'isSettlement': false,
                          });
                        });
                        _inputCtrl.clear();
                        _scrollToBottom();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: val.text.isNotEmpty
                              ? AppColors.primary
                              : AppColors.bg,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: val.text.isNotEmpty
                                  ? AppColors.primary
                                  : AppColors.border),
                        ),
                        child: Icon(Icons.arrow_upward,
                            color: val.text.isNotEmpty
                                ? Colors.white
                                : AppColors.gray,
                            size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(Map<String, dynamic> msg) {
    if (msg['isSettlement'] == true && msg['settlement'] != null) {
      return _buildSettlementCard(msg['settlement'] as SettlementMessage,
          msg['time'] as String);
    }

    final isMe = msg['isMe'] as bool;
    final text = msg['text'] as String;
    final time = msg['time'] as String;
    final userId = msg['userId'] as String;

    if (isMe) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(time,
                style: const TextStyle(fontSize: 10, color: AppColors.gray)),
            const SizedBox(width: 6),
            _bubble(text, isMe: true),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
                color: AppColors.bg,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border)),
            child: const Icon(Icons.person, color: AppColors.gray, size: 20),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('@$userId',
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.gray,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _bubble(text, isMe: false),
                  const SizedBox(width: 6),
                  Text(time,
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.gray)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bubble(String text, {required bool isMe}) {
    return ConstrainedBox(
      constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.62),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: isMe ? null : Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05), blurRadius: 4)
          ],
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 13,
                color: isMe ? Colors.white : AppColors.secondary,
                height: 1.4)),
      ),
    );
  }

  Widget _buildSettlementCard(SettlementMessage s, String time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(time,
              style: const TextStyle(fontSize: 10, color: AppColors.gray)),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(15)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.receipt_long,
                              color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text('정산 요청',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text('${s.memberCount}명',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('총 택시 요금',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.gray)),
                            Text('${_fmt(s.totalFare)}원',
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.secondary,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Divider(color: AppColors.border, height: 1),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('1인당 정산 금액',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.secondary,
                                    fontWeight: FontWeight.w700)),
                            Text('${_fmt(s.perPerson)}원',
                                style: const TextStyle(
                                    fontSize: 18,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w900)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () async {
                              final link = s.kakaoPayLink;
                              if (link != null) {
                                final uri = Uri.tryParse(link);
                                if (uri != null && await canLaunchUrl(uri)) {
                                  await launchUrl(uri,
                                      mode: LaunchMode.externalApplication);
                                }
                              }
                            },
                            child: const Text('정산하기',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i != 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}