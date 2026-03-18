// ============================================================
// 📁 lib/screens/tabs/active_tab.dart
// ============================================================
import 'package:flutter/material.dart';
import '../../utils/colors.dart';

// 데이터 모델
class ActiveRidePin {
  final String id, hostId, dept, dest, time, date;
  final int max, cur;
  const ActiveRidePin({
    required this.id, required this.hostId,
    required this.dept, required this.dest,
    required this.time, required this.date,
    required this.max, required this.cur,
  });
  bool get isFull => cur >= max;
}

// 더미 데이터

// 현재 이용 중인 팀
const _activeRide = ActiveRidePin(
  id: 'active1', hostId: 'taxi_kim',
  dept: '강남역 2번출구', dest: '김포공항',
  time: '14:30', date: '오늘',
  max: 4, cur: 3,
);

// 참여 대기 중 (신청했지만 아직 수락 안 된 것들)-> 수락 형태로 할 건지?
const _waitingPins = [
  ActiveRidePin(id:'w1', hostId:'seoul_lee', dept:'홍대입구역',   dest:'인천공항 T1', time:'18:00', date:'오늘', max:3, cur:2),
  ActiveRidePin(id:'w2', hostId:'go_choi',   dept:'신촌역',        dest:'판교역',       time:'09:00', date:'내일', max:2, cur:1),
];

// 내가 생성한 핀 목록
const _myPins = [
  ActiveRidePin(id:'m1', hostId:'나', dept:'잠실역 8번출구', dest:'강남역', time:'14:45', date:'오늘', max:4, cur:3),
  ActiveRidePin(id:'m2', hostId:'나', dept:'신촌역',          dest:'판교역', time:'16:00', date:'오늘', max:2, cur:0),
];

// ============================================================

class ActiveTab extends StatefulWidget {
  const ActiveTab({super.key});
  @override
  State<ActiveTab> createState() => _ActiveTabState();
}

class _ActiveTabState extends State<ActiveTab> with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  String? _selectedCardId;       // 카드 펼침 상태
  bool _showActiveDetail = false; // 이용 중 시트 표시 여부
  final DraggableScrollableController _sheetCtrl = DraggableScrollableController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() => setState(() => _selectedCardId = null));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _sheetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Stack(
          children: [
            Column(children: [
              _buildHeader(),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _buildWaitingList(),
                    _buildMyPinList(),
                  ],
                ),
              ),
              // 하단 이용 중 버튼 — 두 탭 모두에서 표시
              _buildActiveRideButton(),
            ]),

            // 이용 중 상세 시트 오버레이
            if (_showActiveDetail) _buildActiveDetailSheet(),
          ],
        ),
      ),
    );
  }

  // -- 헤더 ------------------------------------------
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        //border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: const Align(
        alignment: Alignment.centerLeft,
        child: Text('이용 중',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.secondary)),
      ),
    );
  }

  // -- 탭바 ---------------------------------------------
  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabCtrl,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.gray,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        indicatorColor: AppColors.primary,
        indicatorWeight: 2.5,
        indicatorSize: TabBarIndicatorSize.tab,
        tabs: [
          Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('참여 대기 중'),
            if (_waitingPins.isNotEmpty) ...[
              const SizedBox(width: 6),
              _countBadge(_waitingPins.length, active: false),
            ],
          ])),
          Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('내가 만든 핀'),
            if (_myPins.isNotEmpty) ...[
              const SizedBox(width: 6),
              _countBadge(_myPins.length, active: false),
            ],
          ])),
        ],
      ),
    );
  }

  // -- 참여 대기 중 목록 ----------------------------------------
  Widget _buildWaitingList() {
    if (_waitingPins.isEmpty) {
      return _buildEmptyState(
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
        _selectedCardId = _selectedCardId == _waitingPins[i].id ? null : _waitingPins[i].id),
        child: _buildWaitingCard(_waitingPins[i]),
      ),
    );
  }

  // -- 내가 만든 핀 목록 ----------------------------------------
  Widget _buildMyPinList() {
    if (_myPins.isEmpty) {
      return _buildEmptyState(
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
        _selectedCardId = _selectedCardId == _myPins[i].id ? null : _myPins[i].id),
        child: _buildMyPinCard(_myPins[i]),
      ),
    );
  }

  // -- 참여 대기 중 카드 ----------------------------------
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
          Row(children: [
            _profileCircle(),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('@${pin.hostId}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.secondary)),
                  const SizedBox(width: 6),
                  // 신청 대기 뱃지
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                    ),
                    child: const Text('신청 대기',
                        style: TextStyle(fontSize: 9, color: AppColors.accent, fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 4),
                _routeRow(pin),
              ],
            )),
            const SizedBox(width: 8),
            _timeBox(pin.time, pin.date),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            ..._seatIndicators(pin),
            const SizedBox(width: 6),
            Text('${pin.cur}/${pin.max}명', style: const TextStyle(fontSize: 11, color: AppColors.gray)),
            if (pin.isFull)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(100)),
                child: const Text('마감', style: TextStyle(fontSize: 10, color: AppColors.gray, fontWeight: FontWeight.w700)),
              ),
          ]),
          // 펼침 영역 — 예상 금액 없이 취소 버튼만
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            child: isSelected ? Column(children: [
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _showCancelDialog(pin),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.red,
                    side: const BorderSide(color: AppColors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('신청 취소', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ),
            ]) : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // -- 내가 만든 핀 카드 ------------------------------------
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
          Row(children: [
            _profileCircle(),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('@${pin.hostId}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.secondary)),
                  const SizedBox(width: 6),
                  // 내 핀 뱃지
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: const Text('내 핀',
                        style: TextStyle(fontSize: 9, color: AppColors.primary, fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 4),
                _routeRow(pin),
              ],
            )),
            const SizedBox(width: 8),
            _timeBox(pin.time, pin.date),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            ..._seatIndicators(pin),
            const SizedBox(width: 6),
            Text('${pin.cur}/${pin.max}명', style: const TextStyle(fontSize: 11, color: AppColors.gray)),
            if (pin.isFull)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(100)),
                child: const Text('마감', style: TextStyle(fontSize: 10, color: AppColors.gray, fontWeight: FontWeight.w700)),
              ),
          ]),

          // 펼침 영역 (핀 마감 + 삭제 버튼)
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            child: isSelected ? Column(children: [
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 12),

              // 핀 모집 완료 버튼
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _showFinishDialog(pin),  // ** 나중에 핀 마감 로직 추가 ** //
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryDark,
                    side: const BorderSide(color: AppColors.primaryDark),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('모집 완료', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ),

              const SizedBox(height: 5), // 버튼 사이 여백

              // 삭제 버튼
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _showDeleteDialog(pin),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.red,
                    side: const BorderSide(color: AppColors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('핀 삭제', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ),
            ]) : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // -- 하단 이용 중 버튼 -------------------------------------
  Widget _buildActiveRideButton() {
    return GestureDetector(
      onTap: () => setState(() => _showActiveDetail = true),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.secondary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.secondary.withOpacity(0.3),
              blurRadius: 12, offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(children: [
          // 이용 중 펄스 뱃지
          _RidingBadge(),
          const SizedBox(width: 12),
          // 출발지 → 목적지
          Expanded(child: Row(children: [
            Flexible(child: Text(_activeRide.dept,
                style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text('→', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w700)),
            ),
            Flexible(child: Text(_activeRide.dest,
                style: const TextStyle(fontSize: 13, color: Colors.white70),
                overflow: TextOverflow.ellipsis)),
          ])),
          const SizedBox(width: 8),
          const Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 20),
        ]),
      ),
    );
  }

  // -- 이용 중 상세 시트 ------------------------------------
  Widget _buildActiveDetailSheet() {
    return GestureDetector(
      onTap: () => setState(() => _showActiveDetail = false),
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
                child: Column(children: [
                  // 드래그 핸들 + 헤더
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppColors.border)),
                    ),
                    child: Column(children: [
                      Container(
                        width: 40, height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                            color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                      ),
                      Row(children: [
                        _RidingBadge(),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(() => _showActiveDetail = false),
                          child: const Icon(Icons.close, color: AppColors.gray, size: 22),
                        ),
                      ]),
                    ]),
                  ),

                  // 시트 내용
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(20),
                      children: [
                        // 팀 정보 카드
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.bg, borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('팀 정보',
                                  style: TextStyle(fontSize: 12, color: AppColors.gray, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 12),
                              Row(children: [
                                _profileCircle(size: 44),
                                const SizedBox(width: 12),
                                Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('@${_activeRide.hostId}',
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.secondary)),
                                    const SizedBox(height: 4),
                                    _routeRow(_activeRide),
                                  ],
                                )),
                                _timeBox(_activeRide.time, _activeRide.date),
                              ]),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 인원 현황
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white, borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('인원 현황',
                                  style: TextStyle(fontSize: 12, color: AppColors.gray, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 12),
                              Row(children: [
                                ..._seatIndicators(_activeRide),
                                const SizedBox(width: 8),
                                Text('${_activeRide.cur}/${_activeRide.max}명 탑승',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.secondary)),
                              ]),
                              const SizedBox(height: 12),
                              // 인원 진행 바
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: _activeRide.cur / _activeRide.max,
                                  backgroundColor: AppColors.primaryLight,
                                  color: AppColors.primary,
                                  minHeight: 5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              // 멤버 목록
                              ...List.generate(_activeRide.cur, (i) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(children: [
                                  Container(
                                    width: 32, height: 32,
                                    decoration: BoxDecoration(
                                      color: AppColors.bg, shape: BoxShape.circle,
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: const Icon(Icons.person, color: AppColors.gray, size: 18),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    i == 0 ? '@${_activeRide.hostId} (방장)' : '@member_$i',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: i == 0 ? AppColors.primary : AppColors.secondary,
                                      fontWeight: i == 0 ? FontWeight.w700 : FontWeight.w400,
                                    ),
                                  ),
                                ]),
                              )),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 액션 버튼
                        Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.secondary,
                                side: const BorderSide(color: AppColors.border),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {},
                              icon: const Icon(Icons.chat_bubble_outline, size: 16),
                              label: const Text('채팅방', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.red, foregroundColor: Colors.white,
                                elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => setState(() => _showActiveDetail = false),
                              icon: const Icon(Icons.exit_to_app, size: 16),
                              label: const Text('팀 나가기', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ]),
              ),
            );
          },
        ),
      ),
    );
  }

  // -- 다이얼로그 ------------------------------------------------------
  void _showCancelDialog(ActiveRidePin pin) {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('신청 취소', style: TextStyle(fontWeight: FontWeight.w700)),
      content: Text('${pin.dept} → ${pin.dest}\n참여 신청을 취소할까요?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('돌아가기')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red, foregroundColor: Colors.white, elevation: 0),
          onPressed: () => Navigator.pop(context),
          child: const Text('신청 취소'),
        ),
      ],
    ));
  }

  // 핀 모집 완료 팝업
  void _showFinishDialog(ActiveRidePin pin) {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('핀 모집 완료', style: TextStyle(fontWeight: FontWeight.w700)),
      content: Text('${pin.dept} → ${pin.dest}\n해당 핀의 모집을 완료할까요?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('돌아가기')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark, foregroundColor: Colors.white, elevation: 0),
          onPressed: () => Navigator.pop(context), // 모집 완료 로직 추가
          child: const Text('완료하기'),
        ),
      ],
    ));
  }

  // 핀 삭제 팝업 (핀 삭제 완료 로직 추가)
  void _showDeleteDialog(ActiveRidePin pin) {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('핀 삭제', style: TextStyle(fontWeight: FontWeight.w700)),
      content: Text('${pin.dept} → ${pin.dest}\n생성한 핀을 삭제할까요?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('돌아가기')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red, foregroundColor: Colors.white, elevation: 0),
          onPressed: () => Navigator.pop(context),
          child: const Text('삭제하기'),
        ),
      ],
    ));
  }

  // -- 공통 위젯 헬퍼 -------------------------------------
  Widget _profileCircle({double size = 44}) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      color: AppColors.bg, shape: BoxShape.circle,
      border: Border.all(color: AppColors.border),
    ),
    child: Icon(Icons.person, color: AppColors.gray, size: size * 0.6),
  );

  Widget _routeRow(ActiveRidePin pin) => Row(children: [
    Flexible(child: Text(pin.dept,
        style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis)),
    const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Text('→', style: TextStyle(color: AppColors.textSub, fontWeight: FontWeight.w700)),
    ),
    Flexible(child: Text(pin.dest,
        style: const TextStyle(fontSize: 12, color: AppColors.secondary),
        overflow: TextOverflow.ellipsis)),
  ]);

  Widget _timeBox(String time, String date) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
    child: Column(children: [
      Text(date, style: const TextStyle(fontSize: 9, color: Colors.white70)),
      Text(time, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
    ]),
  );

  List<Widget> _seatIndicators(ActiveRidePin pin) =>
      List.generate(pin.max, (j) => Container(
        width: 22, height: 22, margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: j < pin.cur ? AppColors.primary : AppColors.bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: j < pin.cur ? AppColors.primary : AppColors.border),
        ),
        child: j < pin.cur ? const Icon(Icons.person, color: Colors.white, size: 13) : null,
      ));

  Widget _countBadge(int count, {required bool active}) => Container(
    width: 18, height: 18,
    decoration: BoxDecoration(
      color: active ? AppColors.primary : AppColors.gray.withOpacity(0.2),
      shape: BoxShape.circle,
    ),
    child: Center(child: Text('$count',
        style: TextStyle(
            color: active ? Colors.white : AppColors.gray,
            fontSize: 10, fontWeight: FontWeight.w800))),
  );

  Widget _buildEmptyState({required IconData icon, required String title, required String sub}) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 72, height: 72,
        decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
        child: Icon(icon, color: AppColors.primary, size: 36),
      ),
      const SizedBox(height: 16),
      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.secondary)),
      const SizedBox(height: 6),
      Text(sub, style: const TextStyle(fontSize: 13, color: AppColors.gray)),
    ]));
  }
}

// -- 동승 중 펄스 뱃지 -----------------------------------
class _RidingBadge extends StatefulWidget {
  @override
  State<_RidingBadge> createState() => _RidingBadgeState();
}

class _RidingBadgeState extends State<_RidingBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.55, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      AnimatedBuilder(
        animation: _pulse,
        builder: (_, __) => Container(
          width: 7, height: 7,
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(_pulse.value),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(
                color: AppColors.success.withOpacity(0.35 * _pulse.value), blurRadius: 5)],
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
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.success)),
      ),
    ]);
  }
}