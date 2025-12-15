import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:miro/api/addClass_api.dart';
import '../main/class_list_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateClassPage extends StatefulWidget {
  const CreateClassPage({super.key});

  @override
  State<CreateClassPage> createState() => _CreateClassPageState();
}

class _CreateClassPageState extends State<CreateClassPage> {
  // 1. 상태 변수 정의 및 필수 필드 변수 추가
  String _selectedCategory = '디자인';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));

  // 필수 입력 필드 상태 변수
  String _className = '';
  String _classDescription = '';
  String _classCapacity = '';
  String _classCondition = '';
  String _classCaution = '';

  final DateFormat _dateFormat = DateFormat('yyyy. MM. dd');
  bool _isLoading = false; //  로딩 상태 추가

  // 모든 필수 필드가 유효한지 확인하는 Getter
  bool get _isFormValid {
    return _className.isNotEmpty &&
        _classDescription.isNotEmpty &&
        _classCapacity.isNotEmpty &&
        _classCondition.isNotEmpty &&
        _classCaution.isNotEmpty;
    // 참고: 커버 사진 업로드 여부는 현재 상태 변수에 없으므로 제외했습니다.
  }

  // 커버 사진 업로드 (더미 로직)
  void _uploadCoverPhoto() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("커버 사진 업로드 기능을 실행합니다. (실제 파일 선택)"),
        duration: Duration(seconds: 1),
      ),
    );
  }

  // 분야 선택 로직
  void _selectCategory(String category) {
    setState(() {
      _selectedCategory = category;
    });
  }

  // 기간 선택 로직 (캘린더 사용)
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

  // 클래스 생성 API 호출 함수 추가
  Future<void> _submitClass() async {
    if (!_isFormValid) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("모든 필수 항목을 입력해주세요.")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // API 호출
      final coverImages = [
        {
          "fileName": "cover.png",
          "url":
              "https://your-server.com/assets/cover.png", // 실제 서버에 배포된 URL 필요
          "path": "/assets/cover.png",
        },
      ];

      final user = FirebaseAuth.instance.currentUser;
      final String creatorUid = user!.uid;
      final result = await AddClassApiService.addClass(
        classUid: DateTime.now().millisecondsSinceEpoch.toString(), // 간단한 UID
        creatorUid: creatorUid, // 실제 로그인된 사용자 UID로 교체
        coverImg: coverImages, // 커버 사진 (임시)
        className: _className,
        description: _classDescription,
        field: _selectedCategory,
        requirement: _classCondition,
        caution: _classCaution,
        capacity: _classCapacity,
        startDate: _startDate.toIso8601String(), // ISO8601 포맷으로 변환
        endDate: _endDate.toIso8601String(),
      );

      // 성공 시 페이지 이동
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("클래스가 성공적으로 생성되었습니다.")));
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ClassListPage()),
        );
      }

      print(" 서버 응답: $result");
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("클래스 생성 실패: $e")));
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
        backgroundColor: isSelected ? Color(0xFF6DEDC2) : Colors.grey[200],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? Color(0xFF6DEDC2) : Colors.transparent,
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      ),
    );
  }

  // 기간 날짜 박스 위젯
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

  // 공통 텍스트 필드 위젯
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
        foregroundColor: Colors.black, // 아이콘 색상 설정
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 3. 커버 사진 섹션
            const Text(
              "커버사진",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _uploadCoverPhoto,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(Icons.add, size: 40, color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 4. 클래스 이름 섹션
            _buildTextField(
              label: "클래스 이름",
              hintText: "클래스 이름을 입력해주세요",
              onChanged: (value) => setState(() => _className = value),
            ),

            // 5. 클래스 설명 섹션
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "클래스 설명",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  "${_classDescription.length}/200", // 입력 길이를 반영
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              onChanged: (value) => setState(() => _classDescription = value),
              maxLines: 4,
              maxLength: 200, // 최대 길이 제한
              decoration: const InputDecoration(
                hintText: "클래스에 관한 설명을 입력해주세요",
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(10),
                counterText: "", // 기본 길이 카운터 숨김 (위에서 커스텀 표시)
              ),
            ),
            const SizedBox(height: 24),

            // 6. 분야 섹션 (단일 선택 가능)
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

            // 7. 인원 섹션
            _buildTextField(
              label: "인원",
              subText: "최대 인원수를 설정해주세요",
              hintText: "인원수를 입력해주세요",
              keyboardType: TextInputType.number,
              onChanged: (value) => setState(() => _classCapacity = value),
            ),

            // 8. 조건 섹션
            _buildTextField(
              label: "조건",
              subText: "클래스 가입 조건을 설정해주세요",
              hintText: "조건을 입력해주세요 (ex: html이 뭔지 아는 사람)",
              onChanged: (value) => setState(() => _classCondition = value),
            ),

            // 9. 주의사항 섹션
            _buildTextField(
              label: "주의",
              subText: "클래스의 주의사항을 입력해주세요",
              hintText: "주의사항을 입력해주세요",
              onChanged: (value) => setState(() => _classCaution = value),
            ),

            // 10. 기간 섹션 (캘린더 선택 가능)
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

            // 11. 시작하기 버튼 (가장 마지막에 추가)
            //  시작하기 버튼 교체
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isFormValid && !_isLoading
                      ? _submitClass
                      : null, // 수정
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
