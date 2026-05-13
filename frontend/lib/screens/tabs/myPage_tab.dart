import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../auth/login_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/colors.dart';
import '../../service/auth_service.dart';
import '../../service/auth_session.dart';

// ============================================================
// 공통 컴포넌트: AppBar
// ============================================================
AppBar _appBar(String title) => AppBar(
      title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      backgroundColor: Colors.white,
      foregroundColor: AppColors.secondary,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border)),
    );

// ============================================================
// 1. 마이페이지 탭 (메인)
// ============================================================
class MyPageTab extends StatefulWidget {
  const MyPageTab({super.key});
  @override
  State<MyPageTab> createState() => _MyPageTabState();
}

class _MyPageTabState extends State<MyPageTab> {
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  Future<Map<String, dynamic>>? _profileFuture;

  @override
  void initState() {
    super.initState();
    if (AuthSession.isLoggedIn) {
      _profileFuture = AuthService.getProfile();
    }
  }

  List<_MenuItem> _getDynamicMenus(Map<String, dynamic> userData) {
    final String score = userData['trust_score']?.toString() ?? '36.5';
    final int count = userData['successful_streak_count'] ?? 0;

    return [
      _MenuItem(icon: Icons.verified_user_outlined, label: '인증 관리', sub: '본인 및 신원 인증', screen: const _AuthScreen()),
      _MenuItem(icon: Icons.star_outline, label: '회원 매너 점수 관리', sub: '현재 $score점', screen: const _MannerScreen()),
      _MenuItem(icon: Icons.local_taxi_outlined, label: '이용 내역', sub: '총 $count건', screen: const HistoryScreen()),
      _MenuItem(icon: Icons.settings_outlined, label: '설정', sub: '알림, 약관, 버전 정보', screen: const SettingsScreen()),
      _MenuItem(icon: Icons.headset_mic_outlined, label: '고객지원', sub: '문의 및 전화 상담', screen: const SupportScreen()),
      _MenuItem(icon: Icons.flag_outlined, label: '신고하기', sub: '부적절한 이용자 신고', screen: const _ReportScreen(), color: AppColors.red),
      _MenuItem(icon: Icons.logout, label: '로그아웃', sub: null, screen: null, color: AppColors.red),
    ];
  }

  void _showImagePickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
              const Align(alignment: Alignment.centerLeft, child: Text('프로필 사진 변경', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.secondary))),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.photo_library_outlined, color: AppColors.primary, size: 22)),
                title: const Text('갤러리에서 선택', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: const Text('앨범에서 사진을 가져옵니다', style: TextStyle(fontSize: 11, color: AppColors.gray)),
                onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
              ),
              const Divider(color: AppColors.border, height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFF0F4FF), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.camera_alt_outlined, color: Color(0xFF4A6FFF), size: 22)),
                title: const Text('카메라로 촬영', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: const Text('지금 바로 사진을 촬영합니다', style: TextStyle(fontSize: 11, color: AppColors.gray)),
                onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(source: source, imageQuality: 80, maxWidth: 512, maxHeight: 512);
      if (picked != null) {
        setState(() => _profileImage = File(picked.path));
        final result = await AuthService.updateProfileImage(File(picked.path));
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'])));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('사진을 불러올 수 없습니다.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_profileFuture == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 48, color: AppColors.gray),
              const SizedBox(height: 16),
              const Text('로그인이 필요한 서비스입니다.', style: TextStyle(color: AppColors.secondary)),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: () => Navigator.pushNamed(context, '/login'), child: const Text('로그인하러 가기')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data?['success'] == false) return const Center(child: Text('데이터 로딩 실패'));
          final userData = snapshot.data?['data'];
          if (userData == null) return const Center(child: Text('프로필 데이터를 불러올 수 없습니다.'));

          final currentMenus = _getDynamicMenus(userData);

          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildProfileHeader(userData),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(children: currentMenus.map((m) => _buildMenuItem(context, m)).toList()),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> userData) {
    final String realName = userData['user_real_name'] ?? '이름 없음';
    final String username = userData['username'] ?? 'unknown';
    final String trustScore = userData['trust_score']?.toString() ?? '36.5';
    final int tripCount = userData['successful_streak_count'] ?? 0;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
      child: Column(
        children: [
          GestureDetector(
            onTap: _showImagePickerSheet,
            child: Stack(
              children: [
                Container(
                  width: 84, height: 84,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.bg, border: Border.all(color: AppColors.border, width: 2)),
                  child: ClipOval(
                    child: userData['profile_img_url'] != null
                        ? Image.network(userData['profile_img_url'], fit: BoxFit.cover)
                        : const Icon(Icons.person, color: AppColors.gray, size: 48),
                  ),
                ),
                Positioned(
                  right: 0, bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(realName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.secondary)),
          const SizedBox(height: 4),
          Text('@$username', style: const TextStyle(fontSize: 12, color: AppColors.gray)),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [
            _tag('인증됨 ✓'),
            _tag('⭐ $trustScore', color: AppColors.accent, bg: const Color(0xFFFFF8E6)),
            _tag('탑승 $tripCount회'),
          ]),
          Container(
            margin: const EdgeInsets.only(top: 20),
            padding: const EdgeInsets.only(top: 16),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
            child: Row(children: [
              _stat('$tripCount회', '총 탑승'),
              Container(width: 1, height: 36, color: AppColors.border),
              _stat('$trustScore점', '매너점수', color: AppColors.accent),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _stat(String val, String label, {Color color = AppColors.primary}) {
    return Expanded(child: Column(children: [
      Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.gray)),
    ]));
  }

  Widget _tag(String t, {Color color = AppColors.primary, Color bg = AppColors.primaryLight}) =>
      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
          child: Text(t, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)));

  Widget _buildMenuItem(BuildContext context, _MenuItem menu) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            if (menu.label == '로그아웃') { _showLogoutDialog(context); return; }
            if (menu.screen != null) { Navigator.push(context, MaterialPageRoute(builder: (_) => menu.screen!)); }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: menu.color != null ? menu.color!.withOpacity(0.1) : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(menu.icon, color: menu.color ?? AppColors.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(menu.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: menu.color ?? AppColors.secondary)),
                  if (menu.sub != null) Text(menu.sub!, style: const TextStyle(fontSize: 11, color: AppColors.gray)),
                ],
              )),
              const Icon(Icons.chevron_right, color: AppColors.border, size: 22),
            ]),
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('로그아웃', style: TextStyle(fontWeight: FontWeight.w700)),
      content: const Text('정말 로그아웃 하시겠어요?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white, elevation: 0),
            onPressed: () async {
              Navigator.pop(context);
              await AuthService.logout();
              if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
            }, child: const Text('로그아웃')),
      ],
    ));
  }
}

// ============================================================
// 2. 이용 내역 화면 (History)
// ============================================================
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _histories = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      final history = await AuthService.getTripHistory();
      setState(() { _histories = history; _isLoading = false; });
    } catch (e) {
      setState(() { _error = '이용 내역을 불러오는데 실패했습니다: $e'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthSession.isLoggedIn) return Scaffold(appBar: _appBar('이용 내역'), body: const Center(child: Text('로그인이 필요합니다.')));
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _appBar('이용 내역'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.red)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _histories.length,
              itemBuilder: (_, i) => _buildHistoryCard(_histories[i]),
            ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> h) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
            child: Row(children: [
              const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.gray),
              const SizedBox(width: 6),
              Text(h['date'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.gray)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(100)),
                child: Text(h['status'] ?? '완료', style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h['team'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.secondary)),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.location_on, size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(h['dept'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('→', style: TextStyle(color: AppColors.textSub, fontWeight: FontWeight.w700))),
                  Text(h['dest'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.secondary)),
                ]),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    Text('내 부담액', style: const TextStyle(fontSize: 12, color: AppColors.gray)),
                    const Spacer(),
                    Text('₩${h['my'] ?? '0'}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary)),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 3. 설정 화면 (Settings)
// ============================================================
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushAlarm = true;
  bool _chatAlarm = true;
  bool _nightAlarm = false;
  bool _chatEnterAlarm = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _appBar('설정'),
      body: ListView(
        children: [
          _sectionTitle('🔔 알림 설정'),
          _switchTile('푸시 알림 동의', '앱 전체 알림 수신', _pushAlarm, (v) => setState(() => _pushAlarm = v)),
          _switchTile('채팅 알림', '채팅방 메시지 알림', _chatAlarm, (v) => setState(() => _chatAlarm = v)),
          _switchTile('야간 알림 (22시~8시)', '야간 시간대 알림 차단', _nightAlarm, (v) => setState(() => _nightAlarm = v)),
          _sectionTitle('💬 채팅 설정'),
          _switchTile('채팅방 입장 알림', '누군가 입장 시 알림', _chatEnterAlarm, (v) => setState(() => _chatEnterAlarm = v)),
          _navTile('채팅 글꼴 크기', '기본', () {}),
          _sectionTitle('📋 약관 및 정책'),
          _navTile('개인정보 처리방침', null, () {}),
          _navTile('서비스 이용약관', null, () {}),
          _sectionTitle('⚠️ 계정'),
          _navTile('탈퇴하기', null, () => _showWithdrawDialog(context), color: AppColors.red, icon: Icons.person_remove_outlined),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 8), child: Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.gray)));
  Widget _switchTile(String label, String sub, bool value, ValueChanged<bool> onChanged) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), Text(sub, style: const TextStyle(fontSize: 11, color: AppColors.gray))])),
        Switch(value: value, activeColor: AppColors.primary, onChanged: onChanged),
      ]),
    ),
  );
  Widget _navTile(String label, String? value, VoidCallback onTap, {Color? color, IconData? icon}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: Material(color: Colors.white, borderRadius: BorderRadius.circular(14), child: InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          if (icon != null) ...[Icon(icon, color: color ?? AppColors.secondary, size: 20), const SizedBox(width: 14)],
          Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color ?? AppColors.secondary)),
          const Spacer(),
          if (value != null) Text(value, style: const TextStyle(fontSize: 12, color: AppColors.gray)),
          const Icon(Icons.chevron_right, color: AppColors.border, size: 20),
        ]),
      ),
    )),
  );

  void _showWithdrawDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('탈퇴하기', style: TextStyle(color: AppColors.red)),
      content: const Text('정말 탈퇴하시겠습니까?'),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.red), onPressed: () {}, child: const Text('탈퇴'))],
    ));
  }
}

// ============================================================
// 4. 고객지원 화면 (Support)
// ============================================================
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _appBar('고객지원'),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          _supportCard(Icons.phone, '전화 문의', '1588-0000', AppColors.primary, () async => await launchUrl(Uri.parse('tel:15880000'))),
          const SizedBox(height: 12),
          _supportCard(Icons.email_outlined, '이메일 문의', 'support@taximate.app', const Color(0xFF4A6FFF), () async => await launchUrl(Uri.parse('mailto:support@taximate.app'))),
        ]),
      ),
    );
  }

  Widget _supportCard(IconData icon, String title, String val, Color color, VoidCallback onTap) => Material(
    color: Colors.white, borderRadius: BorderRadius.circular(16),
    child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: Container(
      padding: const EdgeInsets.all(20), decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Container(width: 52, height: 52, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: color, size: 28)),
        const SizedBox(width: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)), Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color))]),
        const Spacer(), const Icon(Icons.chevron_right, color: AppColors.border),
      ]),
    )),
  );
}

// ============================================================
// 5. 매너 로그 화면 (Manner)
// ============================================================
class _MannerScreen extends StatefulWidget {
  const _MannerScreen();
  @override
  State<_MannerScreen> createState() => _MannerScreenState();
}

class _MannerScreenState extends State<_MannerScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    final logs = await AuthService.getTrustScoreLogs();
    setState(() { _logs = logs; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _appBar('매너 로그'),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _logs.length,
        itemBuilder: (_, i) => _buildLogCard(_logs[i]),
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    final isGain = log['direction'] == 'GAIN';
    final color = isGain ? AppColors.primary : AppColors.red;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(isGain ? Icons.arrow_upward : Icons.arrow_downward, color: color, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(log['event_type'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)), Text(log['created_at'], style: const TextStyle(fontSize: 11, color: AppColors.gray))])),
        Text(log['applied_delta'], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
      ]),
    );
  }
}

// ============================================================
// 6. 신고하기 화면 (Report)
// ============================================================
class _ReportScreen extends StatefulWidget {
  const _ReportScreen();
  @override
  State<_ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<_ReportScreen> {
  List<_RecentPassenger> _passengers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final list = await AuthService.getRecentCompanions();
    setState(() {
      _passengers = list.map((c) => _RecentPassenger(id: c['id'].toString(), nickname: c['nickname'], rideDate: c['ride_date'], route: c['route'])).toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _appBar('신고하기'),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : Column(children: [
        Container(padding: const EdgeInsets.all(20), color: AppColors.bg, child: const Row(children: [Icon(Icons.info_outline, color: AppColors.primary), SizedBox(width: 12), Expanded(child: Text('최근 동승자 중 신고할 이용자를 선택해주세요.'))])),
        Expanded(child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: _passengers.length, itemBuilder: (_, i) => _buildPassengerCard(_passengers[i]))),
      ]),
    );
  }

  Widget _buildPassengerCard(_RecentPassenger p) => GestureDetector(
    onTap: () {}, // 바텀시트 로직 등 연결 가능
    child: Container(
      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        const CircleAvatar(backgroundColor: AppColors.bg, child: Icon(Icons.person, color: AppColors.gray)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(p.nickname, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)), Text(p.route, style: const TextStyle(fontSize: 12, color: AppColors.primary))])),
        Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: AppColors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Text('신고', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.bold))),
      ]),
    ),
  );
}

// 보조 클래스 및 미구현 화면
class _MenuItem {
  final IconData icon; final String label; final String? sub; final Widget? screen; final Color? color;
  const _MenuItem({required this.icon, required this.label, this.sub, this.screen, this.color});
}
class _RecentPassenger {
  final String id, nickname, rideDate, route;
  _RecentPassenger({required this.id, required this.nickname, required this.rideDate, required this.route});
}
class _AuthScreen extends StatelessWidget { const _AuthScreen(); @override Widget build(_) => Scaffold(appBar: _appBar('인증 관리'), body: const Center(child: Text('화면 준비 중'))); }