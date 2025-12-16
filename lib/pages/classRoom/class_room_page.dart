import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../createPost/create_post_page.dart';
import '../classInto/class_into_page.dart';
import '../classRoom/postUpdate/post_update_page.dart';

// 💡 디자인 시스템 (기존 코드의 색상 기반)
const Color kHighlightColor = Color(0xFF6DEDC2); // 기존 작성하기 버튼 색상
const Color kTabSelectedColor = Color(0xFF6DEDC2); // 탭 선택 시 강조 색상
const Color kTextColor = Colors.black87;
const Color kHintColor = Colors.grey;
// 💡 추가된 디자인: 모달 배경색
const Color kModalBackgroundColor = Color(0xFFFFFFFF); // 요청된 배경색

class ClassRoomPage extends StatefulWidget {
  final String classUid;
  final String userUid;
  final String creatorUid;

  const ClassRoomPage({
    super.key,
    required this.classUid,
    required this.userUid,
    required this.creatorUid,
  });

  @override
  State<ClassRoomPage> createState() => _ClassRoomPageState();
}

class _ClassRoomPageState extends State<ClassRoomPage> {
  
  String _creatorNickname = '';
  String _className = '';
  
  // 💡 클래스 상세 정보 상태 추가
  String _classDescription = '';
  List<Map<String, String>> _classDetails = [];
  bool _isInfoExpanded = false; // 드롭다운 상태

  bool _isLoading = true;
  String _selectedTab = '전체';

  List<Map<String, dynamic>> _posts = [];
  
  bool get _isMentor => widget.userUid == widget.creatorUid; // 멘토 여부

  List<Map<String, dynamic>> get _filteredPosts {
    if (_selectedTab == '전체') {
      return _posts;
    }

    // 탭 이름('과제', '자료')을 서버의 postState 값('assignment', 'material')으로 변환
    final targetState = _selectedTab == '과제' ? 'assignment' : 'material';

    return _posts.where((post) => post['state'] == targetState).toList();
  }

  //  서버 기본 URL (필요 시 수정)
  static const String baseUrl = 'http://localhost:3000';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // 🔹 Firestore + Post API 데이터 동시 불러오기 (클래스 상세 정보 로딩 추가)
  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      // 1. creatorUid → 닉네임
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.creatorUid)
          .get();
      final nickname = userDoc.data()?['nickname'] ?? 'Unknown';

      // 2. classUid → 클래스 이름 및 상세 정보 로드
      final classDoc = await FirebaseFirestore.instance
          .collection('classList')
          .doc(widget.classUid)
          .get();
      final classData = classDoc.data();
      final className = classData?['className'] ?? '이름 없음';
      
      // 💡 클래스 상세 정보 추출 (필드 이름은 임의로 가정, DB 구조에 맞춰 수정 필요)
      _classDescription = classData?['classDescription'] ?? '클래스에 대한 상세 설명이 없습니다.';
      _classDetails = [
        {'label': '분야', 'value': classData?['category'] ?? '미정'},
        {'label': '인원', 'value': (classData?['maxMembers']?.toString() ?? 'N/A') + '명'},
        {'label': '기간', 'value': '${classData?['startDate'] ?? 'N/A'} ~ ${classData?['endDate'] ?? 'N/A'} (가정)'},
        {'label': '조건', 'value': classData?['requirements'] ?? '없음'},
        {'label': '주의', 'value': classData?['notice'] ?? '없음'}, // 주의사항 추가
      ];

      // 3. 서버에서 해당 클래스의 자료 목록 불러오기
      final url = Uri.parse(
        '$baseUrl/post/list?rootClassUid=${widget.classUid}',
      );
      final response = await http.get(url);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        final List posts = data['posts'] ?? [];

        _posts = posts.map((item) {
          final state = item['postState'] ?? 'unknown'; // material / assignment

          return {
            'state': state,
            'title': item['postName'] ?? '제목 없음',
            'postUid': item['postUid'],
          };
        }).toList();
      } else {
        print('자료 목록 불러오기 실패: ${response.statusCode}');
      }

      setState(() {
        _creatorNickname = nickname;
        _className = className;
        _isLoading = false;
      });
    } catch (e) {
      print('데이터 불러오기 오류: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deletePost(String postUid) async {
    final String deletePostUrl = '$baseUrl/post/${widget.classUid}/$postUid';
    final String deleteFilesUrl =
        '$baseUrl/upload/delete-post/${widget.classUid}/$postUid';

    try {
      // 1) DB에서 게시글 삭제
      final postRes = await http.delete(Uri.parse(deletePostUrl));

      if (postRes.statusCode == 200 || postRes.statusCode == 204) {
        print('DB 삭제 완료: $postUid');
      } else {
        print('DB 삭제 실패: ${postRes.statusCode} ${postRes.body}');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('DB 삭제 실패: ${postRes.statusCode}')),
        );
        return;
      }

      // 2) 파일 디렉토리 삭제
      final fileRes = await http.delete(Uri.parse(deleteFilesUrl));

      if (fileRes.statusCode == 200 || fileRes.statusCode == 204) {
        print('파일 삭제 완료: $postUid');
      } else {
        print('파일 삭제 실패: ${fileRes.statusCode} ${fileRes.body}');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('파일 일부 삭제 실패: ${fileRes.statusCode}')),
        );
      }

      if (mounted) ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('삭제되었습니다.')));

      _fetchData(); // 목록 갱신
    } catch (e) {
      print('삭제 요청 오류: $e');
      if (mounted) ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('삭제 중 오류 발생')));
    }
  }
  
  // 💡 [UX 개선] 삭제 확인 모달 함수 (디자인 변경됨)
  Future<void> _showDeleteConfirmationDialog(String postUid) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          // 💡 요청된 모달 배경색 적용
          backgroundColor: kModalBackgroundColor,
          surfaceTintColor: kModalBackgroundColor, // Light Theme에서 배경색이 이상해지는 것을 방지
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          // 💡 요청된 모달 크기(W 329, H 165)를 맞추기 위해 Stack과 SizedBox 사용
          content: SizedBox(
            width: 329, // 요청된 폭
            height: 125, // 요청된 높이(165)에서 title/actions 패딩을 제외한 적절한 값
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 💡 제목 폰트 크기 18pt 적용
                const Text(
                  '정말 삭제하시겠습니까?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextColor),
                ),
                const SizedBox(height: 10),
                // 💡 본문 폰트 크기 12pt 적용
                const Text(
                  '사라진 게시물은 다시 되돌릴 수 없어요',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: kHintColor),
                ),
                const SizedBox(height: 20),
                // 버튼 영역
                Row(
                  children: <Widget>[
                    // 취소 버튼 (왼쪽, 회색 배경)
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          minimumSize: Size.zero, // 최소 크기 제약 해제
                        ),
                        child: const Text(
                          '취소',
                          // 💡 폰트 크기 12pt 적용
                          style: TextStyle(color: kTextColor, fontSize: 12),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop(); // 모달 닫기
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    // 삭제 버튼 (오른쪽, 요청된 6DEDC2 배경색 적용)
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          // 💡 요청된 버튼 배경색 적용
                          backgroundColor: kHighlightColor, 
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          minimumSize: Size.zero, // 최소 크기 제약 해제
                        ),
                        child: const Text(
                          '삭제',
                          // 💡 폰트 크기 12pt 적용
                          style: TextStyle(color: kTextColor, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop(); // 모달 닫기
                          _deletePost(postUid); // 삭제 로직 실행
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // AlertDialog의 title/actions 필드를 사용하지 않고 content 필드에 모든 요소를 배치하여
          // 크기와 내부 간격을 세밀하게 제어합니다.
          titlePadding: EdgeInsets.zero,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        );
      },
    );
  }

  // 수정 페이지로 이동
  void _editPost(String postUid) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PostUpdatePage(classUid: widget.classUid, postUid: postUid),
      ),
    ).then((updated) {
      if (updated == true) {
        _fetchData(); // 수정 후 목록 갱신
      }
    });
  }

  // 화면 렌더링
  @override
  Widget build(BuildContext context) {
    //  필터링된 목록 사용
    final postsToShow = _filteredPosts;

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildClassInfo(), // 💡 이 부분에 드롭다운 로직 추가
                        const SizedBox(height: 15),
                        _buildTopButtons(context),
                        const SizedBox(height: 20),

                        // 실제 자료 목록 (필터링된 목록 사용)
                        if (postsToShow.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(30),
                              child: Text(
                                '$_selectedTab에 등록된 자료가 없습니다.',
                              ), // 텍스트 수정
                            ),
                          )
                        else
                          ListView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            itemCount: postsToShow.length,
                            itemBuilder: (context, index) {
                              final item = postsToShow[index];
                              return _buildListItem(
                                context,
                                item['state']!,
                                item['title']!,
                                item['postUid']!,
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  //  상단 커버 이미지 (기존 로직 유지)
  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 150,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: const Color.fromARGB(255, 141, 108, 108)),
          Image.asset('assets/coverImg/cover.png', fit: BoxFit.cover),
          Positioned(
            left: 0,
            top: 0,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  // 💡 개선: 클래스 이름 + 멘토 정보 + 드롭다운 토글 및 내용 표시
  Widget _buildClassInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _className,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          
          // 멘토 정보 및 더보기 토글 버튼
          Row(
            children: [
              Container(
                width: 15,
                height: 15,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _creatorNickname,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const Spacer(),
              // 💡 '더보기' 토글 버튼
              GestureDetector(
                onTap: () {
                  setState(() => _isInfoExpanded = !_isInfoExpanded);
                },
                child: Row(
                  children: [
                    Text(
                      _isInfoExpanded ? '숨기기' : '더보기',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    Icon(
                      _isInfoExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 14,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // 💡 클래스 정보 드롭다운 영역
          AnimatedCrossFade(
            firstChild: Container(), // 숨김 상태
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 15.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. 상세 설명
                  Text(
                    _classDescription,
                    style: TextStyle(fontSize: 14, height: 1.5, color: Colors.black.withOpacity(0.8)),
                  ),
                  const SizedBox(height: 15),
                  // 2. 상세 정보 리스트
                  ..._classDetails.map((detail) => _buildDetailRow(detail['label']!, detail['value']!)),
                ],
              ),
            ),
            crossFadeState: _isInfoExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  // 💡 상세 정보 행 빌더
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 50,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(value, style: const TextStyle(color: kTextColor)),
          ),
        ],
      ),
    );
  }

  //  작성하기 버튼 + 탭 버튼 (기존 로직 유지)
  Widget _buildTopButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        children: [
          if (widget.userUid == widget.creatorUid)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        CreatePostPage(classUid: widget.classUid),
                  ),
                ).then((_) => _fetchData()); // 새 자료 작성 후 새로고침
              },
              icon: const Icon(Icons.edit, size: 18, color: Colors.black87),
              label: const Text(
                '작성하기',
                style: TextStyle(color: Colors.black87),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kHighlightColor, // 0xFFC3F3D8
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          const Spacer(),
          //  탭 상태를 반영하도록 수정
          _buildTabButton('전체', isSelected: _selectedTab == '전체'),
          const SizedBox(width: 8),
          _buildTabButton('과제', isSelected: _selectedTab == '과제'),
          const SizedBox(width: 8),
          _buildTabButton('자료', isSelected: _selectedTab == '자료'),
        ],
      ),
    );
  }

  // 탭 버튼 (기존 로직 유지)
  Widget _buildTabButton(String text, {bool isSelected = false}) {
    return GestureDetector(
      onTap: () {
        // 탭 클릭 시 상태 업데이트 및 화면 갱신
        setState(() {
          _selectedTab = text;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? kTabSelectedColor : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // 목록 아이템 (수정됨: 삭제 버튼 클릭 시 모달 호출)
  Widget _buildListItem(
    BuildContext context,
    String state, // postState 값: 'assignment' 또는 'material'
    String title,
    String postUid,
  ) {
    // state 값에 따른 아이콘 결정
    IconData icon = state == 'assignment'
        ? Icons.edit_note // 과제 (연필/노트)
        : state == 'material'
        ? Icons.description // 자료 (문서)
        : Icons.circle; // 기타

    // 현재 사용자가 클래스 생성자인지 확인
    final bool isCreator = widget.userUid == widget.creatorUid;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 1.0),
        ),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.grey),
        title: Text(title, style: const TextStyle(color: Colors.black87)),
        trailing:
            isCreator // ⭐️ 클래스 생성자에게만 메뉴 버튼을 표시
            ? PopupMenuButton<String>(
                color: Colors.white,
                onSelected: (String result) {
                  if (result == 'edit') {
                    _editPost(postUid);
                  } else if (result == 'delete') {
                    // 💡 UX 개선: 삭제 버튼 클릭 시 확인 모달 호출
                    _showDeleteConfirmationDialog(postUid);
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(value: 'edit', child: Text('수정')),
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Text('삭제'),
                  ),
                ],
                icon: const Icon(Icons.more_vert, color: Colors.grey),
              )
            : null, // 생성자가 아니면 버튼 없음
        onTap: () {
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
              builder: (context) => ClassIntoPage(
                postUid: postUid,
                isMentor: widget.userUid == widget.creatorUid,
                classUid: widget.classUid,
              ),
            ),
          ).then((_) => _fetchData()); // 상세 페이지에서 돌아왔을 때 목록 갱신
        },
      ),
    );
  }
}