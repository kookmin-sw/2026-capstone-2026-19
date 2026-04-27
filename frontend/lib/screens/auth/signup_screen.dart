// ============================================================
// lib/screens/auth/signup_screen.dart
// 회원가입 화면
// - 전화번호 인증 제거
// - 회원가입 시 프론트에서 필요한 값 임의 생성해서 전송
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final _codeCtrl = TextEditingController();  // 인증번호 입력 컨트롤러

  String? _selectedGender;
  bool _pwVisible = false;
  bool _pwConfVisible = false;
  bool _isLoading     = false;
  bool _codeSent      = false;  // 인증번호 전송 여부
  bool _phoneVerified = false;  // 본인인증 완료 여부
  int  _countdown     = 0;      // 인증번호 유효 시간 카운트다운
  String? _verificationId;      // Firebase 인증 ID
  bool _isSendingCode = false;  // 인증번호 발송 중
  bool _isVerifying   = false;  // 인증번호 확인 중

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _idCtrl.dispose();
    _pwCtrl.dispose();
    _pwConfCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  // -- 인증번호 전송 (Firebase Phone Auth) ----------------------
  Future<void> _sendVerificationCode() async {
    if (_phoneCtrl.text.length < 10) {
      _showSnackBar('올바른 전화번호를 입력해주세요.', isError: true);
      return;
    }

    setState(() => _isSendingCode = true);

    final FirebaseAuth auth = FirebaseAuth.instance;
    String phoneNumber = _phoneCtrl.text.trim();

    // 국가 코드 추가 (한국 기준)
    if (!phoneNumber.startsWith('+')) {
      phoneNumber = '+82${phoneNumber.substring(1)}';
    }

    await auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 120),
      verificationCompleted: (PhoneAuthCredential credential) async {
        // 자동 인증 완료 (일부 기기에서만)
        await auth.signInWithCredential(credential);
        setState(() {
          _phoneVerified = true;
          _codeSent = false;
          _isSendingCode = false;
        });
        _showSnackBar('본인인증이 자동 완료되었습니다!');
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() => _isSendingCode = false);
        _showSnackBar('인증 실패: ${e.message}', isError: true);
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
          _codeSent = true;
          _countdown = 180; // 3분 카운트다운
          _isSendingCode = false;
        });
        _showSnackBar('인증번호가 발송되었습니다.');

        // 카운트다운 타이머
        Future.doWhile(() async {
          await Future.delayed(const Duration(seconds: 1));
          if (!mounted) return false;
          setState(() => _countdown--);
          return _countdown > 0;
        });
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  // -- 인증번호 확인 (Firebase Phone Auth) ---------------------
  Future<void> _verifyCode() async {
    if (_codeCtrl.text.trim().isEmpty) {
      _showSnackBar('인증번호를 입력해주세요.', isError: true);
      return;
    }

    if (_verificationId == null) {
      _showSnackBar('인증번호를 먼저 요청해주세요.', isError: true);
      return;
    }

    setState(() => _isVerifying = true);

    try {
      final FirebaseAuth auth = FirebaseAuth.instance;

      // PhoneAuthCredential 생성
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _codeCtrl.text.trim(),
      );

      // Firebase에 로그인 (인증만 확인용)
      UserCredential userCredential = await auth.signInWithCredential(credential);

      // 인증 성공
      if (userCredential.user != null) {
        setState(() {
          _phoneVerified = true;
          _codeSent = false;
          _isVerifying = false;
        });
        _showSnackBar('본인인증이 완료되었습니다!');

        // 인증 후 Firebase 사용자 삭제 (회원가입은 우리 서버에서 처리)
        await auth.currentUser?.delete();
      } else {
        setState(() => _isVerifying = false);
        _showSnackBar('인증에 실패했습니다. 다시 시도해주세요.', isError: true);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _isVerifying = false);
      String errorMessage = '인증번호가 올바르지 않거나 만료되었습니다.';
      if (e.code == 'invalid-verification-code') {
        errorMessage = '잘못된 인증번호입니다. 다시 확인해주세요.';
      } else if (e.code == 'session-expired') {
        errorMessage = '인증 시간이 만료되었습니다. 다시 요청해주세요.';
      }
      _showSnackBar(errorMessage, isError: true);
    } catch (e) {
      setState(() => _isVerifying = false);
      _showSnackBar('인증 중 오류가 발생했습니다. 다시 시도해주세요.', isError: true);
    }
  }

  // -- 회원가입 처리 --------------------------------------------
  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final username = _idCtrl.text.trim();
    final password = _pwCtrl.text.trim();

    // 사용자가 안 넣어도 프론트에서 임의값 생성
    final name = _nameCtrl.text.trim().isNotEmpty
        ? _nameCtrl.text.trim()
        : 'user_$username';

    final gender = _selectedGender ?? '남';

    final phone = _phoneCtrl.text.trim().isNotEmpty
        ? _phoneCtrl.text.trim()
        : _makeDummyPhone(username);

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
      _showSnackBar(
        result['message'] ?? '회원가입에 실패했습니다.',
        isError: true,
      );
    }
  }

  String _makeDummyPhone(String username) {
    // username 기반으로 숫자만 뽑아서 11자리 맞춤
    final onlyDigits = username.replaceAll(RegExp(r'[^0-9]'), '');
    final padded = (onlyDigits + '00000000000').substring(0, 8);
    return '010$padded';
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

              // 전화번호
              _sectionLabel('전화번호', Icons.phone_outlined),
              const SizedBox(height: 6),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 11,
                decoration: _inputDeco(
                  hint: '비워두면 자동 생성',
                ).copyWith(counterText: ''),
              ),
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
                    onPressed: () =>
                        setState(() => _pwConfVisible = !_pwConfVisible),
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