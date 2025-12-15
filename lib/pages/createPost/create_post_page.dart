import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:http_parser/http_parser.dart';
import 'dart:io';
import 'package:uuid/uuid.dart';

class CreatePostPage extends StatefulWidget {
  final String classUid;

  const CreatePostPage({super.key, required this.classUid});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String _selectedCategory = 'assignment';
  bool _isLoading = false;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  final DateFormat _dateFormat = DateFormat('yyyy. MM. dd');

  File? _selectedFile;
  String? _uploadedFileUrl;

  late String _postUid; // 게시물 고유 UID

  bool get _isFormValid =>
      _titleController.text.isNotEmpty &&
      _descriptionController.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _postUid = const Uuid().v4(); // 게시물 UID 생성
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // 파일 선택
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: false);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
      });
    }
  }

  // 파일 업로드
  // 파일 업로드
  Future<String?> _uploadFile(File file) async {
    final fileUid = const Uuid().v4();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('http://localhost:3000/upload/uploadFile'),
    );

    // ✅ 텍스트 필드 먼저 넣기 (multer가 req.body 인식하게)
    request.fields.addAll({
      "classUid": widget.classUid,
      "postUid": _postUid,
      "postState": _selectedCategory, // assignment or material
      "role": "Mento",
      "fileUid": fileUid, // ✅ 필수 값 추가
    });

    // ✅ 파일 추가 (텍스트 필드 이후)
    final ext = p.extension(file.path).toLowerCase();
    String mimeType = 'application/octet-stream';
    if (ext == '.png')
      mimeType = 'image/png';
    else if (ext == '.jpg' || ext == '.jpeg')
      mimeType = 'image/jpeg';
    else if (ext == '.pdf')
      mimeType = 'application/pdf';
    else if (ext == '.txt')
      mimeType = 'text/plain';

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: p.basename(file.path),
        contentType: MediaType(mimeType.split('/')[0], mimeType.split('/')[1]),
      ),
    );

    final response = await request.send();
    final resBody = await response.stream.bytesToString();

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(resBody)['filePath'];
    } else {
      throw Exception("파일 업로드 실패: $resBody");
    }
  }

  Future<void> _submitPost() async {
    if (!_isFormValid) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("제목과 설명을 모두 입력해주세요.")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_selectedFile != null) {
        _uploadedFileUrl = await _uploadFile(_selectedFile!);
      }

      final isAssignment = _selectedCategory == 'assignment';

      final body = {
        "rootClassUid": widget.classUid,
        "postState": _selectedCategory,
        "postList": [
          {
            "postUid": _postUid,
            "postName": _titleController.text,
            "postDescription": _descriptionController.text,
            if (isAssignment) "postStartDate": _startDate.toIso8601String(),
            if (isAssignment) "postEndDate": _endDate.toIso8601String(),
            "fileUrl": _uploadedFileUrl ?? null, // 첨부 파일
            "submissionUrls": <String>[], // 멘티 제출 파일 초기값
          },
        ],
      };

      final url = Uri.parse('http://localhost:3000/post/addPost');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('API 오류: ${response.body}');
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("게시물이 성공적으로 작성되었습니다.")));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("게시물 작성 실패: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        if (isStart)
          _startDate = picked;
        else
          _endDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "게시물 작성",
          style: TextStyle(color: Colors.black, fontSize: 18),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTitle(),
            const SizedBox(height: 24),
            _buildDescription(),
            const SizedBox(height: 24),
            _buildCategory(),
            const SizedBox(height: 24),
            _buildAttachmentField(),
            const SizedBox(height: 24),
            if (_selectedCategory == 'assignment') _buildDatePicker(),
            if (_selectedCategory == 'assignment') const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isFormValid && !_isLoading ? _submitPost : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6DEDC2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text(
                        "작성하기",
                        style: TextStyle(color: Colors.black, fontSize: 18),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        "제목",
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      _field(_titleController, "게시물 제목 입력", (_) => setState(() {})),
    ],
  );

  Widget _buildDescription() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        "설명",
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      _field(
        _descriptionController,
        "게시물 설명 입력",
        (_) => setState(() {}),
        maxLines: 5,
      ),
    ],
  );

  Widget _buildCategory() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        "분야",
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          _categoryBtn('과제', 'assignment'),
          const SizedBox(width: 8),
          _categoryBtn('자료', 'material'),
        ],
      ),
    ],
  );

  Widget _buildAttachmentField() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        "첨부파일",
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: _pickFile,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              const Icon(Icons.attachment, color: Colors.grey),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _selectedFile == null
                      ? "파일 첨부"
                      : p.basename(_selectedFile!.path),
                  style: const TextStyle(color: Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _buildDatePicker() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        "기간",
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: _dateField(_startDate, () => _selectDate(context, true)),
          ),
          const SizedBox(width: 8),
          const Text('>', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: _dateField(_endDate, () => _selectDate(context, false)),
          ),
        ],
      ),
    ],
  );

  Widget _field(
    TextEditingController c,
    String hint,
    Function(String) onChanged, {
    int maxLines = 1,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.grey[100],
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.grey[300]!),
    ),
    child: TextField(
      controller: c,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
      ),
    ),
  );

  Widget _categoryBtn(String label, String value) {
    final selected = _selectedCategory == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF6DEDC2) : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.grey[700],
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _dateField(DateTime date, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            _dateFormat.format(date),
            style: const TextStyle(color: Colors.black87),
          ),
        ],
      ),
    ),
  );
}
