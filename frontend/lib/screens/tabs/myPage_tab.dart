import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../auth/login_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/colors.dart';
import '../../service/auth_service.dart';
import '../../service/auth_session.dart';

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
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    if (AuthSession.isLoggedIn) {
      _profileFuture = AuthService.getProfile();
    }
  }

  void _refreshProfile() {
    setState(() {
      _profileFuture = AuthService.getProfile();
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isUploading) return;
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (picked != null) {
        setState(() {
          _isUploading = true;
          _profileImage = File(picked.path);
        });
        final result = await AuthService.updateProfileImage(File(picked.path));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'])));
          if (result['success']) _refreshProfile();
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('업데이트 실패: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
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
                leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.photo_library_outlined, color: AppColors.primary)),
                title: const Text('갤러리에서 선택'),
                onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
              ),
              ListTile(
                leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFF0F4FF), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.camera_alt_outlined, color: Color(0xFF4A6FFF))),
                title: const Text('카메라로 촬영'),
                onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
              ),
            ],
          ),
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    if (_profileFuture == null) return _buildLoginPrompt();
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data?['success'] == false) return const Center(child: Text('데이터 로딩 실패'));
          final userData = snapshot.data?['data'];
          if (userData == null) return const Center(child: Text('데이터 없음'));
          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildProfileHeader(userData),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(children: _getDynamicMenus(userData).map((m) => _buildMenuItem(context, m)).toList()),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Scaffold(body: Center(child: ElevatedButton(onPressed: () => Navigator.pushNamed(context, '/login'), child: const Text('로그인하러 가기'))));
  }

  Widget _buildProfileHeader(Map<String, dynamic> userData) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
      child: Column(
        children: [
          GestureDetector(
            onTap: _showImagePickerSheet,
            child: Container(
              width: 84, height: 84,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.bg, border: Border.all(color: AppColors.border, width: 2)),
              child: ClipOval(child: userData['profile_img_url'] != null ? Image.network(userData['profile_img_url'], fit: BoxFit.cover) : const Icon(Icons.person, size: 48)),
            ),
          ),
          const SizedBox(height: 14),
          Text(userData['user_real_name'] ?? '이름 없음', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          Text('@${userData['username']}', style: const TextStyle(fontSize: 12, color: AppColors.gray)),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, _MenuItem menu) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(menu.icon, color: menu.color ?? AppColors.primary),
        title: Text(menu.label, style: TextStyle(color: menu.color)),
        subtitle: menu.sub != null ? Text(menu.sub!) : null,
        onTap: () {
          if (menu.label == '로그아웃') { _showLogoutDialog(context); }
          else if (menu.screen != null) { Navigator.push(context, MaterialPageRoute(builder: (_) => menu.screen!)); }
        },
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('로그아웃'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        ElevatedButton(onPressed: () async {
          await AuthService.logout();
          if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
        }, child: const Text('확인')),
      ],
    ));
  }
}

// ============================================================
// 2. 이용 내역 화면
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
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('이용 내역')),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(itemCount: _histories.length, itemBuilder: (_, i) => ListTile(title: Text(_histories[i]['team']))),
    );
  }
}

// ============================================================
// 3. 신고하기 화면
// ============================================================
class _ReportScreen extends StatefulWidget {
  const _ReportScreen();
  @override
  State<_ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<_ReportScreen> {
  List<_RecentPassenger> _recentPassengers = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchRecentCompanions();
  }

  Future<void> _fetchRecentCompanions() async {
    try {
      final companions = await AuthService.getRecentCompanions();
      setState(() {
        _recentPassengers = companions.map((c) => _RecentPassenger(
          id: c['id'].toString(),
          nickname: c['nickname'],
          rideDate: c['ride_date'],
          route: c['route']
        )).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('신고하기')),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(itemCount: _recentPassengers.length, itemBuilder: (_, i) => ListTile(title: Text(_recentPassengers[i].nickname), trailing: ElevatedButton(onPressed: () => _submitReport(_recentPassengers[i].id), child: const Text('신고')))),
    );
  }

  Future<void> _submitReport(String targetId) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    final result = await AuthService.reportUser(targetId: targetId, tripId: 'temp', reason: '비매너');
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'])));
    setState(() => _isSubmitting = false);
  }
}

// ============================================================
// 4. 기타 설정 및 보조 클래스
// ============================================================
class SettingsScreen extends StatelessWidget { const SettingsScreen({super.key}); @override Widget build(_) => Scaffold(appBar: AppBar(title: const Text('설정'))); }
class SupportScreen extends StatelessWidget { const SupportScreen({super.key}); @override Widget build(_) => Scaffold(appBar: AppBar(title: const Text('고객지원'))); }
class _AuthScreen extends StatelessWidget { const _AuthScreen(); @override Widget build(_) => Scaffold(appBar: AppBar(title: const Text('인증'))); }
class _MannerScreen extends StatelessWidget { const _MannerScreen(); @override Widget build(_) => Scaffold(appBar: AppBar(title: const Text('매너 관리'))); }

class _MenuItem {
  final IconData icon; final String label; final String? sub; final Widget? screen; final Color? color;
  const _MenuItem({required this.icon, required this.label, this.sub, this.screen, this.color});
}

class _RecentPassenger {
  final String id, nickname, rideDate, route;
  _RecentPassenger({required this.id, required this.nickname, required this.rideDate, required this.route});
}