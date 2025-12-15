import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;
import 'package:http_parser/http_parser.dart';
import 'dart:io';

class PostUpdatePage extends StatefulWidget {
  final String classUid;
  final String postUid;

  const PostUpdatePage({
    super.key,
    required this.classUid,
    required this.postUid,
  });

  @override
  State<PostUpdatePage> createState() => _PostUpdatePageState();
}

class _PostUpdatePageState extends State<PostUpdatePage> {
  static const String API_BASE_URL = "http://127.0.0.1:3000";
  static const String FILE_REPLACE_API_PATH = "upload/replaceFile";

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  DateTime? _selectedEndDate;
  bool _isLoading = true;
  bool _isAssignment = false;

  // [파일 상태] 기존 파일 정보 (DB에 저장된 원본)
  String? _existingFileUrl;
  String? _existingFileName;

  // [파일 상태] 새롭게 선택된 파일 (교체/추가용)
  File? _newSelectedFile;
  String? _newSelectedFileName;

  // [파일 상태] UI에서 명시적으로 삭제 버튼을 눌렀는지 여부
  bool _isExplicitlyDeleted = false;

  @override
  void initState() {
    super.initState();
    _fetchPostData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  // --- 1. 기존 게시물 데이터 불러오기 (GET API 호출) ---
  Future<void> _fetchPostData() async {
    try {
      final dio = Dio();
      // GET /post/list?rootClassUid=... 경로 사용
      final url = '$API_BASE_URL/post/list?rootClassUid=${widget.classUid}';
      final response = await dio.get(url);

      final List<dynamic> postList = response.data['posts'] ?? [];

      final postDetail = postList.firstWhere(
        (item) => item['postUid'] == widget.postUid,
        orElse: () => null,
      );

      if (postDetail != null) {
        final Map<String, dynamic> postData = Map<String, dynamic>.from(
          postDetail,
        );

        // 기존 파일 정보 추출 및 저장
        final String fileUrl = postData['fileUrl'] ?? '';
        if (fileUrl.isNotEmpty) {
          final parts = fileUrl.split('/');
          final fullFileName = parts.last;
          final displayedName = fullFileName.split('_').length > 1
              ? fullFileName.split('_').sublist(1).join('_')
              : fullFileName;

          _existingFileUrl = fileUrl; // 원본 URL 저장
          _existingFileName = displayedName;
        }

        _titleController.text = postData['postName'] ?? '';
        _descriptionController.text = postData['postDescription'] ?? '';
        _isAssignment = postData['postState'] == 'assignment';

        if (_isAssignment && postData['postEndDate'] != null) {
          DateTime endDate;
          if (postData['postEndDate'] is String) {
            endDate = DateTime.parse(postData['postEndDate']);
          } else if (postData['postEndDate'] is Map &&
              postData['postEndDate']['_seconds'] != null) {
            final seconds = postData['postEndDate']['_seconds'] as int;
            endDate = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
          } else {
            endDate = DateTime.now();
          }

          _selectedEndDate = DateTime(endDate.year, endDate.month, endDate.day);
          _endDateController.text = DateFormat(
            'yyyy. MM. dd',
          ).format(_selectedEndDate!);
        }
      } else {
        throw Exception('게시물 정보를 찾을 수 없습니다.');
      }

      setState(() {
        _isLoading = false;
      });
    } on DioException catch (e) {
      print('게시물 상세 정보 불러오기 실패 (Dio): $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '게시물 정보를 불러오는 데 실패했습니다: ${e.response?.statusCode ?? '네트워크 오류'}',
          ),
        ),
      );
    } catch (e) {
      print('게시물 상세 정보 불러오기 실패: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('게시물 정보를 불러오는 데 실패했습니다.')));
    }
  }

  // --- 2. 날짜 선택기 ---
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedEndDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _selectedEndDate = DateTime(picked.year, picked.month, picked.day);
        _endDateController.text = DateFormat(
          'yyyy. MM. dd',
        ).format(_selectedEndDate!);
      });
    }
  }

  // 파일 MIME 타입을 추정하는 함수
  String _getMimeType(String filePath) {
    final ext = p.extension(filePath).toLowerCase();

    if (ext == '.png')
      return 'image/png';
    else if (ext == '.jpg' || ext == '.jpeg')
      return 'image/jpeg';
    else if (ext == '.pdf')
      return 'application/pdf';
    else if (ext == '.txt')
      return 'text/plain';
    else if (ext == '.zip')
      return 'application/zip';
    else if (ext == '.docx' || ext == '.doc')
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

    return 'application/octet-stream';
  }

  // 🔹 새 파일 선택 (교체/추가)
  Future<void> _selectNewFile() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result == null) return;

      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;

      setState(() {
        _newSelectedFile = file;
        _newSelectedFileName = fileName;
        _isExplicitlyDeleted = false; // 새 파일 선택 시 삭제 의도 취소
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("파일 선택 실패: $e")));
    }
  }

  // 🔹 기존 파일 정보 클리어 (삭제 준비)
  void _removeExistingFile() {
    setState(() {
      _existingFileName = null; // UI에서 기존 파일 표시 제거
      _newSelectedFile = null; // 새 파일 선택 취소
      _newSelectedFileName = null;
      _isExplicitlyDeleted = true; // ⭐️ 명시적 삭제 의도 설정
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("기존 파일이 삭제 대기 중입니다. '저장' 버튼을 눌러 확정하세요.")),
    );
  }

  // 🔹 파일 교체 API 호출 (PUT /upload/replaceFile)
  Future<String?> _replaceFile(File file, String fileName) async {
    try {
      final mimeType = _getMimeType(file.path);

      final formData = FormData.fromMap({
        "classUid": widget.classUid,
        "postUid": widget.postUid,
        "file": await MultipartFile.fromFile(
          file.path,
          filename: fileName,
          contentType: MediaType.parse(mimeType),
        ),
      });

      final dio = Dio();

      // POST 요청
      final response = await dio.post(
        "$API_BASE_URL/upload/replaceFile",
        data: formData,
        options: Options(
          contentType: "multipart/form-data",
          validateStatus: (_) => true, // 400/500도 바로 확인
        ),
      );

      print('Response status: ${response.statusCode}');
      print('Response data: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data['filePath'] as String?;
      } else {
        throw Exception(
          '서버 오류 ${response.statusCode}: ${response.data['message'] ?? response.data}',
        );
      }
    } catch (e) {
      print('파일 교체 실패: $e');
      rethrow;
    }
  }

  // 🔹 멘토 파일 폴더 비우기
  Future<void> _deletePostMentoFolder(String classUid, String postUid) async {
    try {
      final deleteMentoUrl =
          "$API_BASE_URL/upload/delete-post-mento/$classUid/$postUid";

      final dio = Dio();
      await dio.delete(deleteMentoUrl);
      print('DB에서 fileUrl=null 업데이트 성공 후, 멘토 파일 폴더 정리 완료');
    } catch (e) {
      print('멘토 파일 폴더 정리 실패: $e');
    }
  }

  // --- 3. 게시물 수정 API 호출  ---
  Future<void> _updatePost() async {
    if (_titleController.text.isEmpty || _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('제목과 내용을 입력해주세요.')));
      return;
    }

    Map<String, dynamic> body = {
      'postName': _titleController.text,
      'postDescription': _descriptionController.text,
    };

    // 마감일 처리
    if (_isAssignment) {
      if (_selectedEndDate != null) {
        body['postEndDate'] = _selectedEndDate!.toIso8601String();
      } else {
        body['postEndDate'] = null; // undefined 대신 null
      }
    }

    String? newFileUrlForDB;
    final String? originalFileUrl = _existingFileUrl;

    // 1. 파일 처리 로직 실행
    if (_newSelectedFile != null) {
      // A. 새 파일이 선택되었는가? (추가 또는 교체)
      try {
        newFileUrlForDB = await _replaceFile(
          _newSelectedFile!,
          _newSelectedFileName!,
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('파일 업로드/교체 실패로 수정을 중단합니다: ${e.toString()}')),
        );
        return;
      }
    } else if (_isExplicitlyDeleted && originalFileUrl != null) {
      // B. 기존 파일이 명시적으로 삭제되었는가?
      body['fileUrl'] = null; // DB에 fileUrl 필드를 null로 업데이트하도록 요청
    }

    // 2. 요청 본문에 파일 정보 반영
    if (newFileUrlForDB != null) {
      body['fileUrl'] = newFileUrlForDB;
    }

    // 3. 마감일 업데이트
    if (_isAssignment) {
      if (_selectedEndDate == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('과제의 마감일을 설정해주세요.')));
        return;
      }
      body['postEndDate'] = _selectedEndDate!.toIso8601String();
    }

    // 4. 게시물 수정 요청 (PUT)
    try {
      final dio = Dio();
      // PUT /post/post/:classUid/:postUid 경로 사용
      final url = '$API_BASE_URL/post/${widget.classUid}/${widget.postUid}';
      final response = await dio.put(url, data: body);

      if (response.statusCode == 200) {
        // 5. 게시물 수정 성공 후, 명시적 삭제 요청이 있었으면 폴더 비우기
        if (_isExplicitlyDeleted &&
            originalFileUrl != null &&
            newFileUrlForDB == null) {
          // 파일이 교체된 것이 아니라 완전히 삭제된 경우에만 폴더 정리 요청
          await _deletePostMentoFolder(widget.classUid, widget.postUid);
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('게시물이 성공적으로 수정되었습니다.')));
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('게시물 수정 실패: ${response.statusCode}')),
        );
      }
    } on DioException catch (e) {
      String message = e.response?.data['message'] ?? '게시물 수정 중 오류가 발생했습니다.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('수정 실패: $message')));
      print('Dio 오류: $e');
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('알 수 없는 오류가 발생했습니다.')));
    }
  }

  // --- 4. UI 구성 ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('게시물 수정'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _updatePost,
            child: const Text(
              '저장',
              style: TextStyle(
                color: Color(0xFF52B292),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: '제목',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: '내용',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 10,
                    minLines: 5,
                  ),
                  const SizedBox(height: 20),
                  if (_isAssignment) ...[
                    const Text(
                      '마감일',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => _selectDate(context),
                      child: AbsorbPointer(
                        child: TextField(
                          controller: _endDateController,
                          decoration: const InputDecoration(
                            labelText: '마감일 설정 (클릭)',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 파일 관리 섹션
                  const Text(
                    '첨부 파일 관리',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  _buildFileManagement(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  // 파일 관리 UI 위젯
  Widget _buildFileManagement() {
    // 1. 기존 파일 정보가 있고, 아직 삭제되지 않았을 때
    if (_existingFileName != null && !_isExplicitlyDeleted) {
      return Column(
        children: [
          // 기존 파일 표시 타일
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.description, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _existingFileName!,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // 기존 파일 삭제 버튼
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: _removeExistingFile, // 명시적 삭제 의도 설정
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // 파일 교체 버튼
          ElevatedButton.icon(
            onPressed: _selectNewFile,
            icon: const Icon(Icons.change_circle),
            label: const Text('파일 교체'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
              backgroundColor: Colors.grey.shade100,
              foregroundColor: Colors.black,
              elevation: 0,
            ),
          ),
        ],
      );
    }
    // 2. 새 파일이 선택되었을 때 (업로드/취소 버튼)
    else if (_newSelectedFile != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.green.shade400),
          borderRadius: BorderRadius.circular(8),
          color: Colors.green.shade50,
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, size: 20, color: Colors.green),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '새 파일 선택됨: ${_newSelectedFileName!}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            // 새 파일 선택 취소 버튼
            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.red),
              onPressed: () {
                setState(() {
                  _newSelectedFile = null;
                  _newSelectedFileName = null;
                  // 기존 파일이 있었으면 다시 삭제 의도를 해제
                  if (_existingFileUrl != null) {
                    _isExplicitlyDeleted = false;
                    _existingFileName = _existingFileUrl!
                        .split('/')
                        .last
                        .split('_')
                        .sublist(1)
                        .join('_'); // 파일명 복구
                  }
                });
              },
            ),
          ],
        ),
      );
    }
    // 3. 파일이 없거나 명시적으로 삭제되었을 때 (파일 추가 버튼)
    else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isExplicitlyDeleted && _existingFileUrl != null) // 삭제 대기 중 안내
            Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: Text(
                '기존 파일이 삭제 대기 중입니다. 새 파일을 첨부하거나 저장하세요.',
                style: TextStyle(
                  color: Colors.orange.shade700,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ElevatedButton.icon(
            onPressed: _selectNewFile,
            icon: const Icon(Icons.attachment),
            label: const Text('파일 첨부'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
              backgroundColor: Colors.grey.shade100,
              foregroundColor: Colors.black,
              elevation: 0,
            ),
          ),
        ],
      );
    }
  }
}
