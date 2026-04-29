import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  // 에뮬레이터 기준 localhost 주소. 실기기 테스트 시 192.168.x.x (PC의 IP)로 변경해야 합니다.
  static const String baseUrl = 'http://3.35.37.129:8000/api/accounts';

  // ============================================================
  // [OCTOMO 역발상 인증] 사용자가 서버 번호(1666-3538)로 문자 발송
  // ============================================================

  // 1. 인증 코드 발급 API (Step 1)
  // 서버가 6자리 인증 코드를 생성하고, 수신 번호(1666-3538)와 함께 반환
  static Future<Map<String, dynamic>> issueCode({required String phone}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/issue-code/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return {
          'success': true,
          'receiverNumber': data['receiver_number'],
          'receiverDisplay': data['receiver_display'],
          'verificationCode': data['verification_code'],
          'expiresIn': data['expires_in'],
        };
      } else {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return {
          'success': false,
          'message': data['message'] ?? '인증 코드 발급에 실패했습니다.'
        };
      }
    } catch (e) {
      return {'success': false, 'message': '서버 연결 오류: $e'};
    }
  }

  // 2. 인증 확인 API (Step 3)
  // 사용자가 문자를 발송했는지 OCTOMO API로 확인
  static Future<Map<String, dynamic>> octomoVerifyCode({required String phone}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/verify-code/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return {
          'success': true,
          'verified': data['verified'] ?? true,
          'message': data['message'] ?? '본인인증이 완료되었습니다.'
        };
      } else {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return {
          'success': false,
          'verified': false,
          'message': data['message'] ?? '인증 확인에 실패했습니다.'
        };
      }
    } catch (e) {
      return {'success': false, 'verified': false, 'message': '서버 연결 오류: $e'};
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
      return {'success': false, 'message': '서버 연결 실패: $e'};
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
    await Future.delayed(const Duration(milliseconds: 800));
    return [
      {
        'date': '2026.04.10 18:30',
        'status': '정산 완료',
        'team': '퇴근길 택시팟',
        'dept': '국민대 정문',
        'dest': '길음역',
        'members': 4,
        'total': '6,400',
        'my': '1,600',
      },
      {
        'date': '2026.04.05 22:10',
        'status': '취소됨',
        'team': '야작 끝 집가자',
        'dept': '국민대 조형관',
        'dest': '성신여대입구역',
        'members': 2,
        'total': '8,000',
        'my': '0',
      },
    ];
  }

  // 10. 매너 로그 데이터 반환
  static Future<List<Map<String, dynamic>>> getTrustScoreLogs() async {
    await Future.delayed(const Duration(milliseconds: 800));
    return [
      {
        'direction': 'GAIN',
        'event_type': 'FAST_SETTLEMENT',
        'created_at': '2026-04-10T19:00:00Z',
        'applied_delta': '+0.5',
        'reason_detail': '하차 후 10분 이내 빠른 정산 완료',
        'score_after': '37.0',
      },
      {
        'direction': 'PENALTY',
        'event_type': 'NO_SHOW',
        'created_at': '2026-04-05T22:15:00Z',
        'applied_delta': '-2.0',
        'reason_detail': '약속 시간 5분 경과 후 미탑승',
        'score_after': '36.5',
      },
    ];
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
}