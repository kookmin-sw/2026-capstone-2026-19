// ============================================================
// 📁 lib/screens/tabs/message_tab.dart
// ============================================================
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/colors.dart';
import 'active_tab.dart'; // settlementMessageNotifier, SettlementMessage

// ── 채팅방 모델 ──────────────────────────────────────────────
class _ChatRoom {
  final String id, name, lastMessage, time;
  final int unreadCount;
  const _ChatRoom({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
  });
}

// ── 메시지 모델 ──────────────────────────────────────────────
class _Message {
  final String id, text, time, userId;
  final bool isMe, isLink, isSettlement;
  final SettlementMessage? settlement;
  final File? imageFile;

  const _Message({
    required this.id,
    required this.text,
    required this.time,
    required this.userId,
    required this.isMe,
    this.isLink = false,
    this.isSettlement = false,
    this.settlement,
    this.imageFile,
  });
}

const _rooms = [
  _ChatRoom(id: '1', name: '강남→김포 동승팀',  lastMessage: '출발 10분 전입니다!',          time: '14:20', unreadCount: 2),
  _ChatRoom(id: '2', name: '홍대→인천공항 팀',  lastMessage: '카카오페이 링크 보내드렸어요', time: '어제',   unreadCount: 0),
  _ChatRoom(id: '3', name: '잠실→강남 3인팀',   lastMessage: '도착했습니다 감사해요 😊',     time: '월요일', unreadCount: 0),
];

const _initMessages = [
  _Message(id: '1', isMe: false, userId: 'travel_kim',
      text: '안녕하세요! 강남역 2번 출구에서 14:30 출발 예정입니다.', time: '14:10'),
  _Message(id: '2', isMe: false, userId: 'seoul_lee',
      text: '네 참여할게요! 카카오페이 링크 부탁드려요.', time: '14:12'),
  _Message(id: '3', isMe: true, userId: '나',
      text: '카카오페이 링크입니다 😊', time: '14:13'),
  _Message(id: '4', isMe: true, userId: '나',
      text: 'https://qr.kakaopay.com/sample', time: '14:13', isLink: true),
  _Message(id: '5', isMe: false, userId: 'travel_kim',
      text: '감사합니다! 출발 10분 전에 알림 드릴게요.', time: '14:15'),
];

// ============================================================
// 채팅 탭 — 목록
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
                child: Text('채팅',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.secondary)),
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
        MaterialPageRoute(builder: (_) => ChatRoomScreen(room: room)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border))),
        child: Row(
          children: [
            Stack(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                    color: AppColors.bg,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border)),
                child: const Icon(Icons.person, color: AppColors.gray, size: 28),
              ),
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2)),
                ),
              ),
            ]),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(room.name,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text(room.time,
                        style:
                        const TextStyle(fontSize: 11, color: AppColors.gray)),
                  ]),
                  const SizedBox(height: 4),
                  Text(room.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.gray)),
                ],
              ),
            ),
            if (room.unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                width: 20, height: 20,
                decoration: const BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle),
                child: Center(
                  child: Text('${room.unreadCount}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 채팅방 화면
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
  final ImagePicker _picker = ImagePicker();

  bool _showAttachPanel = false;
  bool _showSearch = false;
  bool _notificationOn = true;
  bool _noticeExpanded = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // 정산 요청 메시지 수신
    settlementMessageNotifier.addListener(_onSettlementMessage);
  }

  @override
  void dispose() {
    settlementMessageNotifier.removeListener(_onSettlementMessage);
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSettlementMessage() {
    final msg = settlementMessageNotifier.value;
    if (msg == null) return;
    setState(() {
      _messages = [
        ..._messages,
        _Message(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          isMe: true,
          userId: msg.hostId,
          text: '정산 요청',
          time: TimeOfDay.now().format(context),
          isSettlement: true,
          settlement: msg,
        ),
      ];
    });
    _scrollToBottom();
  }

  // 이미지 선택 메서드
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (picked != null) {
        setState(() {
          _messages = [
            ..._messages,
            _Message(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              isMe: true,
              userId: '나',
              text: '사진',
              time: TimeOfDay.now().format(context),
              imageFile: File(picked.path),
            ),
          ];
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('사진을 불러올 수 없습니다. 권한을 확인해 주세요.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
            _buildNoticeBar(),
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
            decoration: BoxDecoration(
                color: AppColors.bg,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border)),
            child: const Icon(Icons.person, color: AppColors.gray, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.room.name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                const Text('● 3명 참여 중',
                    style:
                    TextStyle(fontSize: 11, color: AppColors.success)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.search,
                color: _showSearch ? AppColors.primary : AppColors.secondary),
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
              ? IconButton(
              icon: const Icon(Icons.clear, size: 16, color: AppColors.gray),
              onPressed: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); })
              : null,
          filled: true, fillColor: AppColors.bg, isDense: true,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary)),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildNoticeBar() {
    const noticeText = '택시 번호 및 만날 위치를 꼭 공유해주세요';
    return GestureDetector(
      onTap: () => setState(() => _noticeExpanded = !_noticeExpanded),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: AppColors.primaryLight,
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 22, height: 22,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: const BoxDecoration(
                      color: AppColors.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.push_pin_rounded,
                      size: 13, color: Colors.white),
                ),
                const Text('공지',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        letterSpacing: 0.4)),
                const Spacer(),
                AnimatedRotation(
                  duration: const Duration(milliseconds: 200),
                  turns: _noticeExpanded ? 0.5 : 0.0,
                  child: const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 18, color: AppColors.primary),
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: _noticeExpanded
                  ? Padding(
                padding: const EdgeInsets.only(top: 8, left: 30),
                child: Text(noticeText,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w500,
                        height: 1.5)),
              )
                  : const SizedBox.shrink(),
            ),
          ],
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
          child: Text(label,
              style: const TextStyle(fontSize: 11, color: AppColors.gray)),
        ),
        const Expanded(child: Divider(color: AppColors.border)),
      ]),
    );
  }

  Widget _buildMessageBubble(_Message msg) {
    final isHighlighted = _searchQuery.isNotEmpty && msg.text.contains(_searchQuery);

    // 정산 요청 카드 (항상 내 메시지 형태 — 대표자가 보낸 것)
    if (msg.isSettlement && msg.settlement != null) {
      return _buildSettlementBubble(msg, msg.settlement!);
    }

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
            decoration: BoxDecoration(
                color: AppColors.bg,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border)),
            child: const Icon(Icons.person, color: AppColors.gray, size: 20),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('@${msg.userId}',
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.gray,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildBubbleContent(msg, isHighlighted),
                  const SizedBox(width: 6),
                  Text(msg.time,
                      style: const TextStyle(fontSize: 10, color: AppColors.gray)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 정산 요청 카드 버블 ──────────────────────────────────
  Widget _buildSettlementBubble(_Message msg, SettlementMessage s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(msg.time,
              style: const TextStyle(fontSize: 10, color: AppColors.gray)),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 헤더
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(15)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.receipt_long,
                              color: AppColors.primary, size: 16),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('정산 요청',
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text('${s.memberCount}명',
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),

                  // 금액 정보
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 총 요금
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('총 택시 요금',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.gray)),
                            Text(
                              '${_formatNum(s.totalFare)}원',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Divider(color: AppColors.border, height: 1),
                        const SizedBox(height: 10),
                        // 1인당 정산 금액
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('1인당 정산 금액',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.secondary,
                                    fontWeight: FontWeight.w700)),
                            Text(
                              '${_formatNum(s.perPerson)}원',
                              style: const TextStyle(
                                  fontSize: 18,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // 정산하기 버튼
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.primary,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide.none
                              ),
                            ),
                            onPressed: () async {
                              final link = s.kakaoPayLink;
                              if (link != null) {
                                final uri = Uri.tryParse(link);
                                if (uri != null && await canLaunchUrl(uri)) {
                                  await launchUrl(uri,
                                      mode: LaunchMode.externalApplication);
                                }
                              }
                            },
                            child: const Text('정산하기',
                                style: TextStyle(
                                    color: AppColors.primaryLight,
                                    fontSize: 13, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatNum(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i != 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  Widget _buildBubbleContent(_Message msg, bool isHighlighted) {
    // 이미지 메시지 처리
    if (msg.imageFile != null) {
      return ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.62,
            maxHeight: 250),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(msg.isMe ? 16 : 4),
              bottomRight: Radius.circular(msg.isMe ? 4 : 16),
            ),
            border: msg.isMe ? null : Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(msg.isMe ? 16 : 4),
              bottomRight: Radius.circular(msg.isMe ? 4 : 16),
            ),
            child: Image.file(
              msg.imageFile!,
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.62),
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
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)
          ],
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
                decorationColor:
                msg.isMe ? Colors.white : AppColors.primary,
              )),
        )
            : Text(msg.text,
            style: TextStyle(
                fontSize: 13,
                color:
                msg.isMe ? Colors.white : AppColors.secondary,
                height: 1.4)),
      ),
    );
  }

  Widget _buildAttachPanel() {
    final isHost = globalActiveRideState.activeRide.isMyRide;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // _pickImage 연결
          _attachItem(Icons.photo_library_outlined, '사진',
                  () {
                setState(() => _showAttachPanel = false);
                _pickImage(ImageSource.gallery);
              }),
          _attachItem(Icons.camera_alt_outlined, '카메라',
                  () {
                setState(() => _showAttachPanel = false);
                _pickImage(ImageSource.camera);
              }),
          _attachItemWithState(
            icon: Icons.receipt_long_outlined,
            label: '정산 요청',
            enabled: isHost,
            onTap: isHost
                ? () {
              setState(() => _showAttachPanel = false);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReceiptShareScreen(
                    activeRide: globalActiveRideState.activeRide,
                    onSent: () => globalActiveRideState
                        .setPhase(RidePhase.receiptShared),
                  ),
                ),
              );
            }
                : null,
          ),
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
            decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: AppColors.primary, size: 26),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.gray)),
        ],
      ),
    );
  }

  /// 활성/비활성 상태가 있는 첨부 아이템
  Widget _attachItemWithState({
    required IconData icon,
    required String label,
    required bool enabled,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Column(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: enabled ? AppColors.primaryLight : AppColors.bg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: enabled ? AppColors.primary : AppColors.gray,
              size: 26,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.gray,
            ),
          ),
          if (!enabled)
            const Text(
              '대표자 전용',
              style: TextStyle(fontSize: 9, color: AppColors.gray),
            ),
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
                border: Border.all(
                    color: _showAttachPanel ? AppColors.primary : AppColors.border),
              ),
              child: Icon(
                _showAttachPanel ? Icons.close : Icons.add,
                color: _showAttachPanel ? Colors.white : AppColors.gray,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.border)),
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
                  border: Border.all(
                      color: val.text.isNotEmpty
                          ? AppColors.primary
                          : AppColors.border),
                ),
                child: Icon(Icons.arrow_upward,
                    color:
                    val.text.isNotEmpty ? Colors.white : AppColors.gray,
                    size: 18),
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
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2))),
              ListTile(
                leading: Icon(
                    _notificationOn
                        ? Icons.notifications
                        : Icons.notifications_off_outlined,
                    color: AppColors.primary),
                title: const Text('채팅 알림',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                trailing: Switch(
                  value: _notificationOn,
                  activeColor: AppColors.primary,
                  onChanged: (v) {
                    setSheet(() => _notificationOn = v);
                    setState(() => _notificationOn = v);
                  },
                ),
              ),
              const Divider(color: AppColors.border),
              ListTile(
                leading: const Icon(Icons.search, color: AppColors.secondary),
                title: const Text('채팅방 검색',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _showSearch = true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_add_outlined,
                    color: AppColors.secondary),
                title: const Text('참여자 목록',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(context),
              ),
              const Divider(color: AppColors.border),
              ListTile(
                leading: const Icon(Icons.exit_to_app, color: AppColors.red),
                title: const Text('채팅방 나가기',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.red)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
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
      _messages = [
        ..._messages,
        _Message(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          isMe: true, userId: '나',
          text: text,
          time: TimeOfDay.now().format(context),
          isLink: isLink,
        ),
      ];
    });
    _inputCtrl.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
}