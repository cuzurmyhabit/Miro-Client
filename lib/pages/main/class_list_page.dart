import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

// 페이지 import
import '../chat/chat_page.dart';
import '../myclass/myclass_page.dart';
import '../mypage/mypage_page.dart';
import '../createClass/create_class_page.dart';

// 상단 필터 카테고리 정의
enum ClassCategory { all, design, development, etc }

class ClassListPage extends StatefulWidget {
  const ClassListPage({super.key});

  @override
  State<ClassListPage> createState() => _ClassListPageState();
}

class _ClassListPageState extends State<ClassListPage> {
  int _selectedIndex = 0;
  ClassCategory _selectedCategory = ClassCategory.all;

  final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(
    4,
    (_) => GlobalKey<NavigatorState>(),
  );

  List<Map<String, dynamic>> _openClasses = [];
  bool _isLoadingClasses = true;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _fetchOpenClasses();
  }

  String _getStringFromDynamic(dynamic data, String defaultValue) {
    if (data == null) {
      return defaultValue;
    }
    if (data is String) {
      return data;
    }
    if (data is Map<String, dynamic>) {
      return data['value'] is String
          ? data['value']
          : data.values.whereType<String>().isNotEmpty
          ? data.values.whereType<String>().first
          : defaultValue;
    }
    return data.toString();
  }

  Future<Map<String, String>> _fetchMentorDetails(String creatorUid) async {
    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(creatorUid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final String nickname = userData['nickname'] ?? '멘토 이름 없음';

        final String grade = userData['grade'] != null
            ? '${userData['grade']}'
            : '';
        final String classroom = userData['class_room'] != null
            ? '${userData['class_room']}'
            : '';
        final String number = userData['number'] != null
            ? '${userData['number']}번'
            : '';

        String mentorGrade = '';
        if (grade.isNotEmpty || classroom.isNotEmpty || number.isNotEmpty) {
          mentorGrade = '$grade $classroom $number'.trim();
        } else {
          mentorGrade = '정보 없음';
        }

        return {'mentorName': nickname, 'mentorGrade': mentorGrade};
      }
      return {'mentorName': '사용자 없음', 'mentorGrade': '정보 없음'};
    } catch (e) {
      print("멘토 정보 조회 오류 ($creatorUid): $e");
      return {'mentorName': '오류 발생', 'mentorGrade': '정보 없음'};
    }
  }

  Future<void> _fetchOpenClasses() async {
    setState(() => _isLoadingClasses = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final response = await http.get(
        Uri.parse('http://localhost:3000/classList/open'),
        headers: {'x-uid': user.uid},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _openClasses = List<Map<String, dynamic>>.from(data['data']);
          _isLoadingClasses = false;
        });
      } else {
        print("API 호출 실패: ${response.statusCode}");
        setState(() => _isLoadingClasses = false);
      }
    } catch (e) {
      print("API 호출 에러: $e");
      setState(() => _isLoadingClasses = false);
    }
  }

  Future<void> _joinClass(String classUid) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final response = await http.post(
        Uri.parse('http://localhost:3000/classList/join'),
        headers: {'x-uid': user.uid, 'Content-Type': 'application/json'},
        body: jsonEncode({'classUid': classUid}),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '참가 완료! 현재 인원: ${data['data']['currentParticipants']}',
            ),
          ),
        );
        _fetchOpenClasses();
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('참가 실패: ${data['message'] ?? response.statusCode}'),
          ),
        );
      }
    } catch (e) {
      print('참가 API 호출 에러: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('참가 중 오류 발생')));
    }
  }

  void _showClassDetailModal(Map<String, dynamic> classData) {
    final String classId = classData['classUid'] ?? 'unknown_id';
    final String className = classData['className'] ?? '제목 없음';
    final String description = classData['description'] ?? '설명 없음';
    final String field = classData['field'] ?? '';
    final int capacity = classData['capacity'] ?? 0;
    final String creatorUid = classData['creatorUid'] ?? '';

    final String requirement = _getStringFromDynamic(
      classData['requirement'],
      '없음',
    );
    final String caution = _getStringFromDynamic(classData['caution'], '없음');

    DateTime? _dateTimeFromMap(Map<String, dynamic>? map) {
      if (map == null) return null;
      if (map.containsKey('_seconds')) {
        return DateTime.fromMillisecondsSinceEpoch(map['_seconds'] * 1000);
      }
      return null;
    }

    String period = '기간 정보 없음';
    try {
      final startDate = _dateTimeFromMap(
        classData['startDate'] as Map<String, dynamic>?,
      );
      final endDate = _dateTimeFromMap(
        classData['endDate'] as Map<String, dynamic>?,
      );

      if (startDate != null && endDate != null) {
        period =
            '${DateFormat('yyyy. MM. dd').format(startDate)} ~ ${DateFormat('yyyy. MM. dd').format(endDate)}';
      }
    } catch (e) {
      print("날짜 변환 오류: $e");
      period = '기간 정보 오류';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30.0),
              topRight: Radius.circular(30.0),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: FutureBuilder<Map<String, String>>(
                future: _fetchMentorDetails(creatorUid),
                builder: (context, snapshot) {
                  String mentorName = '로딩 중...';
                  String mentorGrade = '정보 로딩 중...';

                  if (snapshot.connectionState == ConnectionState.done &&
                      snapshot.hasData) {
                    mentorName = snapshot.data!['mentorName']!;
                    mentorGrade = snapshot.data!['mentorGrade']!;
                  } else if (snapshot.hasError) {
                    mentorName = '조회 오류';
                    mentorGrade = '오류';
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          height: 5,
                          width: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24.0,
                          vertical: 16.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              className,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF212121),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              description,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF757575),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      mentorName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      mentorGrade,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF9E9E9E),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            const Divider(),
                            _buildInfoRow("분야", field),
                            _buildInfoRow("인원", "${capacity}인"),
                            _buildInfoRow("기간", period),
                            _buildInfoRow("조건", requirement),
                            _buildInfoRow("주의", caution, isNotice: true),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          if (snapshot.connectionState ==
                                  ConnectionState.done &&
                              snapshot.hasData) {
                            _joinClass(classId);
                          }
                        },
                        child: Container(
                          height: 56,
                          width: double.infinity,
                          margin: const EdgeInsets.only(
                            left: 24,
                            right: 24,
                            bottom: 30,
                            top: 16,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6DEDC2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            snapshot.connectionState != ConnectionState.done
                                ? '정보 로딩 중...'
                                : '참여하기',
                            style: const TextStyle(
                              color: Color(0xFF424242),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String title, String content, {bool isNotice = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 50,
            child: Text(
              title,
              style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              content,
              style: TextStyle(
                color: isNotice
                    ? const Color.fromARGB(255, 227, 67, 67)
                    : const Color(0xFF212121),
                fontSize: 14,
                fontWeight: isNotice ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onNavTap(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onCategoryTap(ClassCategory category) {
    setState(() {
      _selectedCategory = category;
    });
  }

  Widget _buildFilterChip(String label, ClassCategory category) {
    final bool isSelected = _selectedCategory == category;
    return GestureDetector(
      onTap: () => _onCategoryTap(category),
      child: Container(
        height: 40,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6DEDC2) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF6DEDC2)
                : const Color(0xFFCECECE),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: isSelected
                ? const Color(0xFF424242)
                : const Color(0xFF616161),
          ),
        ),
      ),
    );
  }

  Widget _buildClassListItem(Map<String, dynamic> classData) {
    final String field = classData['field'] ?? '분야';
    final String className = classData['className'] ?? '멘토 클래스 제목';
    final String creatorUid = classData['creatorUid'] ?? '';

    return GestureDetector(
      onTap: () {
        _showClassDetailModal(classData);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFBABABA),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    field,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    className,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF212121),
                    ),
                  ),
                  const SizedBox(height: 4),
                  FutureBuilder<Map<String, String>>(
                    future: _fetchMentorDetails(creatorUid),
                    builder: (context, snapshot) {
                      String mentorName = '로딩 중...';
                      if (snapshot.connectionState == ConnectionState.done &&
                          snapshot.hasData) {
                        mentorName = snapshot.data!['mentorName']!;
                      } else if (snapshot.hasError) {
                        mentorName = '정보 없음';
                      }

                      return Text(
                        '$mentorName 및 정보',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF9E9E9E)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabPage(int index) {
    switch (index) {
      case 0:
        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          appBar: AppBar(
            backgroundColor: const Color(0xFFF5F5F5),
            scrolledUnderElevation: 0,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: GestureDetector(
                  onTap: () {
                    // TODO: 검색 기능
                  },
                  child: const Icon(
                    Icons.search,
                    color: Color(0xFF424242),
                    size: 28,
                  ),
                ),
              ),
            ],
          ),
          body: Stack(
            children: [
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 헤더 영역
                    Container(
                      width: double.infinity,
                      alignment: Alignment.bottomLeft,
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                      child: const Text(
                        "오늘은 어떤 성장을\n이뤄볼까요?",
                        style: TextStyle(
                          color: Color(0xFF212121),
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    // 필터 칩 및 클래스 리스트
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(32),
                          topRight: Radius.circular(32),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20,),
                          // 필터 칩
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24.0,
                              vertical: 16.0,
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildFilterChip("전체", ClassCategory.all),
                                  _buildFilterChip("디자인", ClassCategory.design),
                                  _buildFilterChip(
                                    "개발",
                                    ClassCategory.development,
                                  ),
                                  _buildFilterChip("그 외", ClassCategory.etc),
                                ],
                              ),
                            ),
                          ),

                          // 클래스 리스트 섹션
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24.0,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 현재 클래스 목록
                                _isLoadingClasses
                                    ? const Center(
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 40,
                                          ),
                                          child: CircularProgressIndicator(),
                                        ),
                                      )
                                    : _openClasses.isEmpty
                                    ? const Center(
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 40,
                                          ),
                                          child: Text(
                                            "열린 클래스가 없습니다",
                                            style: TextStyle(fontSize: 16),
                                          ),
                                        ),
                                      )
                                    : Column(
                                        children: _openClasses
                                            .map(
                                              (classData) =>
                                                  _buildClassListItem(
                                                    classData,
                                                  ),
                                            )
                                            .toList(),
                                      ),
                                const SizedBox(height: 32),
                                const Text(
                                  "추천 클래스",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF212121),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // 추천 클래스
                                SizedBox(
                                  height: 150,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: 3,
                                    itemBuilder: (context, index) {
                                      return Container(
                                        width: 120,
                                        margin: const EdgeInsets.only(
                                          right: 16,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text('추천 클래스 ${index + 1}'),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 120),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      case 1:
        return MyClassPage();
      case 2:
        return ChatPage();
      case 3:
        return MyPage();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final navs = List<Widget>.generate(4, (i) {
      return Offstage(
        offstage: _selectedIndex != i,
        child: Navigator(
          key: _navigatorKeys[i],
          onGenerateRoute: (_) =>
              MaterialPageRoute(builder: (_) => _buildTabPage(i)),
        ),
      );
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          ...navs,
          // 플로팅 네비게이션 바
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    spreadRadius: 2,
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavBarItem(
                    iconPath: "assets/icons/home_icon.png",
                    hoverIconPath: "assets/icons/home_hover_icon.png",
                    label: "홈",
                    isSelected: _selectedIndex == 0,
                    onTap: () => _onNavTap(0),
                  ),
                  _NavBarItem(
                    iconPath: "assets/icons/class_icon.png",
                    hoverIconPath: "assets/icons/class_hover_icon.png",
                    label: "내 수업",
                    isSelected: _selectedIndex == 1,
                    onTap: () => _onNavTap(1),
                  ),
                  _NavBarItem(
                    iconPath: "assets/icons/chat_icon.png",
                    hoverIconPath: "assets/icons/chat_hover_icon.png",
                    label: "채팅",
                    isSelected: _selectedIndex == 2,
                    onTap: () => _onNavTap(2),
                  ),
                  _NavBarItem(
                    iconPath: "assets/icons/mypage_icon.png",
                    hoverIconPath: "assets/icons/mypage_hover_icon.png",
                    label: "마이페이지",
                    isSelected: _selectedIndex == 3,
                    onTap: () => _onNavTap(3),
                  ),
                ],
              ),
            ),
          ),
          // 원형 버튼 (+)
          Positioned(
            bottom: 110,
            right: 30,
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateClassPage(),
                  ),
                );
              },
              child: Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Color(0xFF6DEDC2),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color.fromRGBO(109, 237, 194, 0.4),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add,
                  color: Color(0xFF424242),
                  size: 30,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final String iconPath;
  final String hoverIconPath;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.iconPath,
    required this.hoverIconPath,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              isSelected ? hoverIconPath : iconPath,
              width: 24,
              height: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected
                    ? const Color(0xFF52B292)
                    : const Color(0xFF9E9E9E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
