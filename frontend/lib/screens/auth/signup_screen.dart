// ============================================================
// lib/screens/auth/signup_screen.dart
// 회원가입 화면 - OCTOMO 역발상 인증
// [Step 1] 인증 코드 발급 (서버가 생성, 수신번호 1666-3538 표시)
// [Step 2] 사용자가 문자 앱에서 인증 코드 발송
// [Step 3] 서버에서 OCTOMO API로 문자 수신 확인
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/colors.dart';
import '../../utils/routes.dart';
import 'package:taximate/service/auth_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pwConfCtrl = TextEditingController();

  String? _selectedGender;
  bool _pwVisible = false;
  bool _pwConfVisible = false;
  bool _isLoading = false;

  // OCTOMO 인증 상태
  bool _isVerified = false;
  bool _isCodeIssued = false;
  String? _receiverNumber;
  String? _receiverDisplay;
  String? _verificationCode;
  int _remainingSeconds = 300;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _idCtrl.dispose();
    _pwCtrl.dispose();
    _pwConfCtrl.dispose();
    super.dispose();
  }

  // [Step 1] 인증 코드 발급 요청
  Future<void> _issueVerificationCode() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty || phone.length < 10) {
      _showSnackBar('휴대폰 번호를 올바르게 입력해주세요.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final result = await AuthService.issueCode(phone: phone);

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      setState(() {
        _isCodeIssued = true;
        _receiverNumber = result['receiverNumber'];
        _receiverDisplay = result['receiverDisplay'];
        _verificationCode = result['verificationCode'];
        _remainingSeconds = result['expiresIn'] ?? 300;
        _isVerified = false;
      });
      _showSnackBar('인증 코드가 발급되었습니다. 아래 번호로 문자를 보내주세요.', isError: false);
    } else {
      _showSnackBar(result['message'] ?? '인증 코드 발급에 실패했습니다.', isError: true);
    }
  }

  // [Step 2] 문자 앱 열기
  Future<void> _openSmsApp() async {
    if (_receiverNumber == null || _verificationCode == null) return;

    final smsUrl = Uri.parse('sms:$_receiverNumber?body=$_verificationCode');

    try {
      if (await canLaunchUrl(smsUrl)) {
        await launchUrl(smsUrl, mode: LaunchMode.externalApplication);
      } else {
        _showSnackBar('문자 앱을 열 수 없습니다.', isError: true);
      }
    } catch (e) {
      _showSnackBar('문자 앱 실행 오류: $e', isError: true);
    }
  }

  // [Step 3] 인증 확인
  Future<void> _verifyCode() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      _showSnackBar('휴대폰 번호를 입력해주세요.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final result = await AuthService.octomoVerifyCode(phone: phone);

    setState(() => _isLoading = false);

    if (result['success'] == true && result['verified'] == true) {
      setState(() => _isVerified = true);
      _showSnackBar('본인인증이 완료되었습니다!', isError: false);
    } else {
      _showSnackBar(result['message'] ?? '인증 확인에 실패했습니다. 문자를 보냈는지 확인해주세요.', isError: true);
    }
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isVerified) {
      _showSnackBar('휴대폰 본인인증을 완료해주세요.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final username = _idCtrl.text.trim();
    final password = _pwCtrl.text.trim();

    final name = _nameCtrl.text.trim().isNotEmpty
        ? _nameCtrl.text.trim()
        : 'user_$username';

    final gender = _selectedGender ?? '남';

    final phone = _phoneCtrl.text.trim();

    final result = await AuthService.signup(
      username: username,
      password: password,
      name: name,
      gender: gender,
      phone: phone,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      _showSuccessDialog();
    } else {
      _showSnackBar(result['message'] ?? '회원가입에 실패했습니다.', isError: true);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: AppColors.primary,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '가입 완료!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              '${_idCtrl.text}님, 환영합니다 🎉',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.gray,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.login,
                    (route) => false,
                  );
                },
                child: const Text(
                  '로그인 하러 가기',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.red : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '회원가입',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.secondary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 이름
              _sectionLabel('이름', Icons.badge_outlined),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameCtrl,
                decoration: _inputDeco(hint: '비워두면 자동 생성'),
              ),
              const SizedBox(height: 20),

              // 성별
              _sectionLabel('성별', Icons.wc_outlined),
              const SizedBox(height: 8),
              Row(
                children: ['남', '여'].map((g) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedGender = g),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedGender == g
                                ? AppColors.primary
                                : AppColors.bg,
                            border: Border.all(
                              color: _selectedGender == g
                                  ? AppColors.primary
                                  : AppColors.border,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            g,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: _selectedGender == g
                                  ? Colors.white
                                  : AppColors.gray,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // 전화번호 + OCTOMO 인증
              _sectionLabel('전화번호 (본인인증)', Icons.phone_outlined),
              const SizedBox(height: 6),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 11,
                enabled: !_isVerified,
                decoration: _inputDeco(
                  hint: '01012345678 (- 없이 입력)',
                  suffix: _isVerified
                      ? Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified, color: Colors.green.shade600, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                '인증완료',
                                style: TextStyle(
                                  color: Colors.green.shade600,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        )
                      : null,
                ).copyWith(counterText: ''),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '휴대폰 번호를 입력해주세요.';
                  if (v.trim().length < 10) return '올바른 휴대폰 번호를 입력해주세요.';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // [Step 1] 인증 코드 발급 버튼
              if (!_isVerified)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _issueVerificationCode,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send_to_mobile, size: 18),
                    label: Text(
                      _isCodeIssued ? '인증 코드 재발급' : '인증 코드 발급받기',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),

              // [Step 1-2] 인증 코드 카드
              if (_isCodeIssued && !_isVerified) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.white70, size: 16),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '아래 번호로 인증 코드를 문자로 보내주세요',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.phone, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              _receiverDisplay ?? '1666-3538',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              '인증 코드',
                              style: TextStyle(
                                color: AppColors.gray,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _verificationCode ?? '------',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _openSmsApp,
                          icon: const Icon(Icons.sms, size: 18),
                          label: const Text(
                            '문자 보내기 (문자앱 열기)',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _verifyCode,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.verified, size: 18),
                    label: const Text(
                      '인증 완료 확인',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.gray, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '문자를 보낸 후 "인증 완료 확인" 버튼을 눌러주세요.',
                          style: TextStyle(
                            color: AppColors.gray,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // 아이디
              _sectionLabel('아이디', Icons.alternate_email),
              const SizedBox(height: 6),
              TextFormField(
                controller: _idCtrl,
                decoration: _inputDeco(hint: '영문, 숫자 조합 4~20자'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '아이디를 입력해주세요.';
                  if (v.trim().length < 4) return '아이디는 4자 이상이어야 합니다.';
                  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v.trim())) {
                    return '영문, 숫자, 밑줄(_)만 사용 가능합니다.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // 비밀번호
              _sectionLabel('비밀번호', Icons.lock_outline),
              const SizedBox(height: 6),
              TextFormField(
                controller: _pwCtrl,
                obscureText: !_pwVisible,
                decoration: _inputDeco(
                  hint: '8자 이상',
                  suffix: IconButton(
                    icon: Icon(
                      _pwVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.gray,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _pwVisible = !_pwVisible),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return '비밀번호를 입력해주세요.';
                  if (v.length < 8) return '비밀번호는 8자 이상이어야 합니다.';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // 비밀번호 확인
              TextFormField(
                controller: _pwConfCtrl,
                obscureText: !_pwConfVisible,
                decoration: _inputDeco(
                  hint: '비밀번호를 한 번 더 입력하세요',
                  suffix: IconButton(
                    icon: Icon(
                      _pwConfVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.gray,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _pwConfVisible = !_pwConfVisible),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return '비밀번호 확인을 입력해주세요.';
                  if (v != _pwCtrl.text) return '비밀번호가 일치하지 않습니다.';
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // 회원가입 버튼
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _isLoading ? null : _handleSignup,
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          '회원가입 완료',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.gray,
                  ),
                  child: const Text(
                    '이미 계정이 있으신가요? 로그인',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.secondary,
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDeco({required String hint, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: AppColors.gray),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.red, width: 1.5),
      ),
    );
  }
}
