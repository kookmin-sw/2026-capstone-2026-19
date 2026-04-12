// ============================================================
// lib/screens/tabs/matching_tab.dart
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../utils/colors.dart';
import '../location_search_screen.dart';
import 'home_tab.dart' as home;
import '../../service/trip_service.dart';

// 매칭 탭 전체 레이아웃 (내부 상태 변경 시 화면 리빌드)
class MatchingTab extends StatefulWidget {
  final VoidCallback? onGoHome;
  const MatchingTab({super.key, this.onGoHome});
  @override
  State<MatchingTab> createState() => _MatchingTabState();
}

// 매칭 탭의 실제 로직 & UI 담당 클래스
class _MatchingTabState extends State<MatchingTab>
    with SingleTickerProviderStateMixin { // 탭바 전환 시 애니메이션 동작
    List<dynamic> _filteredPins = [];

  late TabController _tabController; // 검색, 생성 탭 전환 제어 컨트롤러
  final TextEditingController _searchCtrl = TextEditingController(); // 검색창 입력 제어
  String _searchQuery = ''; // 현재 입력된 검색어 저장
  String? _selectedCardId; // 카드 펼침 상태

  // 핀 생성 폼 컨트롤러
  final TextEditingController _deptCtrl = TextEditingController();  // 출발지
  final TextEditingController _destCtrl = TextEditingController();  // 목적지
  final TextEditingController _kakaoCtrl = TextEditingController();  // 카카오페이 링크
  int _maxPeople = 2;  // 최대 모집 인원 수 (초기값:2)
  String? _selectedSeat;  // 생성 시 대표자의 좌석 선택 상태 (선택 안 했을 경우 null)
  TimeOfDay _selectedTime = TimeOfDay.now();  // 출발 시간 (초기값:현재 시각)
  bool _pinCreated = false;  // 핀 생성 시 성공 배너 표시 여부
  bool _isLoading = false;
  List<home.RidePin> _serverPins = [];
  bool _isFetching = false;

  // 출발지/목적지 좌표 저장
  double? _deptLat;
  double? _deptLng;
  double? _destLat;
  double? _destLng;

  // 좌석 옵션 상수
  static const _seats = ['조수석', '왼쪽 창가', '가운데', '오른쪽 창가'];

  // 생명주기 관리
  @override
  void initState() { // 트리에 위젯 첫 삽입 시 초기 설정 수행
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchTrips();
  }

  @override
  void dispose() { // 위젯 제거 시 컨트롤러 해제
    _tabController.dispose();
    _searchCtrl.dispose();
    _deptCtrl.dispose(); _destCtrl.dispose(); _kakaoCtrl.dispose();
    super.dispose();
  }


  // 매칭 탭 기본 화면 구조 위젯 트리
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildSearchTab(), _buildCreateTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 헤더 (title, 핀 검색/생성 탭바)
  // ============================================================
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 10),
            child: Text('매칭', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.secondary)),
          ),
          TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.gray,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: const UnderlineTabIndicator(
              borderSide: BorderSide(color: AppColors.primary, width: 2.5),
            ),
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 13),
            tabs: const [Tab(text: '🔍  검색'), Tab(text: '📍  핀 생성')],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 검색 탭 화면 위젯
  // ============================================================
  Widget _buildSearchTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: GestureDetector(
            onTap: () async {
              final result = await Navigator.push<Map<String, dynamic>>(
                context,
                MaterialPageRoute(
                  builder: (_) => const LocationSearchScreen(title: '장소'),
                ),
              );
              if (result != null) {
                setState(() {
                  _searchCtrl.text = result['name'] as String;
                  _searchQuery = result['name'] as String;
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.bg,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: AppColors.gray, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _searchQuery.isEmpty ? '출발지 또는 목적지 검색...' : _searchQuery,
                      style: TextStyle(
                        fontSize: 14,
                        color: _searchQuery.isEmpty ? AppColors.gray : AppColors.secondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _searchCtrl.clear();
                          _searchQuery = '';
                        });
                      },
                      child: const Icon(Icons.clear, color: AppColors.gray, size: 18),
                    ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: _buildPinList()),
      ],
    );
  }

  // 검색 시 출력되는 핀 목록
  Widget _buildPinList() {
    final pins = _filteredPins;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Text(
              _searchQuery.isEmpty ? '전체 ${pins.length}건' : '"$_searchQuery" ${pins.length}건',
              style: const TextStyle(fontSize: 12, color: AppColors.gray)),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: pins.length,
            itemBuilder: (_, i) => _buildSearchCard(pins[i]),
          ),
        ),
      ],
    );
  }

  // 핀 목록 카드 위젯
  Widget _buildSearchCard(home.RidePin pin) {
    final isFull = pin.cur >= pin.max;
    final isSelected = _selectedCardId == pin.hostId;

    return GestureDetector(
      onTap: () => setState(() =>
      _selectedCardId = isSelected ? null : pin.hostId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
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
          children: [
            Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.bg, shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(Icons.person, color: AppColors.gray, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('@${pin.hostId}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.secondary)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Flexible(child: Text(pin.dept,
                              style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis)),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Text('→', style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.w700)),
                          ),
                          Flexible(child: Text(pin.dest,
                              style: const TextStyle(fontSize: 12, color: AppColors.secondary),
                              overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    children: [
                      const Text('출발', style: TextStyle(fontSize: 9, color: Colors.white70)),
                      Text(pin.time,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ...List.generate(pin.max, (j) => Container(
                  width: 22, height: 22, margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: j < pin.cur ? AppColors.primary : AppColors.bg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: j < pin.cur ? AppColors.primary : AppColors.border),
                  ),
                  child: j < pin.cur ? const Icon(Icons.person, color: Colors.white, size: 13) : null,
                )),
                const SizedBox(width: 6),
                Text('${pin.cur}/${pin.max}명', style: const TextStyle(fontSize: 11, color: AppColors.gray)),
              ],
            ),

            // 펼침 영역 — 참여하기 버튼
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              child: isSelected
                  ? Column(
                children: [
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFull ? AppColors.gray : AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isFull ? null : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => RideJoinScreen(pin: {
                            'hostId': pin.hostId,
                            'dept': pin.dept,
                            'dest': pin.dest,
                            'time': pin.time,
                            'max': pin.max,
                            'cur': pin.cur,
                          })),
                        );
                      },
                      child: Text(isFull ? '마감' : '참여하기',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }


  // ============================================================
  // 핀 생성 탭
  // ============================================================
  Widget _buildCreateTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 핀 생성 성공 배너 (핀 생성 성공 시 출력)
          if (_pinCreated)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                border: Border.all(color: AppColors.primary),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Text('✅', style: TextStyle(fontSize: 20)),
                  SizedBox(width: 10),
                  Text('핀이 생성되었습니다!',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                ],
              ),
            ),

          // 현재 대표자 프로필 카드 (프로필, 인증 여부, 평가 점수)
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.bg,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container( // 원형 프로필 아이콘
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(Icons.person, color: AppColors.gray, size: 26),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('@my_username', // 실제 서비스에서는 로그인된 유저 정보로 대체
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Row(children: [ // 인증 뱃지, 평가 점수 뱃지
                      _tag('인증됨 ✓'),
                      const SizedBox(width: 4),
                      _tag('⭐ 4.8', color: AppColors.accent, bg: const Color(0xFFFFF8E6)),
                    ]),
                  ],
                ),
              ],
            ),
          ),

          // 출발지 입력
          _label('📍 출발지'), const SizedBox(height: 6),
          _locationTextField(
            controller: _deptCtrl,
            hint: '출발지 검색하기',
            isDeparture: true,
            onTap: () => _openLocationSearch(true),
          ),
          const SizedBox(height: 14),

          // 목적지 입력
          _label('🏁 목적지'), const SizedBox(height: 6),
          _locationTextField(
            controller: _destCtrl,
            hint: '목적지 검색하기',
            isDeparture: false,
            onTap: () => _openLocationSearch(false),
          ),
          const SizedBox(height: 14),

          // 출발 시간 선택
          _label('🕐 출발 시간'), const SizedBox(height: 6),
          GestureDetector(
            onTap: _showTimePicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.bg,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time, color: AppColors.gray, size: 20),
                  const SizedBox(width: 10),
                  Text(_selectedTime.format(context),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.secondary)),
                  const Spacer(),
                  const Icon(Icons.chevron_right, color: AppColors.gray),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 모집 인원 선택
          _label('👥 모집 인원 (최대 4명, 본인 포함 기준)'), const SizedBox(height: 8),
          Row(
            children: [2, 3, 4].map((n) => Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _maxPeople = n),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: _maxPeople == n ? AppColors.primary : AppColors.bg,
                      border: Border.all(color: _maxPeople == n ? AppColors.primary : AppColors.border, width: 1.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('$n명', textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14,
                            color: _maxPeople == n ? Colors.white : AppColors.gray)),
                  ),
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 16),

          // 좌석 선택
          _label('💺 좌석 선택'), const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _seats.map((seat) => Expanded( // 좌석 버튼들 Row 안에서 동일한 너비로 배치
              child: GestureDetector(
                onTap: () => setState(() => _selectedSeat = seat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150), // 애니메이션 진행 시간
                  height: 45,  // 버튼 높이(세로) 길이 고정
                  margin: const EdgeInsets.symmetric(horizontal: 6), // 버튼 사이 여백
                  decoration: BoxDecoration(
                    color: _selectedSeat == seat ? AppColors.primaryLight : AppColors.bg,
                    border: Border.all(
                      color: _selectedSeat == seat ? AppColors.primary : AppColors.border,
                      width: _selectedSeat == seat ? 1.5 : 1,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row( // 버튼 내부 아이콘, 텍스트 정렬
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_seat, size: 15,
                          color: _selectedSeat == seat ? AppColors.primary : AppColors.gray),
                      const SizedBox(width: 5),
                      Text(seat,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _selectedSeat == seat ? AppColors.primary : AppColors.gray,
                          )),
                    ],
                  ),
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 16),

          // 카카오페이 링크 입력 (필수로 하기?)
          _label('💛 카카오페이 링크 (필수)'), const SizedBox(height: 6),
          TextField(
            controller: _kakaoCtrl,
            decoration: InputDecoration(
              hintText: 'https://qr.kakaopay.com/...',
              hintStyle: const TextStyle(fontSize: 12, color: AppColors.gray),
              filled: true, fillColor: const Color(0xFFFFFDE7),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accent)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accent)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 24),

          // 핀 생성 버튼 (이걸로 교체!)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              // 로딩 중일 때는 클릭이 안 되게(null) 만들고, 아니면 생성 함수 실행
              onPressed: _isLoading ? null : _handleCreate,
              child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text('📍 핀 생성하기', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // 시간 선택 바텀 시트 표시 메서드 (출발 시간 선택 시 실행)
  void _showTimePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        TimeOfDay tempTime = _selectedTime;
        return StatefulBuilder(
          builder: (ctx, setModalState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
              const Text('출발 시간 선택', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: false, // 12시간 형식(AM/PM)
                  initialDateTime: DateTime(2024, 1, 1, _selectedTime.hour, _selectedTime.minute),
                  onDateTimeChanged: (dt) {
                    setModalState(() => tempTime = TimeOfDay(hour: dt.hour, minute: dt.minute));
                  },
                ),
              ),
              Padding( // 확인 버튼
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    onPressed: () { setState(() => _selectedTime = tempTime); Navigator.pop(context); },
                    child: const Text('확인', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

// --- 아래 코드를 통째로 추가 ---
  Future<void> _fetchTrips() async {
    if (!mounted) return;
    setState(() => _isFetching = true);

    // TODO: 실제 앱에서는 로그인 토큰을 사용하세요.
    final List<dynamic> data = await TripService.getTrips(token: 'this-is-a-fake-test-token-12345');

    if (mounted) {
      setState(() {
        _serverPins = data.map((item) => home.RidePin(
          id: item['id'].toString(),
          hostId: item['host_nickname'] ?? '익명',
          dept: item['depart_name'],
          dest: item['arrive_name'],
          time: DateTime.parse(item['depart_time']).toLocal().toString().substring(11, 16),
          max: item['capacity'],
          cur: item['current_count'],
          lat: double.parse(item['depart_lat'].toString()),
          lng: double.parse(item['depart_lng'].toString()),
        )).toList();
        _isFetching = false;
      });
    }
  }


  // ✅ 새로 교체할 코드 (서버 통신 버전)
  Future<void> _handleCreate() async {
    // 1. 입력값 검사
    if (_deptCtrl.text.isEmpty || _destCtrl.text.isEmpty) {
      _showSnackBar('출발지와 목적지를 입력해주세요.', AppColors.red);
      return;
    }
    if (_deptLat == null || _destLat == null) {
      _showSnackBar('검색을 통해 장소를 선택해주세요.', AppColors.red);
      return;
    }
    if (_selectedSeat == null) {
      _showSnackBar('본인의 좌석을 선택해주세요.', AppColors.red);
      return;
    }

    // 2. 로딩 상태 시작
    setState(() => _isLoading = true);

    // 3. 시간 데이터 생성
    final now = DateTime.now();
    final departDateTime = DateTime(
      now.year, now.month, now.day,
      _selectedTime.hour, _selectedTime.minute,
    );

    // 4. API 서버에 핀 생성 요청
    final result = await TripService.createTrip(
      token: 'this-is-a-fake-test-token-12345', // 👈 나중에 실제 토큰으로 교체
      deptName: _deptCtrl.text,
      deptLat: _deptLat!,
      deptLng: _deptLng!,
      destName: _destCtrl.text,
      destLat: _destLat!,
      destLng: _destLng!,
      departTime: departDateTime,
      capacity: _maxPeople,
      seatPosition: _selectedSeat!,
      kakaoLink: _kakaoCtrl.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false); // 로딩 종료

    // 5. 결과에 따른 처리
    if (result['success']) {
      // 입력창 초기화
      _deptCtrl.clear(); _destCtrl.clear(); _kakaoCtrl.clear();
      _deptLat = null; _deptLng = null; _destLat = null; _destLng = null;
      _selectedSeat = null;

      // 홈 화면으로 이동
      widget.onGoHome?.call();
    } else {
      // 실패 시 에러 메시지
      _showSnackBar(result['message'], AppColors.red);
    }
  }

  // 메시지 표시를 위한 작은 도구 (에러 알림용)
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: color,
    ));
  }

  // 헬퍼 위젯 (재사용 위젯)
  // 제목 텍스트 표준 스타일
  Widget _label(String text) =>
      Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.secondary));

  // 출발지/목적지 검색 화면 열기
  Future<void> _openLocationSearch(bool isDeparture) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationSearchScreen(
          title: isDeparture ? '출발지' : '목적지',
        ),
      ),
    );

    if (result != null) {
      setState(() {
        if (isDeparture) {
          _deptCtrl.text = result['name'] as String;
          _deptLat = result['lat'] as double;
          _deptLng = result['lng'] as double;
        } else {
          _destCtrl.text = result['name'] as String;
          _destLat = result['lat'] as double;
          _destLng = result['lng'] as double;
        }
      });
    }
  }

  // 장소 검색용 텍스트 필드
  Widget _locationTextField({
    required TextEditingController controller,
    required String hint,
    required bool isDeparture,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              isDeparture ? Icons.location_on : Icons.location_on_outlined,
              color: controller.text.isNotEmpty ? AppColors.primary : AppColors.gray,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                controller.text.isNotEmpty ? controller.text : hint,
                style: TextStyle(
                  fontSize: 14,
                  color: controller.text.isNotEmpty ? AppColors.secondary : AppColors.gray,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.gray, size: 20),
          ],
        ),
      ),
    );
  }

  // 뱃지 스타일
  Widget _tag(String text, {Color color = AppColors.primary, Color bg = AppColors.primaryLight}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
        child: Text(text, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
      );
}

// ============================================================
// 동승 참여 화면 - 참여 버튼 클릭 시 실행
// ============================================================
class RideJoinScreen extends StatefulWidget {
  final Map<String, dynamic> pin;
  const RideJoinScreen({super.key, required this.pin});

  @override
  State<RideJoinScreen> createState() => _RideJoinScreenState();
}

// 참여 화면 상태 관리 및 UI 렌더링
class _RideJoinScreenState extends State<RideJoinScreen> {
  String? _selectedSeat;
  final List<String> _takenSeats = ['조수석', '왼쪽 창가']; // 더미: 실제론 pin 데이터에서

  // 참여 화면 전체 UI 렌더링
  @override
  Widget build(BuildContext context) {
    final pin = widget.pin;
    final int cur = pin['cur'] as int;
    final int max = pin['max'] as int;
    final bool isFull = cur >= max;

    return Scaffold(
      backgroundColor: Colors.white,

      // 앱 바 (참여 화면 상단 헤더)
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton( // 뒤로가기
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.secondary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('동승 참여',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.secondary)),
        centerTitle: true,
        bottom: PreferredSize(  // 하단 구분선
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),

      // 참여 화면 바디
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // 대표자 정보 섹션
            _sectionTitle('👤 대표자'),
            const SizedBox(height: 10),
            _card(child: Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.bg, shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(Icons.person, color: AppColors.gray, size: 28),
                ),
                const SizedBox(width: 14),
                Column( // 대표자 아이디, 뱃지
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('@${pin['hostId']}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.secondary)),
                    const SizedBox(height: 4),
                    Row(children: [
                      _tag('인증됨 ✓'),
                      const SizedBox(width: 4),
                      _tag('⭐ 4.8', color: AppColors.accent, bg: const Color(0xFFFFF8E6)),
                    ]),
                  ],
                ),
              ],
            )),
            const SizedBox(height: 20),

            // 경로 섹션
            _sectionTitle('🗺️ 경로'),
            const SizedBox(height: 10),
            _card(child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: _routeRow(Icons.my_location, AppColors.primary, '출발지', '${pin['dept']}'),
                  ),
                ),
                Column(children: List.generate(3, (_) =>
                    Container(width: 2, height: 6, margin: const EdgeInsets.symmetric(vertical: 2), color: AppColors.border))),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: _routeRow(Icons.location_on, AppColors.red, '목적지', '${pin['dest']}'),
                  ),
                ),
              ],
            )),
            const SizedBox(height: 20),

            // 출발 시간 & 모집 인원 섹션
            Row(
              children: [// 출발 시간
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('🕐 출발 시간'),
                    const SizedBox(height: 10),
                    _card(child: Row(children: [
                      const Icon(Icons.access_time_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text('${pin['time']}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.secondary)),
                    ])),
                  ],
                )),
                const SizedBox(width: 12),
                Expanded(child: Column( // 모집 인원
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('👥 모집 인원'),
                    const SizedBox(height: 10),
                    _card(child: Row(children: [
                      ...List.generate(max, (j) => Container(
                        width: 20, height: 20, margin: const EdgeInsets.only(right: 3),
                        decoration: BoxDecoration(
                          color: j < cur ? AppColors.primary : AppColors.bg,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: j < cur ? AppColors.primary : AppColors.border),
                        ),
                        child: j < cur ? const Icon(Icons.person, color: Colors.white, size: 12) : null,
                      )),
                      const SizedBox(width: 6),
                      Text('$cur/$max', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.secondary)),
                    ])),
                  ],
                )),
              ],
            ),
            const SizedBox(height: 20),

            // 좌석 선택 섹션
            _sectionTitle('💺 좌석 선택'),
            const SizedBox(height: 4),
            const Text('빈 좌석을 선택해 주세요.', style: TextStyle(fontSize: 11, color: AppColors.gray)),
            const SizedBox(height: 10),
            _card(
              child: Padding(
                padding: const EdgeInsets.all(12), // 여기서 전체적인 내부 여백을 조절합니다.
                child: Column(
                  children: [
                    // 1행 — 운전석 / 조수석
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8), // 높이 축소
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F5),
                              border: Border.all(color: AppColors.gray.withOpacity(0.2)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.settings, size: 18, color: AppColors.gray), // 아이콘 축소
                                SizedBox(height: 4),
                                Text('운전석', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.gray)),
                                Text('운전자', style: TextStyle(fontSize: 9, color: AppColors.gray)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: _seatButton('조수석', Icons.airline_seat_recline_extra)),
                      ],
                    ),

                    const SizedBox(height: 8),
                    const Divider(color: AppColors.border, height: 1),
                    const SizedBox(height: 8),

                    // 2행 — 좌석들
                    Row(
                      children: [
                        Expanded(child: _seatButton('왼쪽 창가', Icons.airline_seat_recline_normal)),
                        const SizedBox(width: 8),
                        Expanded(child: _seatButton('가운데', Icons.airline_seat_legroom_normal)),
                        const SizedBox(width: 8),
                        Expanded(child: _seatButton('오른쪽 창가', Icons.airline_seat_recline_normal)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 범례
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _legend(AppColors.primaryLight, AppColors.primary, '선택됨'),
                        const SizedBox(width: 12),
                        _legend(AppColors.bg, AppColors.border, '비어있음'),
                        const SizedBox(width: 12),
                        _legend(const Color(0xFFF5F5F5), AppColors.gray, '사용 중'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // 참여하기 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: (isFull || _selectedSeat == null) ? AppColors.gray : AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: (isFull || _selectedSeat == null) ? null : _handleJoin,
                child: Text(
                  isFull ? '마감된 팀입니다'
                      : _selectedSeat == null ? '좌석을 선택해 주세요'
                      : '참여하기',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  //------------------------------------------------------------------------

  // 좌석 선택 버튼 위젯
  Widget _seatButton(String label, IconData icon) {
    final isTaken = _takenSeats.contains(label);
    final isSelected = _selectedSeat == label;
    final Color bg = isTaken ? const Color(0xFFF5F5F5) : isSelected ? AppColors.primaryLight : AppColors.bg;
    final Color border = isTaken ? AppColors.gray : isSelected ? AppColors.primary : AppColors.border;
    final Color textColor = isTaken ? AppColors.gray : isSelected ? AppColors.primary : AppColors.secondary;

    return GestureDetector(
      onTap: isTaken ? null : () => setState(() => _selectedSeat = isSelected ? null : label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border, width: isSelected ? 1.5 : 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Icon(icon, size: 22, color: isTaken ? AppColors.gray : isSelected ? AppColors.primary : AppColors.secondary),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(isTaken ? '사용 중' : '비어있음', style: TextStyle(fontSize: 10, color: isTaken ? AppColors.gray : AppColors.primary)),
        ]),
      ),
    );
  }

  // 헬퍼 위젯
  // 섹션 카드 공통 스타일
  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white, border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );

  // 경로 섹션 스타일
  Widget _routeRow(IconData icon, Color color, String label, String value) => Row(children: [
    Icon(icon, color: color, size: 22),
    const SizedBox(width: 12),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 10, color: AppColors.gray)),
      Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.secondary)),
    ]),
  ]);

  // 각 섹션 tilte 스타일
  Widget _sectionTitle(String text) =>
      Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.secondary));

  // 뱃지 형태 라벨 위젯 스타일
  Widget _tag(String text, {Color color = AppColors.primary, Color bg = AppColors.primaryLight}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
        child: Text(text, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
      );

  // 좌석 상태 스타일
  Widget _legend(Color bg, Color border, String label) => Row(children: [
    Container(width: 14, height: 14,
        decoration: BoxDecoration(color: bg, border: Border.all(color: border), borderRadius: BorderRadius.circular(4))),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 10, color: AppColors.gray)),
  ]);

  //---------------------------------------------------------------------------------------

  // 참여 완료 다이얼로그 표시 메서드 (참여하기 버튼 클릭 시 실행)
  void _handleJoin() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('참여 완료! 🎉',
            style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.secondary)),
        content: Text('@${widget.pin['hostId']} 팀에 참여했습니다.\n좌석: $_selectedSeat',
            style: const TextStyle(fontSize: 13, color: AppColors.gray)),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(context); Navigator.pop(context); },
            child: const Text('확인', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}