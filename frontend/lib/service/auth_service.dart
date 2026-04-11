import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  static const String baseUrl = 'http://10.0.2.2:8000/api/accounts';

  // 1. 인증번호 전송 API
  static Future<Map<String, dynamic>> sendVerificationCode({required String phone}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/send-code/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone}),
      );
      return {'success': response.statusCode == 200};
    } catch (e) {
      return {'success': false, 'message': '서버 연결 오류'};
    }
  }

  // 2. 인증번호 확인 API
  static Future<Map<String, dynamic>> verifyCode({required String phone, required String code}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/verify-code/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'code': code}),
      );
      if (response.statusCode == 200) return {'success': true};
      final data = jsonDecode(response.body);
      return {'success': false, 'message': data['message'] ?? '인증번호가 틀립니다.'};
    } catch (e) {
      return {'success': false, 'message': '서버 연결 오류'};
    }
  }

  // 3. 회원가입 완료 API
  static Future<Map<String, dynamic>> signup({
    required String name,
    required String username, // UI에서 'nickname'으로 보내던 값을 여기서 'username'으로 받음
    required String gender,
    required String phone,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/signup/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': name,
          'nickname': username,
          'password': password,
          'phone_number': phone,
          'gender': gender == '남' ? 'M' : 'F',
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true};
      } else {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return {'success': false, 'message': data['message'] ?? '회원가입 실패'};
      }
    } catch (e) {
      return {'success': false, 'message': '서버 연결 오류'};
    }
  }

  // 4. 로그인 API
  static Future<Map<String, dynamic>> login({
    required String nickname,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nickname': nickname,
          'password': password,
        }),
      );

      final Map<String, dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        return {
          'success': true,
          'token': data['token'],
          'nickname': data['nickname'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? '아이디 또는 비밀번호가 틀립니다.'
        };
      }
    } catch (e) {
      return {'success': false, 'message': '서버 연결 실패: $e'};
    }
  }

  // --- 아래는 MyPage 등에서 에러가 나지 않도록 추가한 껍데기 함수들입니다 ---

  static Future<void> logout() async {}
  static Future<void> updateProfile({String? profileImgUrl}) async {}
  static Future<void> withdraw({required String reason}) async {}
  static Future<List<dynamic>> getTripHistory() async => [];
  static Future<List<dynamic>> getTrustScoreLogs() async => [];
  static Future<List<dynamic>> getRecentCompanions() async => [];
  static Future<void> reportUser({required String targetId, required String reason}) async {}
}