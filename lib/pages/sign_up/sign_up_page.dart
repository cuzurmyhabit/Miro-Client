import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:miro/pages/main/class_list_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SignUpPage extends StatefulWidget {
  final User user;
  const SignUpPage({super.key, required this.user});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  int _step = 1;

  // 입력값 저장
  String? _selectedGrade;
  String? _selectedClass;
  String? _selectedNumber;
  String? _nickname;

  // final _numberController = TextEditingController();
  final _nicknameController = TextEditingController();

  final _nicknameFocus = FocusNode(); // 닉넴

  final List<String> grades = ["1학년", "2학년", "3학년"];
  final List<String> classes = ["1반", "2반", "3반", "4반", "5반", "6반"];
  final List<String> numbers = [
    "1",
    "2",
    "3",
    "4",
    "5",
    "6",
    "7",
    "8",
    "9",
    "10",
    "11",
    "12",
    "13",
    "14",
    "15",
    "16",
    "17",
    "18",
  ];

  @override
  void dispose() {
    // _numberController.dispose();
    _nicknameController.dispose();
    _nicknameFocus.dispose();
    super.dispose();
  }

  //  NestJS API 호출로 회원가입
  Future<void> _signUp() async {
    final url = Uri.parse(
      "http://localhost:3000/users/signup",
    ); // NestJS API 주소
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "uid": widget.user.uid,
        "name": widget.user.displayName ?? '',
        "email": widget.user.email ?? '',
        "grade": _selectedGrade,
        "class_room": _selectedClass, // DTO 필드명
        "number": _selectedNumber,
        "nickname": _nickname,
      }),
    );

    if (response.statusCode == 201) {
      // 성공 시 화면 이동
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => ClassListPage()),
          (route) => false,
        );
      }
    } else {
      // NestJS에서 BadRequestException 발생 시 메시지 표시
      String message = "회원가입 실패";
      try {
        final data = jsonDecode(response.body);
        if (data['message'] != null) {
          message = data['message'];
        }
      } catch (_) {}
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_step == 2) {
          setState(() {
            _step = 1;
            // _numberController.text = _selectedNumber ?? '';
          });
          return false; // 뒤로가기 막고 내부적으로 Step 1로 이동
        }
        return true; // Step 1이면 시스템 뒤로가기 허용
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(""),
          backgroundColor: Colors.white,
          elevation: 0,
          leading: _step == 2
              ? IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () {
                    setState(() {
                      _step = 1;
                      // _numberController.text = _studentNumber ?? '';
                    });
                  },
                )
              : null,
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: _step == 1 ? _buildStep1() : _buildStep2(),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    const double boxWidth = 361;
    const Color defaultBorderColor = Color(0xFFCECECE);
    // const Color focusedBorderColor = Color(0xFF424242);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 36.0),
          child: Text(
            "학교 정보를 입력해주세요",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),

        const Text("학년", style: TextStyle(fontSize: 14)),
        const SizedBox(height: 4),
        Container(
          width: boxWidth,
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: defaultBorderColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _selectedGrade,
            hint: const Text("학년을 선택해주세요"),
            dropdownColor: Colors.white,
            decoration: const InputDecoration(border: InputBorder.none),
            items: grades.map((grade) {
              return DropdownMenuItem(value: grade, child: Text(grade));
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedGrade = value);
            },
          ),
        ),

        const SizedBox(height: 20),
        const Text("반", style: TextStyle(fontSize: 14)),
        const SizedBox(height: 4),
        Container(
          width: boxWidth,
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: defaultBorderColor),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _selectedClass,
            hint: const Text("반을 선택해주세요"),
            dropdownColor: Colors.white,
            decoration: const InputDecoration(border: InputBorder.none),
            items: classes.map((cls) {
              return DropdownMenuItem(value: cls, child: Text(cls));
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedClass = value);
            },
          ),
        ),

        const SizedBox(height: 20),
        const Text("번호", style: TextStyle(fontSize: 14)),
        const SizedBox(height: 4),
        Container(
          width: boxWidth,
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: defaultBorderColor),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _selectedNumber,
            hint: const Text("번호를 선택해주세요"),
            dropdownColor: Colors.white,
            decoration: const InputDecoration(border: InputBorder.none),
            items: numbers.map((n) {
              return DropdownMenuItem(value: n, child: Text(n));
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedNumber = value);
            },
          ),
        ),

        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 70),
              child: SizedBox(
                width: 361,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6DEDC2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    if (_selectedGrade != null &&
                        _selectedClass != null &&
                        _selectedNumber != null) {
                      // _studentNumber = _numberController.text;
                      setState(() => _step = 2);
                      _nicknameController.text = _nickname ?? '';

                      // Step2로 이동 후 포커스 딜레이 주기 (이거 없으면 안되네요)
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        FocusScope.of(context).requestFocus(_nicknameFocus);
                      });
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("모든 항목을 입력해주세요.")),
                      );
                    }
                  },
                  child: const Text(
                    "다음",
                    style: TextStyle(
                      color: Color.fromARGB(255, 33, 33, 33),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    const double boxWidth = 361;
    const Color defaultBorderColor = Color(0xFFCECECE);
    const Color focusedBorderColor = Color(0xFF424242);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 36.0),
          child: Text(
            "닉네임을 입력해주세요",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: boxWidth,
          height: 56,
          child: TextField(
            controller: _nicknameController,
            keyboardType: TextInputType.text, // 한글/영문 입력 가능
            decoration: InputDecoration(
              hintText: "닉네임을 입력해주세요",
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: defaultBorderColor),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: focusedBorderColor),
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 16,
              ),
            ),
            onChanged: (value) => _nickname = value,
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 70),
              child: SizedBox(
                width: 361,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6DEDC2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    if (_nicknameController.text.isNotEmpty) {
                      _nickname = _nicknameController.text;
                      await _signUp(); //  NestJS API 호출
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("닉네임을 입력해주세요.")),
                      );
                    }
                  },
                  child: const Text(
                    "시작하기",
                    style: TextStyle(
                      color: Color.fromARGB(255, 33, 33, 33),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
