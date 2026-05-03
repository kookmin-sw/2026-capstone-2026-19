import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'package:flutter/foundation.dart';

class TripService {
    // 앱 내부 화면 새로고침 알림용
  // Timer처럼 계속 서버를 호출하는 방식이 아니라,
  // 모집 생성/참여처럼 데이터가 바뀐 순간에만 알림을 보낸다.
  static final ValueNotifier<int> tripsRefreshNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<int> chatRoomsRefreshNotifier = ValueNotifier<int>(0);

  static void notifyTripsChanged() {
    tripsRefreshNotifier.value++;
  }

  static void notifyChatRoomsChanged() {
    chatRoomsRefreshNotifier.value++;
  }

  // 프로젝트 전체에서 공통으로 사용할 베이스 주소
  static String get serverUrl => AppConfig.apiBaseUrl;
  static String get tripApiUrl => '$serverUrl/api/trips';

  // 1. 핀 생성 API
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
      final requestBody = {
        'depart_name': deptName,
        'depart_lat': double.parse(deptLat.toStringAsFixed(6)),
        'depart_lng': double.parse(deptLng.toStringAsFixed(6)),
        'arrive_name': destName,
        'arrive_lat': double.parse(destLat.toStringAsFixed(6)),
        'arrive_lng': double.parse(destLng.toStringAsFixed(6)),
        'depart_time': departTime.toIso8601String(),
        'capacity': capacity,
        'seat_position': seatPosition,
        'kakaopay_link': kakaoLink,
      };

      print('🚕 CREATE TRIP REQUEST BODY: ${jsonEncode(requestBody)}');

      final response = await http.post(
        Uri.parse('$tripApiUrl/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: jsonEncode(requestBody),
      );

      print('🚕 CREATE TRIP STATUS: ${response.statusCode}');
      print('🚕 CREATE TRIP RESPONSE: ${utf8.decode(response.bodyBytes)}');

      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 201 || response.statusCode == 200) {
        notifyTripsChanged();
        return {'success': true, 'id': data['id']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? data.toString(),
        };
      }
    } catch (e) {
      return {'success': false, 'message': '서버 연결 오류: $e'};
    }
  }

  // static Future<Map<String, dynamic>> createTrip({
  //   required String token,
  //   required String deptName,
  //   required double deptLat,
  //   required double deptLng,
  //   required String destName,
  //   required double destLat,
  //   required double destLng,
  //   required DateTime departTime,
  //   required int capacity,
  //   required String seatPosition,
  //   required String kakaoLink,
  // }) async {
  //   try {
  //     final response = await http.post(
  //       Uri.parse('$tripApiUrl/'),
  //       headers: {
  //         'Content-Type': 'application/json',
  //         'Authorization': 'Token $token',
  //       },
  //       body: jsonEncode({
  //         'depart_name': deptName,
  //         'depart_lat': deptLat,
  //         'depart_lng': deptLng,
  //         'arrive_name': destName,
  //         'arrive_lat': destLat,
  //         'arrive_lng': destLng,
  //         'depart_time': departTime.toIso8601String(),
  //         'capacity': capacity,
  //         'seat_position': seatPosition,
  //         // 'kakao_link': kakaoLink, // 필요하다면 백엔드 필드에 맞춰 추가하세요
  //       }),
  //     );

  //     final data = jsonDecode(utf8.decode(response.bodyBytes));

  //     if (response.statusCode == 201 || response.statusCode == 200) {
  //       return {'success': true, 'id': data['id']};
  //     } else {
  //       return {'success': false, 'message': data['message'] ?? '핀 생성 실패'};
  //     }
  //   } catch (e) {
  //     return {'success': false, 'message': '서버 연결 오류: $e'};
  //   }
  // }

  // 2. 핀 목록 가져오기
  static Future<List<dynamic>> getTrips({required String token}) async {
    try {
      final response = await http.get(
        Uri.parse('$tripApiUrl/'),
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

  // 3. 채팅방 생성 API
  static Future<Map<String, dynamic>> createChatRoom({
    required String token,
    required int tripId,
  }) async {
    try {
      // ⚠️ 주의: 프로젝트 urls.py 설정에 따라 'api/chat/rooms/'일 수도 있습니다.
      // 현재는 작성하신 urlpatterns 경로인 '/chat/rooms/'를 기준으로 합니다.
      final response = await http.post(
        Uri.parse('$serverUrl/chat/rooms/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: jsonEncode({
          'trip_id': tripId,
        }),
      );

      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 201) {
        notifyChatRoomsChanged();
        return {'success': true, 'id': data['id']};
      } else {
        return {'success': false, 'message': '채팅방 생성 실패'};
      }
    } catch (e) {
      return {'success': false, 'message': '채팅방 서버 연결 오류: $e'};
    }
  }
  // 4. 내 채팅방 목록 가져오기 API
  static Future<List<dynamic>> getChatRooms({required String token}) async {
    try {
      final response = await http.get(
        Uri.parse('$serverUrl/chat/rooms/'), // 백엔드의 채팅방 목록 조회 URL
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      );

      if (response.statusCode == 200) {
        // 성공 시 JSON 리스트 반환
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        print('채팅방 목록 로드 실패: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('채팅방 목록 서버 연결 오류: $e');
      return [];
    }
  }
  // 5. 핀(카풀/택시) 참여하기 API
    static Future<Map<String, dynamic>> joinTrip({
      required String token,
      required int tripId,
      required String seatPosition, // 💡만약 참여할 때 좌석 선택도 백엔드로 보내야 한다면 이 주석을 푸세요!
    }) async {
      try {
        // ⚠️ 주의: 백엔드(Django) urls.py에 설정된 참여 API 주소에 맞춰야 합니다.
        // 보통 '/api/trips/<trip_id>/join/' 또는 '/api/trips/join/' 형태를 씁니다.
        // 아래는 RESTful 관례에 따른 가장 흔한 형태의 예시입니다.
        final response = await http.post(
          Uri.parse('$tripApiUrl/$tripId/join/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Token $token',
          },

          body: jsonEncode({
          'seat_position': seatPosition,
           }),
        );

        // 응답 본문이 비어있을 경우를 대비한 안전한 처리
        Map<String, dynamic> data = {};
        if (response.body.isNotEmpty) {
          data = jsonDecode(utf8.decode(response.bodyBytes));
        }

        // 200(성공) 또는 201(생성됨) 코드가 오면 성공으로 간주
        if (response.statusCode == 200 || response.statusCode == 201) {
          notifyTripsChanged();
          notifyChatRoomsChanged();
          return {'success': true, 'message': '참여 성공'};
        } else {
          return {'success': false, 'message': data['message'] ?? '참여 실패'};
        }
      } catch (e) {
        return {'success': false, 'message': '서버 연결 오류: $e'};
      }
    }
} // 괄호 오타 수정 완료