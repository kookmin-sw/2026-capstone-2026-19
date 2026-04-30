// ============================================================
// lib/screens/auth/signup_screen.dart
// 회원가입 화면 — 이름, 성별, 전화번호, 아이디, 비밀번호, 본인인증 (AuthService 제거 버전)
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/colors.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  // 각 필드 컨트롤러
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _idCtrl    = TextEditingController();
  final _pwCtrl    = TextEditingController();
  final _pwConfCtrl= TextEditingController();
  final _codeCtrl  = TextEditingController(); // 인증번호 입력

  // 상태 변수들
  String? _selectedGender;      // '남' | '여' | '기타'
  bool _pwVisible     = false;
  bool _pwConfVisible = false;
  bool _isLoading     = false;
  bool _codeSent      = false;  // 인증번호 전송 여부
  bool _phoneVerified = false;  // 본인인증 완료 여부
  int  _countdown     = 0;      // 인증번호 유효 시간 카운트다운

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

  // -- 1. 인증번호 전송 (더미 처리) --------------------------------
  Future<void> _sendVerificationCode() async {
    if (_phoneCtrl.text.length < 10) {
      _showSnackBar('올바른 전화번호를 입력해주세요.', isError: true);
      return;
    }

    // AuthService 제거: 1초 대기 후 무조건 성공하는 것으로 처리
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _codeSent = true;
      _countdown = 180; // 3분 타이머
    });
    _showSnackBar('인증번호가 전송되었습니다.');
  }

  // -- 2. 인증번호 확인 (더미 처리) --------------------------------
  Future<void> _verifyCode() async {
    if (_codeCtrl.text.trim().length < 6) {
      _showSnackBar('인증번호 6자리를 모두 입력해주세요.', isError: true);
      return;
    }

    // AuthService 제거: 1초 대기 후 무조건 성공하는 것으로 처리
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _phoneVerified = true;
      _countdown = 0;
    });
    _showSnackBar('본인인증이 완료되었습니다.');
  }

  // -- 3. 회원가입 처리 (더미 처리) --------------------------------
  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedGender == null) {
      _showSnackBar('성별을 선택해주세요.', isError: true);
      return;
    }
    if (!_phoneVerified) {
      _showSnackBar('본인인증을 완료해주세요.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // AuthService 제거: 1.5초 대기 후 가입 성공으로 처리
      await Future.delayed(const Duration(milliseconds: 1500));

      if (mounted) {
        _showSnackBar('회원가입이 완료되었습니다!');
        Navigator.pop(context); // 가입 성공 시 이전 화면(로그인)으로 이동
      }
    } catch (e) {
      if (mounted) _showSnackBar('오류가 발생했습니다: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // -- 스낵바 & 헬퍼 함수 ------------------------------------------
  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.red : AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  String _formatCountdown(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('회원가입', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
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

              // 1. 이름
              _sectionLabel('이름', Icons.badge_outlined),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameCtrl,
                decoration: _inputDeco(hint: '실명을 입력하세요'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '이름을 입력해주세요.';
                  if (v.trim().length < 2) return '이름은 2자 이상이어야 합니다.';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // 2. 성별
              _sectionLabel('성별', Icons.wc_outlined),
              const SizedBox(height: 8),
              Row(
                children: ['남', '여'].map((g) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedGender = g),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedGender == g ? AppColors.primary : AppColors.bg,
                          border: Border.all(
                            color: _selectedGender == g ? AppColors.primary : AppColors.border,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(g,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14,
                              color: _selectedGender == g ? Colors.white : AppColors.gray,
                            )),
                      ),
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 20),

              // 3. 전화번호 + 본인인증
              _sectionLabel('전화번호 & 본인인증', Icons.phone_outlined),
              const SizedBox(height: 6),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: 11,
                      decoration: _inputDeco(hint: '01012345678').copyWith(counterText: ''),
                      enabled: !_phoneVerified,
                      validator: (v) {
                        if (v == null || v.isEmpty) return '전화번호를 입력해주세요.';
                        if (v.length < 10) return '올바른 전화번호를 입력해주세요.';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _phoneVerified ? AppColors.gray : AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      onPressed: _phoneVerified ? null : _sendVerificationCode,
                      child: Text(_phoneVerified ? '완료' : (_codeSent ? '재전송' : '인증번호\n전송'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),

              if (_codeSent && !_phoneVerified) ...[
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _codeCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        maxLength: 6,
                        decoration: _inputDeco(hint: '인증번호 6자리 입력').copyWith(
                          counterText: '',
                          suffixIcon: _countdown > 0
                              ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Text(_formatCountdown(_countdown),
                                style: const TextStyle(color: AppColors.red, fontSize: 13, fontWeight: FontWeight.w700)),
                          )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onPressed: _verifyCode,
                        child: const Text('확인', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],

              if (_phoneVerified) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: AppColors.primary, size: 16),
                      SizedBox(width: 6),
                      Text('본인인증이 완료되었습니다.',
                          style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // 4. 아이디
              _sectionLabel('아이디', Icons.alternate_email),
              const SizedBox(height: 6),
              TextFormField(
                controller: _idCtrl,
                decoration: _inputDeco(hint: '영문, 숫자 조합 4~20자'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '아이디를 입력해주세요.';
                  if (v.trim().length < 4) return '아이디는 4자 이상이어야 합니다.';
                  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v.trim())) return '영문, 숫자, 밑줄(_)만 사용 가능합니다.';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // 5. 비밀번호
              _sectionLabel('비밀번호', Icons.lock_outline),
              const SizedBox(height: 6),
              TextFormField(
                controller: _pwCtrl,
                obscureText: !_pwVisible,
                decoration: _inputDeco(
                  hint: '영문+숫자 조합 8자 이상',
                  suffix: IconButton(
                    icon: Icon(_pwVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: AppColors.gray, size: 20),
                    onPressed: () => setState(() => _pwVisible = !_pwVisible),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return '비밀번호를 입력해주세요.';
                  if (v.length < 8) return '비밀번호는 8자 이상이어야 합니다.';
                  if (!RegExp(r'^(?=.*[a-zA-Z])(?=.*\d)').hasMatch(v)) return '영문과 숫자만 입력해주세요.';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _pwConfCtrl,
                obscureText: !_pwConfVisible,
                decoration: _inputDeco(
                  hint: '비밀번호를 한 번 더 입력하세요',
                  suffix: IconButton(
                    icon: Icon(_pwConfVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: AppColors.gray, size: 20),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: _isLoading ? null : _handleSignup,
                  child: _isLoading
                      ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text('회원가입 완료', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 16),

              // 로그인으로 돌아가기
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(foregroundColor: AppColors.gray),
                  child: const Text('이미 계정이 있으신가요? 로그인',
                      style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // 공통 위젯 헬퍼
  Widget _sectionLabel(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.secondary)),
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
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.red)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.red, width: 1.5)),
    );
  }
}