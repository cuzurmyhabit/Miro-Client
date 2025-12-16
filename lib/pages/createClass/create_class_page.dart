import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:miro/api/addClass_api.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

class CreateClassPage extends StatefulWidget {
  const CreateClassPage({super.key});

  @override
  State<CreateClassPage> createState() => _CreateClassPageState();
}

class _CreateClassPageState extends State<CreateClassPage> {
  String _selectedCategory = '디자인';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));

  String _className = '';
  String _classDescription = '';
  String _classCapacity = '';
  String _classCondition = '';
  String _classCaution = '';

  // 이미지 관련 변수
  File? _coverImageFile;
  String? _coverImageUrl;
  bool _isUploadingImage = false;

  final DateFormat _dateFormat = DateFormat('yyyy. MM. dd');
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  // 모든 필수 필드 유효성 검사
  bool get _isFormValid {
    return _className.isNotEmpty &&
        _classDescription.isNotEmpty &&
        _classCapacity.isNotEmpty &&
        _classCondition.isNotEmpty &&
        _classCaution.isNotEmpty &&
        _coverImageFile != null;
  }

  // 커버 사진 업로드
  Future<void> _uploadCoverPhoto() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        // 파일 확장자 확인
        final extension = path.extension(pickedFile.path).toLowerCase();
        if (extension != '.png' && extension != '.jpg' && extension != '.jpeg') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("PNG 또는 JPG 파일만 업로드 가능합니다.")),
            );
          }
          return;
        }

        setState(() {
          _coverImageFile = File(pickedFile.path);
          _isUploadingImage = true;
        });

        // Firebase Storage에 업로드
        await _uploadImageToFirebase(_coverImageFile!);

        setState(() {
          _isUploadingImage = false;
        });
      }
    } catch (e) {
      setState(() {
        _isUploadingImage = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("이미지 선택 중 오류가 발생했습니다: $e")),
        );
      }
    }
  }

  // Firebase Storage에 이미지 업로드
  Future<void> _uploadImageToFirebase(File imageFile) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("로그인이 필요합니다.");

      final String fileName = 
          'class_covers/${user.uid}/${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';
      
      final Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
      final UploadTask uploadTask = storageRef.putFile(imageFile);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      setState(() {
        _coverImageUrl = downloadUrl;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("커버 이미지가 업로드되었습니다."),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      print("❌ 이미지 업로드 오류: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("이미지 업로드 실패: $e")),
        );
      }
      rethrow;
    }
  }

  // 분야 선택
  void _selectCategory(String category) {
    setState(() {
      _selectedCategory = category;
    });
  }

  // 날짜 선택
  Future<void> _selectDate(
    BuildContext context, {
    required bool isStartDate,
  }) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime(2030),
      helpText: isStartDate ? '시작 기간 선택' : '종료 기간 선택',
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate.isBefore(picked)) {
            _endDate = picked;
          }
        } else {
          if (picked.isBefore(_startDate)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("종료일은 시작일보다 빠를 수 없습니다.")),
            );
            return;
          }
          _endDate = picked;
        }
      });
    }
  }

  // 클래스 생성 제출
  Future<void> _submitClass() async {
    if (!_isFormValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("모든 필수 항목을 입력해주세요."))
      );
      return;
    }

    if (_coverImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("커버 이미지를 업로드해주세요."))
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final coverImages = [
        {
          "fileName": path.basename(_coverImageFile!.path),
          "url": _coverImageUrl!,
          "path": _coverImageUrl!,
        },
      ];

      final user = FirebaseAuth.instance.currentUser;
      final String creatorUid = user!.uid;
      
      final result = await AddClassApiService.addClass(
        classUid: DateTime.now().millisecondsSinceEpoch.toString(),
        creatorUid: creatorUid,
        coverImg: coverImages,
        className: _className,
        description: _classDescription,
        field: _selectedCategory,
        requirement: _classCondition,
        caution: _classCaution,
        capacity: _classCapacity,
        startDate: _startDate.toIso8601String(),
        endDate: _endDate.toIso8601String(),
      );

      print("✅ 서버 응답: $result");

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("클래스가 성공적으로 생성되었습니다."),
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("클래스 생성 실패: $e"))
        );
      }
      print("❌ 오류 발생: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 분야 칩 위젯
  Widget _buildCategoryChip(String label) {
    final isSelected = _selectedCategory == label;
    return GestureDetector(
      onTap: () => _selectCategory(label),
      child: Chip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        backgroundColor: isSelected ? const Color(0xFF6DEDC2) : Colors.grey[200],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? const Color(0xFF6DEDC2) : Colors.transparent,
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      ),
    );
  }

  // 날짜 박스 위젯
  Widget _buildDateBox(DateTime date, {required bool isStartDate}) {
    return Expanded(
      child: InkWell(
        onTap: () => _selectDate(context, isStartDate: isStartDate),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                _dateFormat.format(date),
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 텍스트 필드 위젯
  Widget _buildTextField({
    required String label,
    required String hintText,
    String? subText,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    required void Function(String) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        if (subText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              subText,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ),
        const SizedBox(height: 8),
        TextField(
          onChanged: onChanged,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hintText,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 10,
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          "클래스 생성",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 커버사진 섹션
            const Text(
              "커버사진",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _isUploadingImage ? null : _uploadCoverPhoto,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                  image: _coverImageFile != null
                      ? DecorationImage(
                          image: FileImage(_coverImageFile!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _isUploadingImage
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF6DEDC2),
                        ),
                      )
                    : _coverImageFile == null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add, size: 40, color: Colors.grey),
                                const SizedBox(height: 8),
                                Text(
                                  'PNG 또는 JPG 파일 업로드',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Align(
                            alignment: Alignment.topRight,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                padding: const EdgeInsets.all(4),
                                child: const Icon(
                                  Icons.edit,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
              ),
            ),
            const SizedBox(height: 24),

            // 클래스 이름
            _buildTextField(
              label: "클래스 이름",
              hintText: "클래스 이름을 입력해주세요",
              onChanged: (value) => setState(() => _className = value),
            ),

            // 클래스 설명
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "클래스 설명",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  "${_classDescription.length}/200",
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              onChanged: (value) => setState(() => _classDescription = value),
              maxLines: 4,
              maxLength: 200,
              decoration: const InputDecoration(
                hintText: "클래스에 관한 설명을 입력해주세요",
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(10),
                counterText: "",
              ),
            ),
            const SizedBox(height: 24),

            // 분야
            const Text(
              "분야",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                _buildCategoryChip("디자인"),
                const SizedBox(width: 8),
                _buildCategoryChip("개발"),
                const SizedBox(width: 8),
                _buildCategoryChip("그외"),
              ],
            ),
            const SizedBox(height: 24),

            // 인원
            _buildTextField(
              label: "인원",
              subText: "최대 인원수를 설정해주세요",
              hintText: "인원수를 입력해주세요",
              keyboardType: TextInputType.number,
              onChanged: (value) => setState(() => _classCapacity = value),
            ),

            // 조건
            _buildTextField(
              label: "조건",
              subText: "클래스 가입 조건을 설정해주세요",
              hintText: "조건을 입력해주세요 (ex: html이 뭔지 아는 사람)",
              onChanged: (value) => setState(() => _classCondition = value),
            ),

            // 주의사항
            _buildTextField(
              label: "주의",
              subText: "클래스의 주의사항을 입력해주세요",
              hintText: "주의사항을 입력해주세요",
              onChanged: (value) => setState(() => _classCaution = value),
            ),

            // 기간
            const Text(
              "기간",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                _buildDateBox(_startDate, isStartDate: true),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Icon(Icons.chevron_right),
                ),
                _buildDateBox(_endDate, isStartDate: false),
              ],
            ),
            const SizedBox(height: 40),

            // 시작하기 버튼
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isFormValid && !_isLoading ? _submitClass : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isFormValid
                        ? const Color(0xFF6DEDC2)
                        : Colors.grey,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "시작하기",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}