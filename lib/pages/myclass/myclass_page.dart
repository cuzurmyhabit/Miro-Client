import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../classRoom/class_room_page.dart'; // 입장 페이지

// 정렬 옵션 정의
enum SortOption { deadline, latest, popular }

class MyClassPage extends StatefulWidget {
  const MyClassPage({super.key});

  @override
  State<MyClassPage> createState() => _MyClassPageState();
}

class _MyClassPageState extends State<MyClassPage> {
  bool isMentorView = false;
  bool _isLoading = false;
  String? _errorMessage;
  
  // 정렬 상태 추가
  SortOption _currentSort = SortOption.deadline;

  List<Map<String, dynamic>> _mentoClass = [];
  List<Map<String, dynamic>> _mentiClass = [];

  // 요청된 색상 정의
  static const Color primaryActiveColor = Color(0xFF6DEDC2);

  @override
  void initState() {
    super.initState();
    _fetchMenteeClass();
  }

  // Helper: 정렬 옵션 텍스트 변환
  String _getSortOptionText(SortOption option) {
    switch (option) {
      case SortOption.deadline:
        return '마감 임박 순';
      case SortOption.latest:
        return '최신 순';
      case SortOption.popular:
        return '인기 순';
    }
  }

  // 💡 정렬 순서 반대: 모집 완료된 수업을 맨 아래로 보내는 정렬 헬퍼 함수
  List<Map<String, dynamic>> _sortClasses(List<Map<String, dynamic>> list) {
    list.sort((a, b) {
      final int aCount = (a['mentiUidArray'] as List?)?.length ?? 0;
      final int aCapacity = a['capacity'] ?? 0;
      final int bCount = (b['mentiUidArray'] as List?)?.length ?? 0;
      final int bCapacity = b['capacity'] ?? 0;

      final bool aIsFull = a['status'] == 'Waiting' && aCount >= aCapacity;
      final bool bIsFull = b['status'] == 'Waiting' && bCount >= bCapacity;

      // 1. 모집 완료 상태를 맨 아래로 정렬 (반대로 변경)
      if (aIsFull != bIsFull) {
        return aIsFull ? 1 : -1; // a가 꽉 찼으면 a가 아래로 (1), b가 꽉 찼으면 b가 아래로 (-1)
      }
      
      return 0; // 순서 변경 없음 (API가 준 2차 정렬 순서 유지)
    });
    return list;
  }

  // --- 데이터 페칭 함수 (정렬 적용) ---
  Future<void> _fetchMentoClass({SortOption? sortOption}) async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("로그인이 필요합니다.");

      final response = await http.get(
        Uri.parse('http://localhost:3000/classList/mentoClass?sort=${sortOption ?? _currentSort.name}'),
        headers: {'x-uid': user.uid, 'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        List<Map<String, dynamic>> fetchedList = List<Map<String, dynamic>>.from(body['data']);
        
        setState(() {
          _mentoClass = _sortClasses(fetchedList); // 💡 정렬 적용
        });
      } else {
        final body = jsonDecode(response.body);
        print('서버 오류: $body');
        setState(() {
          _errorMessage = '서버 오류';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchMenteeClass({SortOption? sortOption}) async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("로그인이 필요합니다.");

      final response = await http.get(
        Uri.parse('http://localhost:3000/classList/mentiClass?sort=${sortOption ?? _currentSort.name}'),
        headers: {'x-uid': user.uid, 'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        List<Map<String, dynamic>> fetchedList = List<Map<String, dynamic>>.from(body['data']);
        
        setState(() {
          _mentiClass = _sortClasses(fetchedList); // 💡 정렬 적용
        });
      } else {
        final body = jsonDecode(response.body);
        print('서버 오류: $body');
        setState(() {
          _errorMessage = '서버 오류';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 수업 시작 함수는 기존과 동일
  Future<void> _startClass(String classUid) async {
    try {
      final response = await http.post(
        Uri.parse('http://localhost:3000/classList/start'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'classUid': classUid}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        setState(() {
          _mentoClass = _mentoClass.map((cls) {
            if (cls['classUid'] == classUid) {
              return {...cls, 'status': 'Running'};
            }
            return cls;
          }).toList();
          _mentoClass = _sortClasses(_mentoClass); // 💡 상태 변경 후 정렬 재적용
        });
        print('수업 시작 성공: $body');
      } else {
        final body = jsonDecode(response.body);
        
        print('수업 시작 실패: $body');
      }
    } catch (e) {
      print('수업 시작 예외: $e');
    }
  }
  
  // Helper 함수: 상태 표시 및 색상 결정 (기존과 동일)
  Map<String, dynamic> _getStatusDisplay(String status, int currentCount, int capacity) {
    String text;
    Color color;
    const Color recruitingColor = primaryActiveColor; // 요청하신 색상

    if (status == 'Completed' || status == 'Done') {
      text = '완료';
      color = Colors.grey.shade400;
    } else if (status == 'Running') {
      text = '진행 중';
      color = primaryActiveColor;
    } else if (status == 'Waiting') {
      if (currentCount < capacity) {
        text = '모집 중';
        color = recruitingColor; 
      } else {
        text = '모집 완료';
        color = Colors.orange; // 꽉 찬 경우
      }
    } else {
      text = '대기중';
      color = Colors.grey;
    }
    return {'text': text, 'color': color};
  }


  // 수업 카드 위젯 (버튼 크기 통일)
  Widget _buildClassCard(
    Map<String, dynamic> cls, 
    Widget? trailingWidget, 
    String countText,
    String creator,
  ) {
    final statusData = _getStatusDisplay(
        cls['status'] ?? 'Unknown',
        (cls['mentiUidArray'] as List?)?.length ?? 0,
        cls['capacity'] ?? 0,
    );
    
    const double cardWidth = 350.0; 
    const double imageHeight = 100.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 커버 이미지 및 상단 상태 태그
          Stack(
            children: [
              SizedBox(
                width: double.infinity,
                height: imageHeight,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10.0),
                  child: Image.asset(
                    "assets/coverImg/cover.png", 
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              // 모집 상태 태그
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusData['color'].withOpacity(0.9), 
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    statusData['text'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              // React 아이콘 Placeholder
              const Positioned(
                bottom: 8,
                right: 8,
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.code, size: 20, color: Color(0xFF61DAFB)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          // 2. 제목
          Text(
            cls['className'] ?? '이름 없음',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4.0),
          // 3. 서브 정보 (강의 수 | 멘토 이름)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '현재 0강 | $creator', 
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              // 4. 인원/버튼 영역 - 버튼이 없어도 동일한 공간 유지
              Row(
                children: [
                  Text(
                    countText,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 💡 버튼 영역을 항상 동일한 크기로 유지
                  SizedBox(
                    width: 70,
                    height: 30,
                    child: trailingWidget ?? const SizedBox.shrink(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16.0), 
        ],
      ),
    );
  }

  // --- 멘토 뷰 ---
  Widget _buildMentorView() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) return Center(child: Text(_errorMessage!));
    if (_mentoClass.isEmpty)
      return const Center(child: Text("운영 중인 수업이 없습니다."));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "내가 운영 중인 수업",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              // 정렬 토글 버튼 (Dropdown) - 배경색 하얀색으로 변경
              PopupMenuButton<SortOption>(
                color: Colors.white, // 배경색 설정
                surfaceTintColor: Colors.white, // Material 3 색조 제거
                onSelected: (SortOption result) {
                  setState(() {
                    _currentSort = result;
                    _fetchMentoClass(sortOption: result); 
                  });
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<SortOption>>[
                  const PopupMenuItem<SortOption>(
                    value: SortOption.deadline,
                    child: Text('마감 임박 순'),
                  ),
                  const PopupMenuItem<SortOption>(
                    value: SortOption.latest,
                    child: Text('최신 순'),
                  ),
                  const PopupMenuItem<SortOption>(
                    value: SortOption.popular,
                    child: Text('인기 순'),
                  ),
                ],
                child: Row(
                  children: [
                    Text(_getSortOptionText(_currentSort), style: const TextStyle(color: Colors.black)),
                    const Icon(Icons.arrow_drop_down, color: Colors.black),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _mentoClass.length,
            itemBuilder: (context, index) {
              final cls = _mentoClass[index];
              final String status = cls['status'] ?? 'Unknown';
              final int capacity = cls['capacity'] ?? 0;
              final int currentMentiCount = (cls['mentiUidArray'] as List?)?.length ?? 0;
              final String classUid = cls['classUid'] ?? 'unknown_id';
              final String creator = cls['creatorName'] ?? '멘토';

              String buttonText = '';
              Color buttonColor = Colors.grey;
              VoidCallback? onPressed;
              final Color activeGreen = primaryActiveColor;

              final bool isFull = status == 'Waiting' && currentMentiCount >= capacity;

              Widget? trailingWidget;

              if (status == 'Waiting') {
                if (isFull) { // 꽉 찬 경우
                  buttonText = '시작하기';
                  buttonColor = activeGreen; 
                  onPressed = () => _startClass(classUid);
                } else { // 모집 중인 경우
                  buttonText = '모집 중';
                  buttonColor = Colors.grey.shade300; 
                  onPressed = null;
                }
                trailingWidget = ElevatedButton(
                  onPressed: onPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: Text(buttonText),
                );
              } else if (status == 'Running') {
                buttonText = '입장하기';
                buttonColor = primaryActiveColor;
                onPressed = () {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                        builder: (_) => ClassRoomPage(
                          creatorUid: cls['creatorUid'],
                          classUid: cls['classUid'],
                          userUid: user.uid,
                        ),
                      ),
                    );
                  }
                };
                trailingWidget = ElevatedButton(
                  onPressed: onPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: Text(buttonText),
                );
              } else if (status == 'Completed' || status == 'Done') {
                buttonText = '완료됨';
                buttonColor = Colors.grey.shade400;
                trailingWidget = ElevatedButton(
                  onPressed: null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: Text(buttonText),
                );
              }

              return _buildClassCard(
                cls,
                trailingWidget,
                '$currentMentiCount/$capacity',
                creator,
              );
            },
          ),
        ),
      ],
    );
  }

  // --- 멘티 뷰 ---
  Widget _buildMenteeView() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) return Center(child: Text(_errorMessage!));
    if (_mentiClass.isEmpty)
      return const Center(child: Text("수강 중인 수업이 없습니다."));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "내가 수강 중인 수업",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              // 정렬 토글 버튼 (Dropdown) - 배경색 하얀색으로 변경
              PopupMenuButton<SortOption>(
                color: Colors.white, // 배경색 설정
                surfaceTintColor: Colors.white, // Material 3 색조 제거
                onSelected: (SortOption result) {
                  setState(() {
                    _currentSort = result;
                    _fetchMenteeClass(sortOption: result); 
                  });
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<SortOption>>[
                  const PopupMenuItem<SortOption>(
                    value: SortOption.deadline,
                    child: Text('마감 임박 순'),
                  ),
                  const PopupMenuItem<SortOption>(
                    value: SortOption.latest,
                    child: Text('최신 순'),
                  ),
                  const PopupMenuItem<SortOption>(
                    value: SortOption.popular,
                    child: Text('인기 순'),
                  ),
                ],
                child: Row(
                  children: [
                    Text(_getSortOptionText(_currentSort), style: const TextStyle(color: Colors.black)),
                    const Icon(Icons.arrow_drop_down, color: Colors.black),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _mentiClass.length,
            itemBuilder: (context, index) {
              final cls = _mentiClass[index];
              final String status = cls['status'] ?? 'Unknown';
              final String creator = cls['creatorName'] ?? '멘토';
              final int capacity = cls['capacity'] ?? 0;
              final int currentMentiCount = (cls['mentiUidArray'] as List?)?.length ?? 0;

              Widget? trailingWidget;
              String countText = '$currentMentiCount/$capacity';

              if (status == 'Running') {
                trailingWidget = ElevatedButton(
                  onPressed: () {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(
                          builder: (_) => ClassRoomPage(
                            creatorUid: cls['creatorUid'],
                            classUid: cls['classUid'],
                            userUid: user.uid,
                          ),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryActiveColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: const Text('입장하기'),
                );
              }

              return _buildClassCard(
                cls,
                trailingWidget,
                countText,
                creator,
              );
            },
          ),
        ),
      ],
    );
  }

  // --- 탭 뷰 (기존과 동일) ---
  Widget _buildTabView(BuildContext context) {
    const Color activeColor = primaryActiveColor; 

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(top: 0.0, bottom: 0),
      child: Row(
        children: [
          Expanded(
            child: _tabButton(
              '멘티 보기', 
              !isMentorView, 
              () {
                if (isMentorView) {
                  setState(() => isMentorView = false);
                  _fetchMenteeClass();
                }
              },
              activeColor,
            ),
          ),
          Expanded(
            child: _tabButton(
              '멘토 보기', 
              isMentorView, 
              () {
                if (!isMentorView) {
                  setState(() => isMentorView = true);
                  _fetchMentoClass();
                }
              },
              activeColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton(String text, bool isActive, VoidCallback onTap, Color activeColor) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12.0),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? activeColor : Colors.transparent,
              width: 3.0,
            ),
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isActive ? activeColor : Colors.black,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                children: [
                  const SizedBox.shrink(),
                ],
              ),
            ),
            _buildTabView(context),
            const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)), 
            Expanded(
              child: isMentorView ? _buildMentorView() : _buildMenteeView(),
            ),
          ],
        ),
      ),
    );
  }
}