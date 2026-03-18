// ============================================================
// lib/screens/tabs/message_tab.dart
// ============================================================
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/colors.dart';

class _ChatRoom {
  final String id, name, lastMessage, time;
  final int unreadCount;
  const _ChatRoom({required this.id, required this.name, required this.lastMessage,
    required this.time, required this.unreadCount});
}

class _Message {
  final String id, text, time, userId;
  final bool isMe, isLink;
  const _Message({required this.id, required this.text, required this.time,
    required this.userId, required this.isMe, this.isLink = false});
}

const _rooms = [
  _ChatRoom(id:'1', name:'강남→김포 동승팀',    lastMessage:'출발 10분 전입니다!',          time:'14:20', unreadCount:2),
  _ChatRoom(id:'2', name:'홍대→인천공항 팀',    lastMessage:'카카오페이 링크 보내드렸어요', time:'어제',   unreadCount:0),
  _ChatRoom(id:'3', name:'잠실→강남 3인팀',     lastMessage:'도착했습니다 감사해요 😊',     time:'월요일', unreadCount:0),
];

const _initMessages = [
  _Message(id:'1', isMe:false, userId:'travel_kim', text:'안녕하세요! 강남역 2번 출구에서 14:30 출발 예정입니다.', time:'14:10'),
  _Message(id:'2', isMe:false, userId:'seoul_lee',  text:'네 참여할게요! 카카오페이 링크 부탁드려요.',           time:'14:12'),
  _Message(id:'3', isMe:true,  userId:'나',          text:'카카오페이 링크입니다 😊',                           time:'14:13'),
  _Message(id:'4', isMe:true,  userId:'나',          text:'https://qr.kakaopay.com/sample', time:'14:13', isLink:true),
  _Message(id:'5', isMe:false, userId:'travel_kim', text:'감사합니다! 출발 10분 전에 알림 드릴게요.',           time:'14:15'),
];

// ============================================================
// 채팅 탭 - 목록만 표시
// ============================================================
class MessageTab extends StatelessWidget {
  const MessageTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
              child: const Align(
                alignment: Alignment.centerLeft,
                child: Text('채팅', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.secondary)),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _rooms.length,
                itemBuilder: (_, i) => _buildRoomTile(context, _rooms[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomTile(BuildContext context, _ChatRoom room) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatRoomScreen(room: room),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
        child: Row(
          children: [
            Stack(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: AppColors.bg, shape: BoxShape.circle, border: Border.all(color: AppColors.border)),
                child: const Icon(Icons.person, color: AppColors.gray, size: 28),
              ),
              Positioned(bottom: 0, right: 0,
                  child: Container(width: 12, height: 12,
                      decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2)))),
            ]),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(room.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text(room.time, style: const TextStyle(fontSize: 11, color: AppColors.gray)),
                ]),
                const SizedBox(height: 4),
                Text(room.lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.gray)),
              ],
            )),
            if (room.unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                width: 20, height: 20, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                child: Center(child: Text('${room.unreadCount}',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 채팅방 화면 - 별도 Screen (탭바 없음)
// ============================================================
class ChatRoomScreen extends StatefulWidget {
  final _ChatRoom room;
  const ChatRoomScreen({super.key, required this.room});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  List<_Message> _messages = List.from(_initMessages);
  final TextEditingController _inputCtrl  = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  bool _showAttachPanel = false;
  bool _showSearch = false;
  bool _notificationOn = true;
  String _searchQuery = '';

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayMessages = _searchQuery.isEmpty
        ? _messages
        : _messages.where((m) => m.text.contains(_searchQuery)).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF9F8F6),
      body: SafeArea(
        child: Column(
          children: [
            _buildChatHeader(),
            if (_showSearch) _buildSearchBar(),
            Expanded(
              child: ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                itemCount: displayMessages.length + 1,
                itemBuilder: (_, i) {
                  if (i == 0) return _buildDateDivider('오늘');
                  return _buildMessageBubble(displayMessages[i - 1]);
                },
              ),
            ),
            if (_showAttachPanel) _buildAttachPanel(),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildChatHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: AppColors.secondary, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: AppColors.bg, shape: BoxShape.circle, border: Border.all(color: AppColors.border)),
            child: const Icon(Icons.person, color: AppColors.gray, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.room.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const Text('● 3명 참여 중', style: TextStyle(fontSize: 11, color: AppColors.success)),
            ],
          )),
          IconButton(
            icon: Icon(Icons.search, color: _showSearch ? AppColors.primary : AppColors.secondary),
            onPressed: () => setState(() {
              _showSearch = !_showSearch;
              if (!_showSearch) { _searchCtrl.clear(); _searchQuery = ''; }
            }),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: AppColors.secondary),
            onPressed: _showMoreMenu,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: TextField(
        controller: _searchCtrl,
        autofocus: true,
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: '채팅 내 검색...',
          hintStyle: const TextStyle(color: AppColors.gray, fontSize: 13),
          prefixIcon: const Icon(Icons.search, color: AppColors.gray, size: 18),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(icon: const Icon(Icons.clear, size: 16, color: AppColors.gray),
              onPressed: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); })
              : null,
          filled: true, fillColor: AppColors.bg, isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary)),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildDateDivider(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        const Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.gray)),
        ),
        const Expanded(child: Divider(color: AppColors.border)),
      ]),
    );
  }

  Widget _buildMessageBubble(_Message msg) {
    final isHighlighted = _searchQuery.isNotEmpty && msg.text.contains(_searchQuery);

    if (msg.isMe) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(msg.time, style: const TextStyle(fontSize: 10, color: AppColors.gray)),
            const SizedBox(width: 6),
            _buildBubbleContent(msg, isHighlighted),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: AppColors.bg, shape: BoxShape.circle, border: Border.all(color: AppColors.border)),
            child: const Icon(Icons.person, color: AppColors.gray, size: 20),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('@${msg.userId}',
                  style: const TextStyle(fontSize: 11, color: AppColors.gray, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildBubbleContent(msg, isHighlighted),
                  const SizedBox(width: 6),
                  Text(msg.time, style: const TextStyle(fontSize: 10, color: AppColors.gray)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBubbleContent(_Message msg, bool isHighlighted) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.62),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isHighlighted
              ? const Color(0xFFFFF8CC)
              : (msg.isMe ? AppColors.primary : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(msg.isMe ? 16 : 4),
            bottomRight: Radius.circular(msg.isMe ? 4 : 16),
          ),
          border: msg.isMe ? null : Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
        ),
        child: msg.isLink
            ? GestureDetector(
          onTap: () async {
            final uri = Uri.tryParse(msg.text);
            if (uri != null && await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          child: Text(msg.text,
              style: TextStyle(
                fontSize: 13,
                color: msg.isMe ? Colors.white : AppColors.primary,
                decoration: TextDecoration.underline,
                decorationColor: msg.isMe ? Colors.white : AppColors.primary,
              )),
        )
            : Text(msg.text,
            style: TextStyle(fontSize: 13, color: msg.isMe ? Colors.white : AppColors.secondary, height: 1.4)),
      ),
    );
  }

  Widget _buildAttachPanel() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _attachItem(Icons.photo_library_outlined, '사진',   () => setState(() => _showAttachPanel = false)),
          _attachItem(Icons.camera_alt_outlined,    '카메라', () => setState(() => _showAttachPanel = false)),
          _attachItem(Icons.link,                   '링크',   () { _sendMessage(isLink: true, linkText: 'https://qr.kakaopay.com/sample'); setState(() => _showAttachPanel = false); }),
          _attachItem(Icons.location_on_outlined,   '위치',   () => setState(() => _showAttachPanel = false)),
        ],
      ),
    );
  }

  Widget _attachItem(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: AppColors.secondary, size: 26),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.gray)),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => setState(() => _showAttachPanel = !_showAttachPanel),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _showAttachPanel ? AppColors.primary : AppColors.bg,
                shape: BoxShape.circle,
                border: Border.all(color: _showAttachPanel ? AppColors.primary : AppColors.border),
              ),
              child: Icon(_showAttachPanel ? Icons.close : Icons.add,
                  color: _showAttachPanel ? Colors.white : AppColors.gray, size: 20),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.bg, borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _inputCtrl,
                minLines: 1, maxLines: 4,
                style: const TextStyle(fontSize: 13, color: AppColors.secondary),
                decoration: const InputDecoration(
                  hintText: '메시지 입력...',
                  hintStyle: TextStyle(fontSize: 13, color: AppColors.gray),
                  border: InputBorder.none, isDense: true,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _inputCtrl,
            builder: (_, val, __) => GestureDetector(
              onTap: _sendMessage,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: val.text.isNotEmpty ? AppColors.primary : AppColors.bg,
                  shape: BoxShape.circle,
                  border: Border.all(color: val.text.isNotEmpty ? AppColors.primary : AppColors.border),
                ),
                child: Icon(Icons.arrow_upward,
                    color: val.text.isNotEmpty ? Colors.white : AppColors.gray, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMoreMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
              ListTile(
                leading: Icon(_notificationOn ? Icons.notifications : Icons.notifications_off_outlined, color: AppColors.primary),
                title: const Text('채팅 알림', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                trailing: Switch(
                  value: _notificationOn, activeColor: AppColors.primary,
                  onChanged: (v) { setSheet(() => _notificationOn = v); setState(() => _notificationOn = v); },
                ),
              ),
              const Divider(color: AppColors.border),
              ListTile(
                leading: const Icon(Icons.search, color: AppColors.secondary),
                title: const Text('채팅방 검색', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                onTap: () { Navigator.pop(context); setState(() => _showSearch = true); },
              ),
              ListTile(
                leading: const Icon(Icons.person_add_outlined, color: AppColors.secondary),
                title: const Text('참여자 목록', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(context),
              ),
              const Divider(color: AppColors.border),
              ListTile(
                leading: const Icon(Icons.exit_to_app, color: AppColors.red),
                title: const Text('채팅방 나가기', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.red)),
                onTap: () {
                  Navigator.pop(context); // 바텀시트 닫기
                  Navigator.pop(context); // 채팅방 화면 닫기 (목록으로 복귀)
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _sendMessage({bool isLink = false, String? linkText}) {
    final text = linkText ?? _inputCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages = [..._messages, _Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        isMe: true, userId: '나',
        text: text,
        time: TimeOfDay.now().format(context),
        isLink: isLink,
      )];
    });
    _inputCtrl.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }
}