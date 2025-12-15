import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../classRoom/class_room_page.dart'; // 입장 페이지

class MyClassPage extends StatefulWidget {
  const MyClassPage({super.key});

  @override
  State<MyClassPage> createState() => _MyClassPageState();
}

class _MyClassPageState extends State<MyClassPage> {
  bool isMentorView = false;
  bool _isLoading = false;
  String? _errorMessage;

  List<Map<String, dynamic>> _mentoClass = [];
  List<Map<String, dynamic>> _mentiClass = [];

  @override
  void initState() {
    super.initState();
    _fetchMenteeClass();
  }

  Future<void> _fetchMentoClass() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("로그인이 필요합니다.");

      final response = await http.get(
        Uri.parse('http://localhost:3000/classList/mentoClass'),
        headers: {'x-uid': user.uid, 'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        setState(() {
          _mentoClass = List<Map<String, dynamic>>.from(body['data']);
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

  Future<void> _fetchMenteeClass() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("로그인이 필요합니다.");

      final response = await http.get(
        Uri.parse('http://localhost:3000/classList/mentiClass'),
        headers: {'x-uid': user.uid, 'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        setState(() {
          _mentiClass = List<Map<String, dynamic>>.from(body['data']);
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

  Future<void> _startClass(String classUid) async {
    try {
      final response = await http.post(
        Uri.parse('http://localhost:3000/classList/start'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'classUid': classUid}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // 이런 바보같은 나..... 담부터 꼭 200 || 201로 쓰자..
        final body = jsonDecode(response.body);
        setState(() {
          _mentoClass = _mentoClass.map((cls) {
            if (cls['classUid'] == classUid) {
              return {...cls, 'status': 'Running'};
            }
            return cls;
          }).toList();
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

  Widget _buildMentorView() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) return Center(child: Text(_errorMessage!));
    if (_mentoClass.isEmpty)
      return const Center(child: Text("운영 중인 수업이 없습니다."));

    return ListView.builder(
      itemCount: _mentoClass.length,
      itemBuilder: (context, index) {
        final cls = _mentoClass[index];
        final String status = cls['status'] ?? 'Unknown';
        final int capacity = cls['capacity'] ?? 0;
        final int currentMentiCount =
            (cls['mentiUidArray'] as List?)?.length ?? 0;
        final String classUid = cls['classUid'] ?? 'unknown_id';

        String buttonText = '';
        Color buttonColor = Colors.grey;
        VoidCallback? onPressed;

        if (status == 'Waiting') {
          if (currentMentiCount < capacity) {
            buttonText = '대기중';
            buttonColor = Colors.grey;
            onPressed = null;
          } else {
            buttonText = '시작하기';
            buttonColor = Colors.blue;
            onPressed = () => _startClass(classUid);
          }
        } else if (status == 'Running') {
          final user = FirebaseAuth.instance.currentUser;
          buttonText = '입장하기';
          buttonColor = Colors.green;
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
        }

        return ListTile(
          leading:
              cls['coverImg'] != null &&
                  cls['coverImg'].isNotEmpty &&
                  cls['coverImg'][0]['url'] != null
              ? SizedBox(
                  width: 80,
                  height: 80,
                  child: Image.asset(
                    "assets/coverImg/cover.png",
                    fit: BoxFit.cover,
                  ),
                )
              : Container(
                  width: 60,
                  height: 60,
                  color: Colors.grey[300],
                  child: const Icon(Icons.image_not_supported),
                ),
          title: Text(cls['className'] ?? '이름 없음'),
          subtitle: Text(
            "상태: $status\n분야: ${cls['field'] ?? '-'}\n현재 인원: $currentMentiCount/$capacity",
          ),
          trailing: SizedBox(
            width: 90,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                elevation: 0,
                shadowColor: Colors.transparent,
              ),
              child: Text(buttonText),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenteeView() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) return Center(child: Text(_errorMessage!));
    if (_mentiClass.isEmpty)
      return const Center(child: Text("수강 중인 수업이 없습니다."));

    return ListView.builder(
      itemCount: _mentiClass.length,
      itemBuilder: (context, index) {
        final cls = _mentiClass[index];
        return ListTile(
          leading:
              cls['coverImg'] != null &&
                  cls['coverImg'].isNotEmpty &&
                  cls['coverImg'][0]['url'] != null
              ? SizedBox(
                  width: 80,
                  height: 80,
                  child: Image.asset(
                    "assets/coverImg/cover.png",
                    fit: BoxFit.cover,
                  ),
                )
              : Container(
                  width: 60,
                  height: 60,
                  color: Colors.grey[300],
                  child: const Icon(Icons.image_not_supported),
                ),
          title: Text(cls['className'] ?? '이름 없음'),
          subtitle: Text(
            "상태: ${cls['status'] ?? 'Unknown'}\n분야: ${cls['field'] ?? '-'}",
          ),
          trailing: cls['status'] == 'Running'
              ? SizedBox(
                  width: 90,
                  child: ElevatedButton(
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
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      elevation: 0,
                      shadowColor: Colors.transparent,
                    ),
                    child: const Text('입장하기'),
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _buildTabView(BuildContext context) {
    const TextStyle defaultTextStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
    );

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey, width: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () {
                  if (!isMentorView) return;
                  setState(() => isMentorView = false);
                  _fetchMenteeClass();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: !isMentorView
                            ? Colors.green
                            : Colors.transparent,
                        width: 2.0,
                      ),
                    ),
                  ),
                  child: Text(
                    "멘티 보기",
                    textAlign: TextAlign.center,
                    style: defaultTextStyle.copyWith(
                      color: !isMentorView ? Colors.green : Colors.black,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: () {
                  if (isMentorView) return;
                  setState(() => isMentorView = true);
                  _fetchMentoClass();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isMentorView ? Colors.green : Colors.transparent,
                        width: 2.0,
                      ),
                    ),
                  ),
                  child: Text(
                    "멘토 보기",
                    textAlign: TextAlign.center,
                    style: defaultTextStyle.copyWith(
                      color: isMentorView ? Colors.green : Colors.black,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildTabView(context),
            Expanded(
              child: isMentorView ? _buildMentorView() : _buildMenteeView(),
            ),
          ],
        ),
      ),
    );
  }
}
