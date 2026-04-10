import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  // ⚠️ 중요: 에뮬레이터에서는 10.0.2.2, 실제 폰에서는 노트북의 IP주소(예: 192.168.0.x)를 적어야 합니다.
  static const String baseUrl = 'http://10.0.2.2:8000/api/accounts';

  // 1. 인증번호 전송 API
  static Future<Map<String, dynamic>> sendVerificationCode({required String phone}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/send-code/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone}),
      );

      if (response.statusCode == 200) {
        return {'success': true};
      } else {
        return {'success': false, 'message': '인증번호 전송에 실패했습니다.'};
      }
    } catch (e) {
      return {'success': false, 'message': '서버 연결 오류가 발생했습니다.'};
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

      if (response.statusCode == 200) {
        return {'success': true};
      } else {
        final data = jsonDecode(response.body);
        return {'success': false, 'message': data['message'] ?? '인증번호가 틀립니다.'};
      }
    } catch (e) {
      return {'success': false, 'message': '서버 연결 오류가 발생했습니다.'};
    }
  }

  // 3. 회원가입 완료 API
  static Future<Map<String, dynamic>> signup({
    required String name,
    required String gender,
    required String phone,
    required String username,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/signup/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'nickname': name, // 💡 DB 모델의 nickname 필드에 우선 실명을 넣도록 처리했습니다.
          'phone_number': phone,
          'gender': gender == '남' ? 'M' : 'F', // DB 모델의 'M', 'F' 규격에 맞춤
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true};
      } else {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return {'success': false, 'message': data['message'] ?? '회원가입에 실패했습니다.'};
      }
    } catch (e) {
      return {'success': false, 'message': '서버 연결 오류가 발생했습니다.'};
    }
  }
}