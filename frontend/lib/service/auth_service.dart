import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'auth_session.dart';

class AuthService {

  // 에뮬레이터 기준 localhost 주소. 실기기 테스트 시 192.168.x.x (PC의 IP)로 변경해야 합니다.
  static String get baseUrl => '${AppConfig.apiBaseUrl}/api/accounts';
  // ============================================================
  // [실제 통신] 백엔드(Django)와 연결된 API
  // ============================================================

  static String _signupErrorMessage(Map<String, dynamic> data) {
    final raw = data['message'] ?? data;

    final text = raw.toString();

    final hasUsernameError =
        text.contains('username') ||
        text.contains('user with this username already exists');

    final hasPhoneError =
        text.contains('phone_number') ||
        text.contains('user with this phone number already exists');

    if (hasUsernameError && hasPhoneError) {
      return '이미 사용 중인 아이디와 전화번호입니다.';
    }

    if (hasUsernameError) {
      return '이미 사용 중인 아이디입니다.';
    }

    if (hasPhoneError) {
      return '이미 사용 중인 전화번호입니다.';
    }

    if (text.contains('password')) {
      return '비밀번호 형식을 확인해주세요.';
    }

    return data['message']?.toString() ?? '회원가입에 실패했습니다.';
  }

  // 1. 옥토모 역발상 인증 - 6자리 코드 발급 API
  static Future<Map<String, dynamic>> sendVerificationCode({required String phone}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/send-code/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone}),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return {
          'success': true,
          'code': data['code'],
          'octomoNumber': data['octomoNumber'] ?? '1666-3538',
          'message': data['message'],
        };
      }
      
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return {'success': false, 'message': data['message'] ?? '코드 발급 실패'};
    } catch (e) {
      return {'success': false, 'message': '서버 연결 오류가 발생했습니다. 네트워크 상태를 확인해주세요.'};
    }
  }

  // 2. 옥토모 역발상 인증 - SMS 발송 여부 확인 API
  static Future<Map<String, dynamic>> verifyCode({required String phone}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/verify-code/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone}),
      );
      
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      
      if (response.statusCode == 200 && data['verified'] == true) {
        return {'success': true, 'verified': true, 'message': data['message'] ?? '인증 완료'};
      }
      
      return {
        'success': false,
        'verified': false,
        'message': data['message'] ?? '인증 확인 실패'
      };
    } catch (e) {
      return {'success': false, 'verified': false, 'message': '서버 연결 오류가 발생했습니다. 네트워크 상태를 확인해주세요.'};
    }
  }

  // 3. 회원가입 API
  static Future<Map<String, dynamic>> signup({
    required String name,
    required String username, // UI의 '아이디'
    required String gender,
    required String phone,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/signup/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'user_real_name': name,
          'password': password,
          'phone_number': phone,
          'gender': gender == '남' ? 'M' : 'F',
        }),
      );

      final Map<String, dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));

      if ((response.statusCode == 201 || response.statusCode == 200) &&
          data['success'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? '회원가입 성공',
        };
      }

      return {
        'success': false,
        'message': _signupErrorMessage(data),
      };
    } catch (e) {
      return {'success': false, 'message': '서버 연결 오류가 발생했습니다. 네트워크 상태를 확인해주세요.'};
    }
  }

  // 4. 로그인 API
  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      final Map<String, dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        AuthSession.save(
                  newToken: data['token'],
                  newUsername: data['username']
                );
        return {
          'success': true,
          'token': data['token'],
          'username': data['username'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? '아이디 또는 비밀번호가 틀립니다.'
        };
      }
    } catch (e) {
      return {'success': false, 'message': '서버 연결 오류가 발생했습니다. 네트워크 상태를 확인해주세요.'};
    }
  }

  // ============================================================
  // [가짜 데이터] UI 테스트용 임시 함수 (백엔드 완성 시 http 로직으로 교체)
  // ============================================================

  // 5. 로그아웃
  static Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 500));
    // 추후 기기에 저장된 토큰(SharedPreferences) 삭제 로직 추가
  }

  // 6. 프로필 이미지 업데이트
  static Future<void> updateProfile({required String profileImgUrl}) async {
    await Future.delayed(const Duration(seconds: 1));
  }

  // 7. 회원 탈퇴 (myPage_tab.dart 호출에 맞춤)
  static Future<Map<String, dynamic>> withdraw({required String reason}) async {
    await Future.delayed(const Duration(seconds: 1));
    return {'is_blocked': false, 'message': '탈퇴가 완료되었습니다.'};
  }

  // 8. 유저 신고 (myPage_tab.dart 호출 파라미터 4개에 맞춤)
  static Future<Map<String, dynamic>> reportUser({
    required String targetId,
    required String tripId,
    required String reason,
    String? detail,
  }) async {
    await Future.delayed(const Duration(seconds: 1));
    return {'success': true, 'message': '신고가 접수되었습니다.'};
  }

  // 9. 이용 내역 데이터 반환 (List<Map> 타입으로 에러 방지)
  static Future<List<Map<String, dynamic>>> getTripHistory() async {
    final url = Uri.parse('$baseUrl/history/');

        final response = await http.get(
          url,
          headers: {
            'Authorization': 'Token ${AuthSession.token}', // 로그인 토큰
            'Content-Type': 'application/json',
          },
        );

        if (response.statusCode == 200) {
          // 한글 깨짐 방지를 위해 utf8.decode 사용
          final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
          return data.map((item) => item as Map<String, dynamic>).toList();
        } else {
          throw Exception('이용 내역 조회 실패: ${response.statusCode}');
        }
      }
  static Future<List<Map<String, dynamic>>> getTrustScoreLogs() async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}/api/moderation/trust-score-logs/');
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Token ${AuthSession.token}',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      // 🚨 여기를 9번 함수와 똑같이 utf8.decode 로 감싸주세요!
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((item) => item as Map<String, dynamic>).toList();
    } else {
      throw Exception('매너 로그 조회 실패: ${response.statusCode}');
    }
  }

  // 11. 최근 동승자 데이터 반환
  static Future<List<Map<String, dynamic>>> getRecentCompanions() async {
    await Future.delayed(const Duration(milliseconds: 800));
    return [
      {
        'id': 'user_101',
        'nickname': '컴공과 고양이',
        'ride_date': '2026.04.10 18:30',
        'route': '국민대 정문 → 길음역',
      },
      {
        'id': 'user_202',
        'nickname': '지각은안돼',
        'ride_date': '2026.04.08 08:40',
        'route': '길음역 3번 출구 → 국민대 과학관',
      },
    ];
  }
  static Future<Map<String, dynamic>> getProfile() async {
    try {
      final token = AuthSession.token; // 저장된 토큰 가져오기
      if (token == null) return {'success': false, 'message': '로그인이 필요합니다.'};

      final response = await http.get(
        Uri.parse('$baseUrl/profile/'), // 백엔드 프로필 엔드포인트
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token', // 토큰 인증
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return {'success': false, 'message': '프로필 로딩 실패'};
    } catch (e) {
      return {'success': false, 'message': '서버 연결 오류'};
    }
  }
}

