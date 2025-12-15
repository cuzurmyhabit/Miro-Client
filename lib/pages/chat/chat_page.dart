import 'package:flutter/material.dart';

// ChatRoomScreen import. 실제 프로젝트 구조에 맞게 경로를 수정해 주세요.
import './chat_room_page.dart';
// 만약 ChatRoomScreen이 ChatPage와 같은 파일에 정의되어 있다면 이 import는 필요 없습니다.

// 초록색 강조 색상 정의
const Color _kAccentColor = Color(0xFF6DEDC2);

// 더미 데이터: 채팅 목록 아이템
class ChatItem {
  final String nickname;
  final String role;
  final String message;
  final String time;
  final int? unreadCount;

  ChatItem(
    this.nickname,
    this.role,
    this.message,
    this.time, {
    this.unreadCount,
  });
}

// 더미 데이터 리스트
final List<ChatItem> _chatList = [
  ChatItem("빔빔", "멘토", "이건 이렇게 하는 게 맞나요?", "어제"),
  ChatItem("미탈", "멘토", "모르겠어요 ㅠ", "어제"),
  ChatItem("닉네임", "멘토", "지금 보내주세요~", "어제", unreadCount: 1),
];

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // "채팅" 타이틀
            const Padding(
              padding: EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 10.0),
              child: Text(
                "채팅",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ),

            // 탭 선택 부분
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: _TabSelectionRow(),
            ),

            // 채팅 목록
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: _chatList.length,
                itemBuilder: (context, index) {
                  return _ChatListItem(item: _chatList[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 탭 선택 관련 위젯 ---

class _TabSelectionRow extends StatefulWidget {
  const _TabSelectionRow();

  @override
  State<_TabSelectionRow> createState() => _TabSelectionRowState();
}

class _TabSelectionRowState extends State<_TabSelectionRow> {
  int _selectedIndex = 0;
  final List<String> _tabs = ["전체", "멘토", "멘티", "그 외"];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_tabs.length, (index) {
        return Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: _TabButton(
            text: _tabs[index],
            isSelected: _selectedIndex == index,
            onTap: () {
              setState(() {
                _selectedIndex = index;
              });
            },
          ),
        );
      }),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isSelected ? _kAccentColor : Colors.white,
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            color: isSelected ? _kAccentColor : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.grey.shade600,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

// --- 채팅 목록 아이템 위젯 (ChatRoomScreen 연결 포함) ---

class _ChatListItem extends StatelessWidget {
  final ChatItem item;

  const _ChatListItem({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            builder: (context) =>
                ChatRoomScreen(chatPartnerNickname: item.nickname),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 20.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 프로필 이미지 영역 (더미)
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),

            // 닉네임, 역할, 마지막 메시지
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        item.nickname,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // 역할 칩
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6.0,
                          vertical: 2.0,
                        ),
                        decoration: BoxDecoration(
                          color: _kAccentColor.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        child: Text(
                          item.role,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                  ),
                ],
              ),
            ),

            // 시간 및 안 읽은 메시지 수
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  item.time,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                if (item.unreadCount != null && item.unreadCount! > 0) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(4.0),
                    constraints: const BoxConstraints(minWidth: 18),
                    decoration: const BoxDecoration(
                      color: _kAccentColor,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      item.unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
