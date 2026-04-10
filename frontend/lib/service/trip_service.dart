import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // 시간 포맷팅용 패키지 (pubspec.yaml 추가 필요)

class TripService {
  static const String baseUrl = 'http://10.0.2.2:8000/api/trips';

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
          'Authorization': 'Token $token', // 👈 로그인 시 받은 토큰 필수!
        },
        body: jsonEncode({
          'depart_name': deptName,
          'depart_lat': deptLat,
          'depart_lng': deptLng,
          'arrive_name': destName,
          'arrive_lat': destLat,
          'arrive_lng': destLng,
          'depart_time': departTime.toIso8601String(), // 장고가 좋아하는 형식
          'capacity': capacity,
          'seat_position': seatPosition, // 백엔드에서 Participant 생성 시 사용
          //'kakao_pay_link': kakaoLink,
        }),
      );

      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'trip_id': data['id']};
      } else {
        return {'success': false, 'message': data['message'] ?? '핀 생성에 실패했습니다.'};
      }
    } catch (e) {
      return {'success': false, 'message': '서버 연결 오류: $e'};
    }
  }
}
// 핀 목록 가져오기 (GET)
  static Future<List<dynamic>> getTrips({required String token}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/'), // GET http://10.0.2.2:8000/api/trips/
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      );

      if (response.statusCode == 200) {
        // 한글 깨짐 방지 디코딩 후 리스트 반환
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        print('목록 로드 실패: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('서버 연결 오류: $e');
      return [];
    }
  }