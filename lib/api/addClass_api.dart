import 'package:http/http.dart' as http;
import 'dart:convert';

class AddClassApiService {
  static const String baseUrl = "http://localhost:3000"; // 기본 포트

  // 중복 확인, 클래스 생성 로직
  static Future<Map<String, dynamic>> addClass({
    required String classUid,
    required String creatorUid,
    required List<Map<String, String>> coverImg,
    required String className,
    required String description,
    required String field,
    required String requirement,
    required String caution,
    required String capacity,
    required String startDate,
    required String endDate,
  }) async {
    final url = Uri.parse('$baseUrl/classList/addClass');
    // print("📡 요청 URL: $url");
    final body = jsonEncode({
      'classUid': classUid,
      'creatorUid': creatorUid,
      'coverImg': coverImg,
      'className': className,
      'description': description,
      'field': field,
      'requirement': requirement,
      'caution': caution,
      'capacity': capacity,
      'startDate': startDate,
      'endDate': endDate,
    });

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      // 성공 시
      return jsonDecode(response.body);
    } else if (response.statusCode == 400) {
      // 서버에서 BadRequestException 던진 경우
      final decoded = jsonDecode(response.body); // 에러 json을 map해서 body만 가지고 옴
      final errorData = decoded['message']; // body의 메세지만 가지고 옴

      // 유효성 검사에 따른 예외 처리
      if (errorData is Map<String, dynamic>) {
        // 구조가 <코드, 에러메세지>인지 확인
        final code = errorData['code'];
        final message = errorData['message'];

        if (code == 'DUPLICATE_INFO') {
          throw Exception('이미 같은 클래스 이름이 존재합니다.');
        } else {
          throw Exception(message ?? '잘못된 요청입니다.');
        }
      } else {
        throw Exception('잘못된 요청입니다.');
      }
    } else {
      // 그 외 에러
      throw Exception('클래스 생성 실패 (${response.statusCode})');
    }
  }
}
