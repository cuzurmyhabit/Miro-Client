import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';

class ClassIntoPage extends StatefulWidget {
  final String postUid;
  final bool isMentor;
  final String classUid;

  const ClassIntoPage({
    super.key,
    required this.postUid,
    required this.isMentor,
    required this.classUid,
  });

  @override
  State<ClassIntoPage> createState() => _ClassIntoPageState();
}

class _ClassIntoPageState extends State<ClassIntoPage> {
  Map<String, dynamic>? _postData;
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _mySubmittedFiles = []; // 내가 제출한 파일 목록 (멘티 전용)
  List<dynamic> _allMenteeFiles = []; // 멘토가 보는 과제 파일 목록 (멘토 전용)

  static const Color _actionButtonColor = Color(0xFF52B292);

  static const String API_BASE_URL = "http://127.0.0.1:3000";

  @override
  void initState() {
    super.initState();
    _fetchPostDetail();

    if (widget.isMentor) {
      _fetchAllMenteeFiles();
    } else {
      _fetchMySubmittedFiles();
    }
  }

  // 멘티 UID로 이름 조회
  Future<String> _fetchUserName(String userUid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userUid)
          .get();
      return doc.data()?['nickname'] ?? '알 수 없음';
    } catch (e) {
      print("사용자 이름 조회 오류 ($userUid): $e");
      return '오류';
    }
  }

  Future<void> _fetchPostDetail() async {
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('post')
          .doc(widget.classUid)
          .get();

      if (docSnapshot.exists) {
        final doc = docSnapshot.data();
        final List<dynamic> postList =
            doc?['postList'] ?? doc?['postlist'] ?? [];

        final postDetail = postList.firstWhere(
          (item) => item['postUid'] == widget.postUid,
          orElse: () => null,
        );

        if (postDetail != null) {
          setState(() {
            _postData = Map<String, dynamic>.from(postDetail);
            _isLoading = false;
          });
          return;
        }
      }

      setState(() {
        _errorMessage = '게시물 정보를 찾을 수 없습니다.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '오류: $e';
        _isLoading = false;
      });
    }
  }

  // 마감일이 지났는지 확인
  bool _isDeadlinePassed() {
    final postState = _postData?['postState'] ?? 'material';
    if (postState != 'assignment') {
      return false;
    }

    final endDateTimestamp = _postData?['postEndDate'] as Timestamp?;
    if (endDateTimestamp == null) {
      return false;
    }

    final endDate = endDateTimestamp.toDate();

    // 마감일의 자정(다음 날 00:00:00)까지 유효하도록 판단
    final deadline = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
    ).add(const Duration(days: 1));

    return DateTime.now().isAfter(deadline);
  }

  /// 파일 다운로드 (멘토 게시물 첨부 파일)
  void _launchUrl(String fileUrl) async {
    try {
      final segments = fileUrl.split("/");

      final classUid = segments[1];
      final postUid = segments[2];
      final role = segments[3];
      final fileName = segments.last;

      final downloadUrl =
          "$API_BASE_URL/upload/download/$classUid/$postUid/$role/$fileName";

      String originalFileName = fileName.contains('_')
          ? fileName.split('_').sublist(1).join('_')
          : fileName;

      final dir = await getApplicationDocumentsDirectory();
      final savePath = "${dir.path}/$originalFileName";

      final dio = Dio();
      await dio.download(downloadUrl, savePath);
      await OpenFile.open(savePath);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('파일 열기 실패: $e')));
    }
  }

  // 멘토가 멘티 파일을 다운로드
  void _downloadMenteeFile(String fullFileName, String userUid) async {
    try {
      final downloadUrl =
          "$API_BASE_URL/upload/download/${widget.classUid}/${widget.postUid}/Menti/$userUid/$fullFileName";

      String originalFileName = fullFileName.contains('_')
          ? fullFileName.split('_').sublist(1).join('_')
          : fullFileName;

      final dir = await getApplicationDocumentsDirectory();
      final savePath = "${dir.path}/$originalFileName";

      final dio = Dio();
      await dio.download(downloadUrl, savePath);
      await OpenFile.open(savePath);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$originalFileName 다운로드 완료')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('멘티 파일 다운로드 실패: $e')));
    }
  }

  // 파일 업로드 (멘티 제출)
  Future<void> _uploadAssignmentFile() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result == null) return;

      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;
      final userUid = FirebaseAuth.instance.currentUser!.uid;

      final formData = FormData.fromMap({
        "classUid": widget.classUid,
        "postUid": widget.postUid,
        "postState": "assignment",
        "role": "Menti",
        "userUid": userUid,
        "fileUid": const Uuid().v4(),
        "file": await MultipartFile.fromFile(file.path, filename: fileName),
      });

      final dio = Dio();
      final response = await dio.post(
        "$API_BASE_URL/upload/uploadFile",
        data: formData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("업로드 성공")));
        await _fetchMySubmittedFiles();
      } else {
        throw Exception("응답 오류: ${response.statusCode}");
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("업로드 실패: $e")));
    }
  }

  // 내 제출 파일 목록 조회 (멘티 전용)
  Future<void> _fetchMySubmittedFiles() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final userUid = user.uid;
      final dio = Dio();

      final response = await dio.get(
        "$API_BASE_URL/upload/list/${widget.classUid}/${widget.postUid}/$userUid",
      );

      if (response.statusCode == 200) {
        setState(() {
          _mySubmittedFiles = response.data['files'] ?? [];
        });
      }
    } catch (e) {
      print("❌ 파일 목록 조회 오류: $e");
    }
  }

  // 제출 파일 삭제 (멘티 전용)
  Future<void> _deleteSubmittedFile(String fileName) async {
    try {
      final userUid = FirebaseAuth.instance.currentUser!.uid;
      final dio = Dio();

      final response = await dio.delete(
        "$API_BASE_URL/upload/delete/${widget.classUid}/${widget.postUid}/$userUid/$fileName",
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("파일이 삭제되었습니다.")));
        await _fetchMySubmittedFiles();
      } else {
        throw Exception("파일 삭제 응답 오류: ${response.statusCode}");
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("파일 삭제 실패: $e")));
    }
  }

  // 모든 과제 조회 (멘토 전용)
  Future<void> _fetchAllMenteeFiles() async {
    if (!widget.isMentor) return;

    try {
      final dio = Dio();
      final response = await dio.get(
        "$API_BASE_URL/upload/list-all/${widget.classUid}/${widget.postUid}",
      );

      if (response.statusCode == 200) {
        final submissions =
            response.data['submissions'] as Map<String, dynamic>? ?? {};
        List<dynamic> combinedFiles = [];

        for (final entry in submissions.entries) {
          final userUid = entry.key;
          final files = entry.value as List<dynamic>;

          final userName = await _fetchUserName(userUid);

          for (var file in files) {
            final String fullFileName = file['fileName'] ?? '알 수 없는 파일';
            final List<String> parts = fullFileName.split('_');

            final String displayedName = parts.length > 1
                ? parts.sublist(1).join('_')
                : fullFileName;

            combinedFiles.add({
              'fileName': fullFileName,
              'displayedName': displayedName,
              'userUid': userUid,
              'userName': userName,
            });
          }
        }

        setState(() {
          _allMenteeFiles = combinedFiles;
        });
      } else {
        print("⚠️ 실패: HTTP ${response.statusCode}");
      }
    } catch (e) {
      print("❌ 멘티 제출 목록 조회 오류: $e");
    }
  }

  // 멘티 전용: 제출된 파일 목록을 표시
  Widget _buildSubmittedFilesList() {
    if (_mySubmittedFiles.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _mySubmittedFiles.map<Widget>((file) {
          final String fullFileName = file['fileName'] ?? '알 수 없는 파일';
          final List<String> parts = fullFileName.split('_');
          final String displayedName = parts.length > 1
              ? parts.sublist(1).join('_')
              : fullFileName;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                const Icon(Icons.description, size: 20, color: Colors.black87),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    displayedName,
                    style: const TextStyle(fontSize: 15, color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // ⭐️ 삭제 버튼도 마감일 체크 로직을 따르도록 수정 (선택 사항)
                InkWell(
                  onTap: () {
                    if (_isDeadlinePassed()) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("⚠️ 마감일이 지나 삭제할 수 없습니다.")),
                      );
                      return;
                    }
                    _deleteSubmittedFile(fullFileName);
                  },
                  borderRadius: BorderRadius.circular(15),
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(Icons.close, size: 20, color: Colors.redAccent),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // 멘토 전용: 멘티 제출 목록을 표시
  Widget _buildAllMenteeFilesList() {
    if (_allMenteeFiles.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
        child: Text('제출된 과제가 없습니다.'),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._allMenteeFiles.map<Widget>((fileData) {
            final String displayedName = fileData['displayedName']!;
            final String userName = fileData['userName']!;
            final String fullFileName = fileData['fileName']!;
            final String userUid = fileData['userUid']!;

            return GestureDetector(
              onTap: () => _downloadMenteeFile(fullFileName, userUid),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.description,
                      size: 20,
                      color: Colors.black87,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        displayedName,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Color(userName.hashCode).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        userName,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(userName.hashCode).withOpacity(0.8),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // ⭐️ [수정] 개별 액션 버튼 (클릭 시 마감일 검사)
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    const double buttonSize = 60.0;
    const double iconSize = 30.0;

    // ⭐️ [수정] onTap을 처리하는 로직 추가
    void handleTap() {
      if (_isDeadlinePassed()) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("⚠️ 마감일이 지나 제출할 수 없습니다.")));
        return;
      }
      onTap();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: handleTap, // ⭐️ handleTap 사용
          borderRadius: BorderRadius.circular(buttonSize / 2),
          child: Container(
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: iconSize, color: color),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 16, color: Colors.black87),
        ),
      ],
    );
  }

  // 멘티 전용 액션 버튼 모음
  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildActionButton(
          icon: Icons.upload_file,
          label: '업로드',
          color: _actionButtonColor,
          onTap: () async {
            await _uploadAssignmentFile();
          },
        ),
        const SizedBox(width: 40),
        _buildActionButton(
          icon: Icons.camera_alt,
          label: '카메라',
          color: _actionButtonColor,
          onTap: () {
            print('카메라 버튼 클릭');
          },
        ),
      ],
    );
  }

  // ⭐️ [수정] bottomNavigationBar에 들어갈 컨테이너 (버튼 모양 유지)
  Widget _buildBottomActionbar() {
    // ⭐️ 마감일 체크를 여기서 하지 않고 버튼 내부에서 처리하도록 변경
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: SafeArea(
        child: _buildActionButtons(), // ⭐️ 항상 버튼을 표시
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMentor = widget.isMentor;
    final bool isAssignment = _postData?['postState'] == 'assignment';

    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPostContent(),

                  if (isAssignment)
                    if (isMentor)
                      _buildAllMenteeFilesList()
                    else
                      Column(
                        children: [
                          _buildSubmittedFilesList(),
                          const SizedBox(height: 10),
                        ],
                      ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
      // 멘티이고 과제일 때만 하단 버튼 바를 표시
      bottomNavigationBar: isAssignment && !isMentor
          ? _buildBottomActionbar()
          : null,
    );
  }

  // 게시물 내용 표시
  Widget _buildPostContent() {
    final postName = _postData!['postName'] ?? '제목 없음';
    final postDescription = _postData!['postDescription'] ?? '내용 없음';
    final postState = _postData!['postState'] ?? 'material';
    final createdAt = (_postData!['createdAt'] as Timestamp).toDate();
    final formattedCreatedAt = DateFormat('yyyy. MM. dd').format(createdAt);
    final String fileUrl = _postData!['fileUrl'] ?? '';

    String dateInfo = formattedCreatedAt;

    if (postState == 'assignment') {
      final endDate = _postData!['postEndDate'] as Timestamp;
      final difference = endDate.toDate().difference(DateTime.now());
      // ⭐️ D-Day 표시: 마감일이 지났는지 여부를 _isDeadlinePassed()로 판단
      final dDay = _isDeadlinePassed() ? '마감됨' : 'D-${difference.inDays}';
      dateInfo = "$formattedCreatedAt ($dDay)";
    }

    String displayedFileName = '';
    if (fileUrl.isNotEmpty) {
      final String fullFileName = fileUrl.split('/').last;
      final List<String> parts = fullFileName.split('_');
      displayedFileName = parts.length > 1
          ? parts.sublist(1).join('_')
          : fullFileName;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            postName,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Text(
            dateInfo,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          Text(
            postDescription,
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
          const SizedBox(height: 30),
          if (displayedFileName.isNotEmpty)
            _buildAttachmentTile(fileName: displayedFileName, fileUrl: fileUrl)
          else
            const Text('첨부된 파일이 없습니다.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildAttachmentTile({
    required String fileName,
    required String fileUrl,
  }) {
    return GestureDetector(
      onTap: () => _launchUrl(fileUrl),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            const Icon(Icons.description, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(fileName, overflow: TextOverflow.ellipsis)),
            const Icon(Icons.file_download, size: 20),
          ],
        ),
      ),
    );
  }
}
