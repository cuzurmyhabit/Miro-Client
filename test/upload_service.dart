import 'dart:convert';
import 'package:http/http.dart' as http;

class UploadService {
  final String baseUrl = "http://127.0.0.1:3000/files"; // Nest 서버 주소

  Future<Map<String, dynamic>> uploadFile(String filePath) async {
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload'));

    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    var response = await request.send();
    return jsonDecode(await response.stream.bytesToString());
  }

  Future<bool> deleteFile(String filePath) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/delete'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"filePath": filePath}),
    );

    final result = jsonDecode(response.body);
    return result["success"] == true;
  }
}
