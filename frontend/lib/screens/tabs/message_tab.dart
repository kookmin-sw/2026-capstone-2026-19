import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/colors.dart';
import 'active_tab.dart';
import '../../service/trip_service.dart';

// ── 채팅방 모델 ──────────────────────────────────
class ChatRoomModel {
  final int id; // 백엔드 trip_id
  final String name;
  final String lastMessage;
  final String time;
  final int unreadCount;
  final String pinnedNotice;

  const ChatRoomModel({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    required this.pinnedNotice,
  });

  factory ChatRoomModel.fromJson(Map<String, dynamic> json) {
    return ChatRoomModel(
      id: json['id'],
      name: json['trip_title'] ?? "새 채팅방",
      lastMessage: json['last_message'] ?? "채팅방이 생성되었습니다.",
      time: _formatDate(json['created_at'] ?? ""),
      unreadCount: json['unread_count'] ?? 0,
      pinnedNotice: json['pinned_notice'] ?? "만날 위치를 공유해주세요",
    );
  }

  static String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return "";
    try {
      final DateTime dt = DateTime.parse(dateStr).toLocal();
      return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (e) { return dateStr; }
  }
}

// ── 메시지 모델 ──────────────────────────────────
class _Message {
  final String id, text, time, userId;
  final bool isMe, isLink, isSettlement;
  final SettlementMessage? settlement;
  final File? imageFile;

  const _Message({
    required this.id, required this.text, required this.time, required this.userId,
    required this.isMe, this.isLink = false, this.isSettlement = false,
    this.settlement, this.imageFile,
  });
}

// ============================================================
// 채팅 탭 — 목록 화면
// ============================================================
class MessageTab extends StatefulWidget {
  const MessageTab({super.key});
  @override
  State<MessageTab> createState() => _MessageTabState();
}

class _MessageTabState extends State<MessageTab> {
  List<ChatRoomModel> _serverRooms = [];
  bool _isLoading = true;

  // 🌟 실제 로그인 환경에서는 이 닉네임을 전역 상태(UserProvider 등)에서 가져와야 합니다.
  // 현재는 TripService의 토큰 흐름에 맞춰 상수로 두거나 생성 시 받아와야 합니다.
  final String _currentUsername = "my_username";

  @override
  void initState() {
    super.initState();
    _fetchChatRooms();
  }

  Future<void> _fetchChatRooms() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final List<dynamic> data = await TripService.getChatRooms(
      token: 'this-is-a-fake-test-token-12345', // 실제 연동시 UserToken 입력
    );

    if (mounted) {
      setState(() {
        _serverRooms = data.map((item) => ChatRoomModel.fromJson(item)).toList();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _fetchChatRooms,
                      child: ListView.builder(
                        itemCount: _serverRooms.length,
                        itemBuilder: (_, i) => _buildRoomTile(context, _serverRooms[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      child: const Align(
        alignment: Alignment.centerLeft,
        child: Text('채팅', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.secondary)),
      ),
    );
  }

  Widget _buildRoomTile(BuildContext context, ChatRoomModel room) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatRoomScreen(
            room: room,
            myNickname: _currentUsername, // 🌟 더미가 아닌 현재 접속 유저 정보 전달
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
        child: Row(
          children: [
            _buildAvatar(room.unreadCount > 0),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(room.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    Text(room.time, style: const TextStyle(fontSize: 11, color: AppColors.gray)),
                  ]),
                  const SizedBox(height: 4),
                  Text(room.lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.gray)),
                ],
              ),
            ),
            if (room.unreadCount > 0) _buildUnreadBadge(room.unreadCount),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(bool hasUnread) {
    return Stack(children: [
      Container(
        width: 48, height: 48,
        decoration: BoxDecoration(color: AppColors.bg, shape: BoxShape.circle, border: Border.all(color: AppColors.border)),
        child: const Icon(Icons.person, color: AppColors.gray, size: 28),
      ),
      if (hasUnread)
        Positioned(bottom: 0, right: 0, child: Container(width: 12, height: 12, decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
    ]);
  }

  Widget _buildUnreadBadge(int count) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      width: 20, height: 20,
      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
      child: Center(child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
    );
  }
}

// ============================================================
// 채팅방 화면 (실시간 웹소켓 연동 버전)
// ============================================================
class ChatRoomScreen extends StatefulWidget {
  final ChatRoomModel room;
  final String myNickname;

  const ChatRoomScreen({super.key, required this.room, required this.myNickname});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  WebSocketChannel? _channel;
  List<_Message> _messages = [];
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final ImagePicker _picker = ImagePicker();
  bool _showAttachPanel = false;

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
  }

  void _connectWebSocket() {
    // 🌟 TripService의 serverUrl을 기반으로 웹소켓 경로 설정
    final wsUrl = Uri.parse('ws://3.35.37.129:8000/ws/chat/${widget.room.id}/');
    _channel = WebSocketChannel.connect(wsUrl);

    _channel!.stream.listen((data) {
      final decoded = jsonDecode(data);
      if (mounted) {
        setState(() {
          _messages.add(_Message(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            userId: decoded['sender'],
            text: decoded['message'],
            time: TimeOfDay.now().format(context),
            isMe: decoded['sender'] == widget.myNickname,
          ));
        });
        _scrollToBottom();
      }
    });
  }

  void _sendMessage() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;

    // 🌟 서버로 메시지 객체 전송
    _channel?.sink.add(jsonEncode({
      'message': text,
      'sender': widget.myNickname,
    }));

    _inputCtrl.clear();
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // --- 기존 UI 빌더 (_buildChatHeader, _buildInputBar 등) 생략 없이 그대로 유지하여 사용하시면 됩니다 ---
  // (코드 중복 방지를 위해 주요 로직 위주로 재구성하였습니다.)

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F8F6),
      appBar: AppBar(title: Text(widget.room.name), backgroundColor: Colors.white, foregroundColor: AppColors.secondary, elevation: 1),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(14),
              itemCount: _messages.length,
              itemBuilder: (_, i) => _buildMessageBubble(_messages[i]),
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_Message msg) {
    return Align(
      alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: msg.isMe ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: msg.isMe ? null : Border.all(color: AppColors.border),
        ),
        child: Text(msg.text, style: TextStyle(color: msg.isMe ? Colors.white : AppColors.secondary)),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.border))),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _inputCtrl,
            decoration: const InputDecoration(hintText: '메시지 입력...', border: InputBorder.none),
            onSubmitted: (_) => _sendMessage(),
          ),
        ),
        IconButton(icon: const Icon(Icons.send, color: AppColors.primary), onPressed: _sendMessage),
      ]),
    );
  }
}