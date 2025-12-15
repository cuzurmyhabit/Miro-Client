import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../createPost/create_post_page.dart';
import '../classInto/class_into_page.dart';
import '../classRoom/postUpdate/post_update_page.dart';

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
  bool _isLoading = true;
  String _selectedTab = '전체';

  List<Map<String, dynamic>> _posts = [];

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

  // 🔹 Firestore + Post API 데이터 동시 불러오기
  Future<void> _fetchData() async {
    try {
      // 1. creatorUid → 닉네임
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.creatorUid)
          .get();
      final nickname = userDoc.data()?['nickname'] ?? 'Unknown';

      // 2. classUid → 클래스 이름
      final classDoc = await FirebaseFirestore.instance
          .collection('classList')
          .doc(widget.classUid)
          .get();
      final className = classDoc.data()?['className'] ?? '이름 없음';

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
        ScaffoldMessenger.of(context).showSnackBar(
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('파일 일부 삭제 실패: ${fileRes.statusCode}')),
        );
        // 파일 삭제 실패해도 DB는 이미 지워졌으므로 계속 진행
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('삭제되었습니다.')));

      _fetchData(); // 목록 갱신
    } catch (e) {
      print('삭제 요청 오류: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('삭제 중 오류 발생')));
    }
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
                        _buildClassInfo(),
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

  //  상단 커버 이미지 (생략)
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

  //  클래스 이름 + 멘토 정보 (생략)
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
              const Text(
                '더보기',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            ],
          ),
        ],
      ),
    );
  }

  //  작성하기 버튼 + 탭 버튼
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
                backgroundColor: const Color(0xFFC3F3D8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
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

  // 탭 버튼
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
          color: isSelected ? const Color(0xFFC3F3D8) : Colors.grey[200],
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

  // 목록 아이템 (아이콘 결정 로직 및 onTap 수정)
  Widget _buildListItem(
    BuildContext context,
    String state, // postState 값: 'assignment' 또는 'material'
    String title,
    String postUid,
  ) {
    // state 값에 따른 아이콘 결정
    IconData icon = state == 'assignment'
        ? Icons
              .edit_note // 과제 (연필/노트)
        : state == 'material'
        ? Icons
              .description // 자료 (문서)
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
                    _deletePost(postUid);
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
          );
        },
      ),
    );
  }
}
