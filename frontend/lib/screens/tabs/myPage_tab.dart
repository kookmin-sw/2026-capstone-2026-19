// ============================================================
// lib/screens/tabs/myPage_tab.dart
// ============================================================
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../auth/login_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/colors.dart';
import '../../service/auth_service.dart';
import '../../service/auth_session.dart';

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

      // 📍 핵심: 로그인이 안 되어 있으면 서버에 묻지 말고 '가짜 실패 데이터'를 바로 넣어줍니다.
      // 이렇게 하면 late 변수가 비어있지 않게 되어 앱이 즉사하지 않습니다!
     if (AuthSession.isLoggedIn) {
           _profileFuture = AuthService.getProfile();
      }
    }

  // 데이터에 따라 메뉴 리스트를 동적으로 생성하는 함수
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
                  '프로필 사진 변경',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.secondary),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.photo_library_outlined, color: AppColors.primary, size: 22),
                ),
                title: const Text('갤러리에서 선택', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: const Text('앨범에서 사진을 가져옵니다', style: TextStyle(fontSize: 11, color: AppColors.gray)),
                onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
              ),
              const Divider(color: AppColors.border, height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: const Color(0xFFF0F4FF), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.camera_alt_outlined, color: Color(0xFF4A6FFF), size: 22),
                ),
                title: const Text('카메라로 촬영', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: const Text('지금 바로 사진을 촬영합니다', style: TextStyle(fontSize: 11, color: AppColors.gray)),
                onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
              ),
              if (_profileImage != null) ...[
                const Divider(color: AppColors.border, height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delete_outline, color: AppColors.red, size: 22),
                  ),
                  title: const Text('프로필 사진 삭제',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _profileImage = null);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (picked != null) {
        setState(() => _profileImage = File(picked.path));

        try {
          // AuthService 호출 대신 딜레이로 업로드 효과 시뮬레이션
          await Future.delayed(const Duration(milliseconds: 600));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('프로필 사진이 업데이트되었습니다.')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('프로필 업데이트 실패: $e')),
            );
          }
        }
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

  @override
    Widget build(BuildContext context) {
      // 📍 1. 입구 컷: 준비된 데이터(_profileFuture)가 없으면(스킵된 상태면) 아예 퓨처빌더를 안 돌립니다.
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
                ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  child: const Text('로그인하러 가기'),
                ),
              ],
            ),
          ),
        );
      }

      // 📍 2. 로그인이 되어 있어서 _profileFuture가 세팅되었다면, 기존처럼 퓨처빌더로 화면을 그립니다.
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: FutureBuilder<Map<String, dynamic>>(
          future: _profileFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (!snapshot.hasData || snapshot.data?['success'] == false) return const Center(child: Text('데이터 로딩 실패'));

            final userData = snapshot.data?['data'];

            // 만약 통신은 성공했는데 데이터가 꼬여서 null이 올 경우를 대비한 최소한의 방어막
            if (userData == null) {
              return const Center(
                child: Text('프로필 데이터를 불러올 수 없습니다.'),
              );
            }

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
    // DB 필드명과 매칭 (장고 User 모델 기준)
    final String realName = userData['user_real_name'] ?? '이름 없음';
    final String username = userData['username'] ?? 'unknown';
    final String trustScore = userData['trust_score']?.toString() ?? '36.5';
    final int tripCount = userData['successful_streak_count'] ?? 0; // 예시: 성공 횟수를 탑승 횟수로 활용

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
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.bg,
                    border: Border.all(color: AppColors.border, width: 2),
                  ),
                  child: ClipOval(
                    child: userData['profile_img_url'] != null
                        ? Image.network(userData['profile_img_url'], fit: BoxFit.cover) // 네트워크 이미지로 변경
                        : const Icon(Icons.person, color: AppColors.gray, size: 48),
                  ),
                ),
                // ... 카메라 아이콘 Stack 부분은 동일
              ],
            ),
          ),
          const SizedBox(height: 14),
          // 1. 이름 (실명) 연동
          Text(realName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.secondary)),
          const SizedBox(height: 4),
          // 2. 아이디 연동
          Text('@$username', style: const TextStyle(fontSize: 12, color: AppColors.gray)),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [
            _tag('인증됨 ✓'),
            _tag('⭐ $trustScore', color: AppColors.accent, bg: const Color(0xFFFFF8E6)), // 매너점수
            _tag('탑승 $tripCount회'), // 탑승 횟수 연동
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

  Widget _buildMenuItem(BuildContext context, _MenuItem menu) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            if (menu.label == '로그아웃') { _showLogoutDialog(context); return; }
            if (menu.screen != null) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => menu.screen!));
            }
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

  Widget _tag(String t, {Color color = AppColors.primary, Color bg = AppColors.primaryLight}) =>
      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
          child: Text(t, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)));

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
              try {
                // AuthService 호출 대신 딜레이로 로그아웃 효과 시뮬레이션
                await Future.delayed(const Duration(milliseconds: 500));
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('로그아웃 실패: $e')),
                  );
                }
              }
            },
            child: const Text('로그아웃')),
      ],
    ));
  }
}

class _MenuItem {
  final IconData icon; final String label; final String? sub; final Widget? screen; final Color? color;
  const _MenuItem({required this.icon, required this.label, this.sub, this.screen, this.color});
}

// ============================================================
// 이용 내역 화면
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
        // 🚨 기존 더미 데이터 생성 코드(await Future.delayed... 부터)를 싹 지우고
        // 아래처럼 AuthService를 호출해서 진짜 서버 데이터를 가져옵니다!
        final history = await AuthService.getTripHistory();

        setState(() {
          _histories = history;
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _error = '이용 내역을 불러오는데 실패했습니다: $e';
          _isLoading = false;
        });
      }
    }

  Widget build(BuildContext context) {
    // 📍 1. 로그인 상태를 먼저 체크합니다. (가장 중요!)
    if (!AuthSession.isLoggedIn) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: _appBar('이용 내역'),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 48, color: AppColors.gray),
              const SizedBox(height: 16),
              const Text('로그인이 필요한 서비스입니다.', style: TextStyle(color: AppColors.secondary)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/login'),
                child: const Text('로그인하러 가기'),
              ),
            ],
          ),
        ),
      );
    }

    // 📍 2. 로그인이 된 경우에만 아래 로직을 수행합니다.
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _appBar('이용 내역'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: _buildErrorUI()) // 에러 UI를 별도로 빼면 코드가 깔끔해집니다.
              : _histories.isEmpty
                  ? const Center(child: Text('이용 내역이 없습니다.', style: TextStyle(color: AppColors.gray)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _histories.length,
                      itemBuilder: (_, i) => _buildHistoryCard(_histories[i]),
                    ),
    );
  }

  // 📍 별도의 에러 처리 UI (선택 사항)
  Widget _buildErrorUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(_error!, style: const TextStyle(color: AppColors.red)),
        TextButton(onPressed: _fetchHistory, child: const Text('다시 시도')),
      ],
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
              Text(h['date'] as String, style: const TextStyle(fontSize: 12, color: AppColors.gray)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(100)),
                child: Text(h['status'] as String,
                    style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h['team'] as String,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.secondary)),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.location_on, size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(h['dept'] as String, style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                  const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Text('→', style: TextStyle(color: AppColors.textSub, fontWeight: FontWeight.w700))),
                  Text(h['dest'] as String, style: const TextStyle(fontSize: 12, color: AppColors.secondary)),
                ]),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(10)),
                  child: Column(children: [
                    _infoRow('탑승 인원', '${h['members']}명'),
                    const SizedBox(height: 6),
                    _infoRow('총 택시비', '₩${h['total']}'),
                    const SizedBox(height: 6),
                    Row(children: [
                      Text('내 부담액 (1/${h['members']})', style: const TextStyle(fontSize: 12, color: AppColors.gray)),
                      const Spacer(),
                      Text('₩${h['my']}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary)),
                    ]),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) => Row(children: [
    Text(label, style: const TextStyle(fontSize: 12, color: AppColors.gray)),
    const Spacer(),
    Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.secondary)),
  ]);
}

// ============================================================
// 설정 화면
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
          _switchTile('푸시 알림 동의',       '앱 전체 알림 수신',      _pushAlarm,      (v) => setState(() => _pushAlarm = v)),
          _switchTile('채팅 알림',             '채팅방 메시지 알림',     _chatAlarm,      (v) => setState(() => _chatAlarm = v)),
          _switchTile('야간 알림 (22시~8시)',  '야간 시간대 알림 차단',  _nightAlarm,     (v) => setState(() => _nightAlarm = v)),
          _sectionTitle('💬 채팅 설정'),
          _switchTile('채팅방 입장 알림',      '누군가 입장 시 알림',    _chatEnterAlarm, (v) => setState(() => _chatEnterAlarm = v)),
          _navTile('채팅 글꼴 크기',    '기본',         () {}),
          _navTile('미디어 자동 저장',  '와이파이에서만', () {}),
          _sectionTitle('📋 약관 및 정책'),
          _navTile('개인정보 처리방침',      null, () => _openUrl('https://taximate.app/privacy')),
          _navTile('위치기반 서비스 약관',   null, () => _openUrl('https://taximate.app/location')),
          _navTile('오픈 소스 라이센스',     null, () {}),
          _navTile('서비스 이용약관',        null, () {}),
          _sectionTitle('ℹ️ 앱 정보'),
          _navTile('버전 정보', 'v1.0.0', () {}),
          _sectionTitle('⚠️ 계정'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Material(
              color: Colors.white, borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _showWithdrawDialog(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(14)),
                  child: const Row(children: [
                    Icon(Icons.person_remove_outlined, color: AppColors.red, size: 20),
                    SizedBox(width: 14),
                    Text('탈퇴하기', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.red)),
                    Spacer(),
                    Icon(Icons.chevron_right, color: AppColors.border, size: 22),
                  ]),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
    child: Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.gray, letterSpacing: 0.5)),
  );

  Widget _switchTile(String label, String sub, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            Text(sub, style: const TextStyle(fontSize: 11, color: AppColors.gray)),
          ])),
          Switch(value: value, activeColor: AppColors.primary, onChanged: onChanged),
        ]),
      ),
    );
  }

  Widget _navTile(String label, String? value, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(color: Colors.white, borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14), onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
            child: Row(children: [
              Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (value != null) Text(value, style: const TextStyle(fontSize: 12, color: AppColors.gray)),
              const Icon(Icons.chevron_right, color: AppColors.border, size: 20),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showWithdrawDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('탈퇴하기', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.red)),
      content: const Text('탈퇴하면 모든 이용 내역과 채팅 데이터가 삭제됩니다.\n정말 탈퇴하시겠습니까?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white, elevation: 0),
            onPressed: () async {
              Navigator.pop(context);
              try {
                // 더미 결과 처리
                await Future.delayed(const Duration(milliseconds: 800));
                final result = {'success': true, 'is_blocked': true, 'message': '탈퇴가 완료되었습니다.'};

                if (context.mounted) {
                  if (result['is_blocked'] == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('1년간 재가입이 제한됩니다'),
                        backgroundColor: AppColors.red,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(result['message'] as String? ?? '탈퇴가 완료되었습니다.')),
                    );
                  }

                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('탈퇴 처리 중 오류가 발생했습니다: $e')),
                  );
                }
              }
            },
            child: const Text('탈퇴하기')),
      ],
    ));
  }
}

// ============================================================
// 고객지원 화면
// ============================================================
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});
  static const _phone = '1588-0000';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _appBar('고객지원'),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity, padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primaryLight, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('고객센터 운영 시간', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary)),
                SizedBox(height: 6),
                Text('평일 09:00 ~ 18:00', style: TextStyle(fontSize: 14, color: AppColors.secondary, fontWeight: FontWeight.w600)),
                SizedBox(height: 2),
                Text('주말 및 공휴일 휴무', style: TextStyle(fontSize: 12, color: AppColors.gray)),
              ]),
            ),
            const SizedBox(height: 20),
            Material(
              color: Colors.white, borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  final uri = Uri(scheme: 'tel', path: _phone.replaceAll('-', ''));
                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                },
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                  child: Row(children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.phone, color: AppColors.primary, size: 28),
                    ),
                    const SizedBox(width: 16),
                    const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('전화 문의', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      SizedBox(height: 4),
                      Text(_phone, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 1)),
                      Text('클릭하면 바로 연결됩니다', style: TextStyle(fontSize: 11, color: AppColors.gray)),
                    ]),
                    const Spacer(),
                    const Icon(Icons.chevron_right, color: AppColors.border),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Material(
              color: Colors.white, borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  final uri = Uri(scheme: 'mailto', path: 'support@taximate.app',
                      queryParameters: {'subject': 'TaxiMate 문의'});
                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                },
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                  child: Row(children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(color: const Color(0xFFF0F4FF), borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.email_outlined, color: Color(0xFF4A6FFF), size: 28),
                    ),
                    const SizedBox(width: 16),
                    const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('이메일 문의', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      SizedBox(height: 4),
                      Text('support@taximate.app',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF4A6FFF))),
                    ]),
                    const Spacer(),
                    const Icon(Icons.chevron_right, color: AppColors.border),
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

AppBar _appBar(String title) => AppBar(
  title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
  backgroundColor: Colors.white, foregroundColor: AppColors.secondary,
  elevation: 0, surfaceTintColor: Colors.transparent,
  bottom: const PreferredSize(
      preferredSize: Size.fromHeight(1),
      child: Divider(height: 1, color: AppColors.border)),
);

class _SubScreen extends StatelessWidget {
  final String title, icon;
  const _SubScreen({required this.title, required this.icon});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: _appBar(title),
    body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(icon, style: const TextStyle(fontSize: 52)),
      const SizedBox(height: 16),
      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      const Text('화면 준비 중입니다.', style: TextStyle(fontSize: 13, color: AppColors.gray)),
    ])),
  );
}

class _AuthScreen   extends StatelessWidget { const _AuthScreen();   @override Widget build(_) => const _SubScreen(title: '인증 관리', icon: '🛡️'); }

// ============================================================
// 매너 로그 화면
// ============================================================
class _MannerScreen extends StatefulWidget {
  const _MannerScreen();

  @override
  State<_MannerScreen> createState() => _MannerScreenState();
}

class _MannerScreenState extends State<_MannerScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchMannerLogs();
  }

  Future<void> _fetchMannerLogs() async {
    try {
      final logs = await AuthService.getTrustScoreLogs();

      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '매너 로그를 불러오는데 실패했습니다: $e';
        _isLoading = false;
      });
    }
  }

  String _formatDate(String dateStr) {
    final date = DateTime.parse(dateStr);
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  String _getEventDisplayName(String eventType, String reasonDetail) {
    // MANUAL_ADJUST 중 정산 지연 패널티 특수 처리
    if (eventType == 'MANUAL_ADJUST' && reasonDetail.contains('정산 지연')) {
      return '정산 지연 패널티';
    }

    final names = {
      'TRIP_LEADER_SUCCESS': '팀장 성공',
      'TRIP_PARTICIPATION_COMPLETE': '동승 완료',
      'TRIP_PARTICIPATION_COMPLETED': '동승 완료',
      'FAST_SETTLEMENT': '빠른 정산',
      'STREAK_BONUS': '연속 보너스',
      'NORMAL_CANCEL': '일반 취소',
      'URGENT_CANCEL': '긴급 취소',
      'NO_SHOW': '노쇼',
      'MANUAL_ADJUST': '수동 조정',
    };
    return names[eventType] ?? eventType;
  }

  Color _getDirectionColor(String direction) {
    switch (direction) {
      case 'GAIN':
        return AppColors.primary;
      case 'PENALTY':
        return AppColors.red;
      case 'ADJUST':
        return AppColors.accent;
      default:
        return AppColors.gray;
    }
  }

  IconData _getDirectionIcon(String direction) {
    switch (direction) {
      case 'GAIN':
        return Icons.arrow_upward;
      case 'PENALTY':
        return Icons.arrow_downward;
      case 'ADJUST':
        return Icons.sync;
      default:
        return Icons.remove;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _appBar('매너 로그'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.red)))
              : _logs.isEmpty
                  ? const Center(child: Text('매너 로그가 없습니다.', style: TextStyle(color: AppColors.gray)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _logs.length,
                      itemBuilder: (_, index) => _buildLogCard(_logs[index]),
                    ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    final direction = log['direction'] as String;
    final color = _getDirectionColor(direction);
    final icon = _getDirectionIcon(direction);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getEventDisplayName(
                          log['event_type'] as String,
                          log['reason_detail'] as String? ?? '',
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.secondary,
                        ),
                      ),
                      Text(
                        _formatDate(log['created_at'] as String),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.gray,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    log['applied_delta'] as String,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log['reason_detail'] as String? ?? '',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text(
                        '변경 후 점수: ',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.gray,
                        ),
                      ),
                      Text(
                        '${log['score_after']}점',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 신고 화면
// ============================================================
class _ReportScreen extends StatefulWidget {
  const _ReportScreen();

  @override
  State<_ReportScreen> createState() => _ReportScreenState();
}

class _RecentPassenger {
  final String id;
  final String nickname;
  final String rideDate;
  final String route;
  final String profileImage;

  const _RecentPassenger({
    required this.id,
    required this.nickname,
    required this.rideDate,
    required this.route,
    this.profileImage = '',
  });
}

class _ReportScreenState extends State<_ReportScreen> {
  List<_RecentPassenger> _recentPassengers = [];
  bool _isLoading = true;
  String? _error;

  String _selectedReason = '노쇼';
  final TextEditingController _detailController = TextEditingController();

  final List<String> _reportReasons = ['노쇼', '비매너 행위', '무단 이탈', '기타'];

  @override
  void initState() {
    super.initState();
    _fetchRecentCompanions();
  }

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  Future<void> _fetchRecentCompanions() async {
    try {
      // 더미 데이터
      await Future.delayed(const Duration(milliseconds: 800));
      final companions = [
        {'id': 'user_001', 'nickname': '@taxi_kim', 'ride_date': '오늘 14:30', 'route': '강남역 → 김포공항'},
        {'id': 'user_002', 'nickname': '@seoul_lee', 'ride_date': '어제 15:00', 'route': '홍대입구역 → 인천공항 T1'},
        {'id': 'user_003', 'nickname': '@rider_park', 'ride_date': '3일 전 14:45', 'route': '잠실역 → 강남역'},
        {'id': 'user_004', 'nickname': '@go_choi', 'ride_date': '1주일 전 16:00', 'route': '신촌역 → 판교역'},
      ];

      setState(() {
        _recentPassengers = companions.map((c) => _RecentPassenger(
          id: c['id'] ?? '',
          nickname: c['nickname'] ?? '',
          rideDate: c['ride_date'] ?? '',
          route: c['route'] ?? '',
        )).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '동승자 목록을 불러오는데 실패했습니다: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _submitReport(String reportedUserId, String tripId) async {
    // API 호출 대신 딜레이
    await Future.delayed(const Duration(seconds: 1));
  }

  void _showReportBottomSheet(_RecentPassenger passenger) {
    _selectedReason = '노쇼';
    _detailController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 20,
            left: 24,
            right: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(Icons.person, color: AppColors.gray, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          passenger.nickname,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.secondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          passenger.route,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.gray,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                '신고 사유',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 12),
              ..._reportReasons.map((reason) => RadioListTile<String>(
                title: Text(
                  reason,
                  style: const TextStyle(fontSize: 14, color: AppColors.secondary),
                ),
                value: reason,
                groupValue: _selectedReason,
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
                dense: true,
                onChanged: (value) {
                  setSheetState(() {
                    _selectedReason = value!;
                  });
                },
              )),
              const SizedBox(height: 20),
              const Text(
                '상세 내용',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _detailController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: '구체적인 상황을 설명해주세요...',
                  hintStyle: const TextStyle(fontSize: 13, color: AppColors.gray),
                  filled: true,
                  fillColor: AppColors.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.gray,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('취소', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await _submitReport(passenger.id, 'trip_dummy_id');
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('신고가 접수되었습니다'),
                              backgroundColor: AppColors.primary,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        '신고 제출',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('신고하기', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.secondary,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.red)))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      color: AppColors.bg,
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '최근 동승자 중 신고할 이용자를 선택해주세요.\n허위 신고 시 제재를 받을 수 있습니다.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.secondary.withOpacity(0.8),
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
                      child: Text(
                        '최근 동승자',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.secondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _recentPassengers.isEmpty
                          ? const Center(child: Text('최근 동승자가 없습니다.', style: TextStyle(color: AppColors.gray)))
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _recentPassengers.length,
                              itemBuilder: (context, index) {
                                final passenger = _recentPassengers[index];
                                return _buildPassengerCard(passenger);
                              },
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildPassengerCard(_RecentPassenger passenger) {
    return GestureDetector(
      onTap: () => _showReportBottomSheet(passenger),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.bg,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.person, color: AppColors.gray, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    passenger.nickname,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 12, color: AppColors.gray),
                      const SizedBox(width: 4),
                      Text(
                        passenger.rideDate,
                        style: const TextStyle(fontSize: 12, color: AppColors.gray),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.route, size: 12, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          passenger.route,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.flag, size: 14, color: AppColors.red),
                  SizedBox(width: 4),
                  Text(
                    '신고',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.red,
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
}