import 'package:flutter/material.dart';

// 초록색 강조 색상 재사용
const Color _kAccentColor = Color(0xFF6DEDC2);

// 채팅방 화면 위젯
class ChatRoomScreen extends StatefulWidget {
  final String chatPartnerNickname;

  const ChatRoomScreen({super.key, required this.chatPartnerNickname});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  // 사용자의 메시지를 저장할 리스트 (더미 데이터)
  final List<String> _messages = [];
  // 메시지 입력 컨트롤러
  final TextEditingController _textController = TextEditingController();

  // 메시지 전송 처리 함수
  void _handleSubmitted(String text) {
    if (text.isEmpty) return; // 빈 메시지는 전송하지 않음

    // 입력 필드 초기화
    _textController.clear();

    // 메시지 리스트에 추가하고 UI 업데이트
    setState(() {
      _messages.insert(0, text); // 최신 메시지가 위로 오도록 0번 인덱스에 추가
    });

    // 메시지를 전송한 후, 키보드가 닫히고 스크롤이 자동으로 이동하도록
    FocusScope.of(context).unfocus();
  }

  // 개별 메시지를 표시하는 위젯
  Widget _buildMessage(String message) {
    return Align(
      // 간단한 예제이므로 모든 메시지를 오른쪽(본인)으로 가정하고 강조색을 적용합니다.
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 14.0),
        decoration: BoxDecoration(
          color: _kAccentColor, // 강조색 사용
          borderRadius: BorderRadius.circular(15.0).copyWith(
            topRight: const Radius.circular(0), // 오른쪽 상단은 각지게
          ),
        ),
        child: Text(
          message,
          style: const TextStyle(color: Colors.black, fontSize: 16),
        ),
      ),
    );
  }

  // 메시지 입력 필드와 전송 버튼
  Widget _buildTextComposer() {
    return Container(
      // 하단 safe area 패딩을 위해 margin 대신 padding 사용
      padding: EdgeInsets.only(
        left: 8.0,
        right: 8.0,
        bottom: MediaQuery.of(context).padding.bottom + 5.0, // 하단 네비게이션바 영역 고려
        top: 5.0,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200, width: 1.0),
        ),
      ),
      child: Row(
        children: <Widget>[
          Flexible(
            child: TextField(
              controller: _textController,
              onSubmitted: _handleSubmitted, // 엔터키로 전송 가능하게
              decoration: const InputDecoration.collapsed(hintText: "메시지 보내기"),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4.0),
            child: IconButton(
              icon: const Icon(Icons.send),
              color: _kAccentColor,
              onPressed: () => _handleSubmitted(_textController.text),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.chatPartnerNickname), // 상대방 닉네임을 타이틀로 사용
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: Colors.black, // 뒤로 가기 버튼 색상
        centerTitle: false, // 좌측 정렬
      ),
      body: Column(
        children: <Widget>[
          // 채팅 메시지 목록 영역
          Flexible(
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              reverse: true, // 목록을 반대로 구성하여 최신 메시지가 하단에 오도록 설정
              itemBuilder: (_, int index) => _buildMessage(_messages[index]),
              itemCount: _messages.length,
            ),
          ),
          // 메시지 입력 영역 (Divider는 _buildTextComposer 내에서 처리)
          _buildTextComposer(),
        ],
      ),
    );
  }
}
