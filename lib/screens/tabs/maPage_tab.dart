// ============================================================
// lib/screens/tabs/myPage_tab.dart
// ============================================================
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:project/screens/auth/login_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/colors.dart';

class MyPageTab extends StatefulWidget {
  const MyPageTab({super.key});
  @override
  State<MyPageTab> createState() => _MyPageTabState();
}

class _MyPageTabState extends State<MyPageTab> {

  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  late final List<_MenuItem> _menus = [
    _MenuItem(icon: Icons.verified_user_outlined,  label: '인증 관리',        sub: '본인 및 신원 인증',    screen: const _AuthScreen()),
    // 프로필 관리
    _MenuItem(icon: Icons.star_outline,            label: '회원 매너 점수 관리', sub: '현재 4.8점',         screen: const _MannerScreen()),
    _MenuItem(icon: Icons.local_taxi_outlined,     label: '이용 내역',         sub: '총 12건',              screen: const HistoryScreen()),
    _MenuItem(icon: Icons.settings_outlined,       label: '설정',              sub: '알림, 약관, 버전 정보', screen: const SettingsScreen()),
    _MenuItem(icon: Icons.headset_mic_outlined,    label: '고객지원',          sub: '문의 및 전화 상담',    screen: const SupportScreen()),
    _MenuItem(icon: Icons.flag_outlined,           label: '신고하기',          sub: '부적절한 이용자 신고', screen: const _ReportScreen(), color: AppColors.red),
    _MenuItem(icon: Icons.logout,                  label: '로그아웃',          sub: null, screen: null, color: AppColors.red),
  ];

  // 프로필 이미지 선택 바
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
              // 핸들 바
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
              // 갤러리 선택
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
              // 카메라 촬영
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
              // 사진 삭제 (기존 사진이 있을 때만 표시)
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

  // ← 추가: 실제 이미지 선택 처리
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,     // 이미지 압축 품질 (0~100)
        maxWidth: 512,        // 최대 가로 크기 (px)
        maxHeight: 512,       // 최대 세로 크기 (px)
      );
      if (picked != null) {
        setState(() => _profileImage = File(picked.path));
      }
    } catch (e) {
      // 권한 거부 등 예외 처리
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
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildProfileHeader(),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(children: _menus.map((m) => _buildMenuItem(context, m)).toList()),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
      child: Column(
        children: [
          // ─────────────────────────────────────────────
          // ← 변경: GestureDetector로 프로필 전체 영역 탭 감지
          // ─────────────────────────────────────────────
          GestureDetector(
            onTap: _showImagePickerSheet,
            child: Stack(
              children: [
                // 프로필 이미지
                Container(
                  width: 84, height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.bg,
                    border: Border.all(color: AppColors.border, width: 2),
                  ),
                  child: ClipOval(
                    child: _profileImage != null
                    // ← 선택된 이미지가 있으면 표시
                        ? Image.file(_profileImage!, fit: BoxFit.cover)
                    // ← 없으면 기본 아이콘
                        : const Icon(Icons.person, color: AppColors.gray, size: 48),
                  ),
                ),
                // 카메라 버튼
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                  ),
                ),
              ],
            ),
          ),
          // ─────────────────────────────────────────────
          const SizedBox(height: 14),
          const Text('홍길동', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.secondary)),
          const SizedBox(height: 4),
          const Text('@my_username', style: TextStyle(fontSize: 12, color: AppColors.gray)),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [
            _tag('인증됨 ✓'),
            _tag('⭐ 4.8', color: AppColors.accent, bg: const Color(0xFFFFF8E6)),
            _tag('탑승 12회'),
          ]),
          Container(
            margin: const EdgeInsets.only(top: 20),
            padding: const EdgeInsets.only(top: 16),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
            child: Row(children: [
              _stat('12회', '총 탑승'),
              Container(width: 1, height: 36, color: AppColors.border),
              _stat('4.8점', '매너점수', color: AppColors.accent),
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
            onPressed: () {
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
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
// 이용 내역 화면 (변경 없음)
// ============================================================
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  static const _histories = [
    {'date':'2024.12.20','team':'강남→김포 동승팀',  'dept':'강남역 2번출구','dest':'김포공항',   'members':4,'total':'18,400','my':'4,600', 'status':'완료'},
    {'date':'2024.12.15','team':'홍대→인천공항 팀',  'dept':'홍대입구역',    'dest':'인천공항 T1','members':3,'total':'34,200','my':'11,400','status':'완료'},
    {'date':'2024.12.10','team':'잠실→강남 3인팀',   'dept':'잠실역 8번',    'dest':'강남역',     'members':3,'total':'12,600','my':'4,200', 'status':'완료'},
    {'date':'2024.11.28','team':'신촌→판교 팀',      'dept':'신촌역',         'dest':'판교역',     'members':2,'total':'28,000','my':'14,000','status':'완료'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _appBar('이용 내역'),
      body: ListView.builder(
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
// 설정 화면 (변경 없음)
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
            onPressed: () => Navigator.pop(context),
            child: const Text('탈퇴하기')),
      ],
    ));
  }
}

// ============================================================
// 고객지원 화면 (변경 없음)
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

// ============================================================
// 서브화면 공통 헬퍼 (변경 없음)
// ============================================================
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
class _MannerScreen extends StatelessWidget { const _MannerScreen(); @override Widget build(_) => const _SubScreen(title: '매너 점수 관리', icon: '⭐'); }
class _ReportScreen extends StatelessWidget { const _ReportScreen(); @override Widget build(_) => const _SubScreen(title: '신고하기', icon: '🚨'); }