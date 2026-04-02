import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // =========================================================
  // 통신 스위치: true = 더미 데이터, false = 실제 API 통신
  // =========================================================
  static bool useDummyData = true;

  // =========================================================
  // 서버 주소 (환경에 맞게 수정)
  // =========================================================
  // 안드로이드 에뮬레이터 → 10.0.2.2
  // 실제 폰 → PC IP (예: 192.168.0.10)
  static const String baseUrl = 'http://10.0.2.2:8000/api';

  // =========================================================
  // 토큰 저장/조회/삭제
  // =========================================================
  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refresh_token');
  }

  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }

  // =========================================================
  // 인증 헤더 가져오기
  // =========================================================
  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // =========================================================
  // 1️⃣ 로그인
  // POST /api/accounts/login/
  // =========================================================
  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    if (useDummyData) {
      // 더미 데이터 모드
      await Future.delayed(const Duration(seconds: 1));
      return {
        'success': true,
        'access': 'dummy_access_token_12345',
        'refresh': 'dummy_refresh_token_67890',
        'user': {
          'username': username,
          'nickname': '테스트유저',
        },
      };
    }

    // 실제 API 통신
    final uri = Uri.parse('$baseUrl/accounts/login/');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );

    final data = _handleResponse(response);

    // 토큰 저장
    if (data['access'] != null && data['refresh'] != null) {
      await saveTokens(
        accessToken: data['access'],
        refreshToken: data['refresh'],
      );
    }

    return data;
  }

  // =========================================================
  // 2️⃣ 로그아웃
  // POST /api/accounts/logout/
  // =========================================================
  static Future<Map<String, dynamic>> logout() async {
    final refreshToken = await getRefreshToken();

    if (useDummyData) {
      // 더미 데이터 모드
      await Future.delayed(const Duration(milliseconds: 500));
      await clearTokens();
      return {'success': true, 'message': '로그아웃되었습니다.'};
    }

    // 실제 API 통신
    final uri = Uri.parse('$baseUrl/accounts/logout/');
    final headers = await getAuthHeaders();

    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'refresh': refreshToken,
      }),
    );

    final data = _handleResponse(response);

    // 토큰 삭제
    await clearTokens();

    return data;
  }

  // =========================================================
  // 3️⃣ 회원 탈퇴
  // POST /api/accounts/withdrawal/
  // =========================================================
  static Future<Map<String, dynamic>> withdraw({
    String reason = '사용자 탈퇴',
  }) async {
    if (useDummyData) {
      // 더미 데이터 모드
      await Future.delayed(const Duration(milliseconds: 800));
      await clearTokens();
      return {
        'success': true,
        'is_blocked': true,
        'message': '탈퇴가 완료되었습니다.',
      };
    }

    // 실제 API 통신
    final uri = Uri.parse('$baseUrl/accounts/withdrawal/');
    final headers = await getAuthHeaders();

    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'reason': reason,
      }),
    );

    final data = _handleResponse(response);

    // 토큰 삭제
    await clearTokens();

    return data;
  }

  // =========================================================
  // 4️⃣ 프로필 사진 업데이트
  // PATCH /api/accounts/me/
  // =========================================================
  static Future<Map<String, dynamic>> updateProfile({
    required String profileImgUrl,
  }) async {
    if (useDummyData) {
      // 더미 데이터 모드
      await Future.delayed(const Duration(milliseconds: 600));
      return {
        'success': true,
        'profile_img_url': profileImgUrl,
        'message': '프로필이 업데이트되었습니다.',
      };
    }

    // 실제 API 통신
    final uri = Uri.parse('$baseUrl/accounts/me/');
    final headers = await getAuthHeaders();

    final response = await http.patch(
      uri,
      headers: headers,
      body: jsonEncode({
        'profile_img_url': profileImgUrl,
      }),
    );

    return _handleResponse(response);
  }

  // =========================================================
  // 5️⃣ 이용 내역 조회 (HistoryScreen에서 사용)
  // GET /api/trips/history/
  // =========================================================
  static Future<List<Map<String, dynamic>>> getTripHistory() async {
    if (useDummyData) {
      await Future.delayed(const Duration(milliseconds: 800));
      return [
        {'date':'2024.12.20','team':'강남→김포 동승팀', 'dept':'강남역 2번출구','dest':'김포공항', 'members':4,'total':'18,400','my':'4,600', 'status':'완료'},
        {'date':'2024.12.15','team':'홍대→인천공항 팀', 'dept':'홍대입구역', 'dest':'인천공항 T1','members':3,'total':'34,200','my':'11,400','status':'완료'},
        {'date':'2024.12.10','team':'잠실→강남 3인팀', 'dept':'잠실역 8번', 'dest':'강남역', 'members':3,'total':'12,600','my':'4,200', 'status':'완료'},
        {'date':'2024.11.28','team':'신촌→판교 팀', 'dept':'신촌역', 'dest':'판교역', 'members':2,'total':'28,000','my':'14,000','status':'완료'},
      ];
    }

    final uri = Uri.parse('$baseUrl/trips/history/');
    final headers = await getAuthHeaders();
    final response = await http.get(uri, headers: headers);
    final data = _handleResponse(response);
    return List<Map<String, dynamic>>.from(data['history'] ?? []);
  }

  // =========================================================
  // 6️⃣ 매너 로그 조회 (_MannerScreen에서 사용)
  // GET /api/moderation/trust-score-logs/
  // =========================================================
  static Future<List<Map<String, dynamic>>> getTrustScoreLogs() async {
    if (useDummyData) {
      await Future.delayed(const Duration(milliseconds: 800));
      return [
        {
          'event_type': 'TRIP_PARTICIPATION_COMPLETED',
          'direction': 'GAIN',
          'applied_delta': '+2.5',
          'score_after': '42.0',
          'reason_detail': '동승 완료 - 정산 완료',
          'created_at': '2024-12-20T14:30:00',
        },
        {
          'event_type': 'FAST_SETTLEMENT',
          'direction': 'GAIN',
          'applied_delta': '+1.0',
          'score_after': '39.5',
          'reason_detail': '빠른 정산 보너스',
          'created_at': '2024-12-18T09:15:00',
        },
        {
          'event_type': 'NORMAL_CANCEL',
          'direction': 'PENALTY',
          'applied_delta': '-1.0',
          'score_after': '38.5',
          'reason_detail': '출발 10분 전 취소',
          'created_at': '2024-12-15T16:20:00',
        },
        {
          'event_type': 'STREAK_BONUS',
          'direction': 'GAIN',
          'applied_delta': '+0.5',
          'score_after': '39.5',
          'reason_detail': '연속 성공 보너스',
          'created_at': '2024-12-10T11:00:00',
        },
      ];
    }

    final uri = Uri.parse('$baseUrl/moderation/trust-score-logs/');
    final headers = await getAuthHeaders();
    final response = await http.get(uri, headers: headers);
    final data = _handleResponse(response);
    return List<Map<String, dynamic>>.from(data['logs'] ?? []);
  }

  // =========================================================
  // 7️⃣ 최근 동승자 조회 (_ReportScreen에서 사용)
  // GET /api/trips/recent-companions/
  // =========================================================
  static Future<List<Map<String, dynamic>>> getRecentCompanions() async {
    if (useDummyData) {
      await Future.delayed(const Duration(milliseconds: 800));
      return [
        {'id': 'user_001', 'nickname': '@taxi_kim', 'ride_date': '오늘 14:30', 'route': '강남역 → 김포공항'},
        {'id': 'user_002', 'nickname': '@seoul_lee', 'ride_date': '어제 15:00', 'route': '홍대입구역 → 인천공항 T1'},
        {'id': 'user_003', 'nickname': '@rider_park', 'ride_date': '3일 전 14:45', 'route': '잠실역 → 강남역'},
        {'id': 'user_004', 'nickname': '@go_choi', 'ride_date': '1주일 전 16:00', 'route': '신촌역 → 판교역'},
      ];
    }

    final uri = Uri.parse('$baseUrl/trips/recent-companions/');
    final headers = await getAuthHeaders();
    final response = await http.get(uri, headers: headers);
    final data = _handleResponse(response);
    return List<Map<String, dynamic>>.from(data['companions'] ?? []);
  }

  // =========================================================
  // 8️⃣ 유저 신고 (_ReportScreen에서 사용)
  // POST /api/moderation/reports/
  // =========================================================
  static Future<Map<String, dynamic>> reportUser({
    required String reportedUserId,
    required String tripId,
    required String reason,
    String? detail,
  }) async {
    if (useDummyData) {
      await Future.delayed(const Duration(seconds: 1));
      return {'success': true, 'message': '신고가 접수되었습니다.'};
    }

    final uri = Uri.parse('$baseUrl/moderation/reports/');
    final headers = await getAuthHeaders();

    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'reported_user_id': reportedUserId,
        'trip_id': tripId,
        'reason': reason,
        'detail': detail ?? '',
      }),
    );

    return _handleResponse(response);
  }

  // =========================================================
  // 공통 응답 처리 (핵심)
  // =========================================================
  static Map<String, dynamic> _handleResponse(http.Response response) {
    final data = response.body.isNotEmpty ? jsonDecode(response.body) : {};

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else {
      throw Exception(
        data['message'] ?? data['detail'] ?? '서버 오류 (${response.statusCode})',
      );
    }
  }

  // =========================================================
  // 인증번호 전송 (회원가입용)
  // =========================================================
  static Future<Map<String, dynamic>> sendVerificationCode({
    required String phone,
  }) async {
    if (useDummyData) {
      await Future.delayed(const Duration(milliseconds: 500));
      return {'success': true, 'message': '인증번호가 전송되었습니다.'};
    }

    final uri = Uri.parse('$baseUrl/auth/send-code/');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'phone': phone}),
    );

    return _handleResponse(response);
  }

  // =========================================================
  // 인증번호 확인 (회원가입용)
  // =========================================================
  static Future<Map<String, dynamic>> verifyCode({
    required String phone,
    required String code,
  }) async {
    if (useDummyData) {
      await Future.delayed(const Duration(milliseconds: 500));
      return {'success': true, 'message': '인증번호가 확인되었습니다.'};
    }

    final uri = Uri.parse('$baseUrl/auth/verify-code/');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'phone': phone, 'code': code}),
    );

    return _handleResponse(response);
  }

  // =========================================================
  // 회원가입
  // =========================================================
  static Future<Map<String, dynamic>> signup({
    required String name,
    required String gender,
    required String phone,
    required String username,
    required String password,
  }) async {
    if (useDummyData) {
      await Future.delayed(const Duration(seconds: 1));
      return {'success': true, 'message': '회원가입이 완료되었습니다.'};
    }

    final uri = Uri.parse('$baseUrl/auth/signup/');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'name': name,
        'gender': gender,
        'phone': phone,
        'username': username,
        'password': password,
      }),
    );

    return _handleResponse(response);
  }
}