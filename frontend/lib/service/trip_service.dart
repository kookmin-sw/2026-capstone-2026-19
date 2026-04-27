import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
// 주의: pubspec.yaml에 intl을 추가해야 이 줄의 에러가 사라집니다.
import 'package:intl/intl.dart';

class TripService {
  static String get baseUrl => '${dotenv.env['BASE_URL']}/api/trips';

  // 1. 핀 생성 API
  static Future<Map<String, dynamic>> createTrip({
    required String token,
    required String deptName,
    required double deptLat,
    required double deptLng,
    required String destName,
    required double destLat,
    required double destLng,
    required DateTime departTime,
    required int capacity,
    required String seatPosition,
    required String kakaoLink,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: jsonEncode({
          'depart_name': deptName,
          'depart_lat': deptLat,
          'depart_lng': deptLng,
          'arrive_name': destName,
          'arrive_lat': destLat,
          'arrive_lng': destLng,
          'depart_time': departTime.toIso8601String(),
          'capacity': capacity,
          'seat_position': seatPosition,
        }),
      );

      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'id': data['id']};
      } else {
        return {'success': false, 'message': data['message'] ?? '핀 생성 실패'};
      }
    } catch (e) {
      return {'success': false, 'message': '서버 연결 오류: $e'};
    }
  }

  // 2. 핀 목록 가져오기 (이 함수가 반드시 class 내부 괄호 안에 있어야 함!)
  static Future<List<dynamic>> getTrips({required String token}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }
}