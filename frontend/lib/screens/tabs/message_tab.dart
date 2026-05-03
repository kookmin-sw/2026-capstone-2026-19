import '../../service/auth_session.dart';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import '../../utils/colors.dart';
//import 'active_tab.dart';
import '../../service/trip_service.dart';
import '../../service/settlement_service.dart';
import '../../config/app_config.dart';

// ── 채팅방 모델 ──────────────────────────────────
class ChatRoomModel {
  final int id; // chat_room_id
  final int tripId; // 실제 trip_id
  final String name;
  final String lastMessage;
  final String time;
  final int unreadCount;
  final String pinnedNotice;

  const ChatRoomModel({
    required this.id,
    required this.tripId,
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    required this.pinnedNotice,
  });

  factory ChatRoomModel.fromJson(Map<String, dynamic> json) {
    return ChatRoomModel(
      id: json['id'],
      tripId: json['trip_id'],
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
    } catch (e) {
      return dateStr;
    }
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

class SettlementMessage {
  final int settlementId;
  final int totalAmount;
  final int shareAmount;
  final String? receiptImageUrl;
  final String? paymentLink;
  final String status;

  const SettlementMessage({
    required this.settlementId,
    required this.totalAmount,
    required this.shareAmount,
    this.receiptImageUrl,
    this.paymentLink,
    required this.status,
  });

  factory SettlementMessage.fromJson(Map<String, dynamic> json) {
    String? channelLink;

    final paymentChannel = json['payment_channel'];
    if (paymentChannel is Map) {
      final paymentChannelMap = Map<String, dynamic>.from(paymentChannel);
      channelLink = paymentChannelMap['kakaopay_link']?.toString()
          ?? paymentChannelMap['payment_link']?.toString();
    }

    return SettlementMessage(
      settlementId: _toInt(json['settlement_id'] ?? json['id']),
      totalAmount: _toInt(json['total_amount']),
      shareAmount: _toInt(json['share_amount']),
      receiptImageUrl: json['receipt_image_url']?.toString()
          ?? json['image_url']?.toString(),
      paymentLink: json['kakaopay_link']?.toString()
          ?? json['payment_link']?.toString()
          ?? channelLink,
      status: json['status']?.toString() ?? 'REQUEST',
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String get totalAmountText => '${_formatWon(totalAmount)}원';
  String get shareAmountText => '${_formatWon(shareAmount)}원';

  static String _formatWon(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
  }
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

  void _onChatRoomsChanged() {
    _fetchChatRooms();
  }

  @override
  void initState() {
    super.initState();
    _fetchChatRooms();

    TripService.chatRoomsRefreshNotifier.addListener(_onChatRoomsChanged);
  }

  @override
  void dispose() {
    TripService.chatRoomsRefreshNotifier.removeListener(_onChatRoomsChanged);
    super.dispose();
  }

  Future<void> _fetchChatRooms() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final List<dynamic> data = await TripService.getChatRooms(
      token: AuthSession.token ?? '', // 실제 연동시 UserToken 입력
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
                  : _serverRooms.isEmpty
                      ? const Center(
                          child: Text(
                            '채팅방이 없습니다.',
                            style: TextStyle(
                              color: AppColors.gray,
                              fontSize: 13,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _serverRooms.length,
                          itemBuilder: (context, index) {
                            return _buildRoomTile(
                              context,
                              _serverRooms[index],
                            );
                          },
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
  // 테스트용 리더 토큰. 실제 배포에서는 로그인 후 저장된 토큰을 사용해야 함.
  //static const String _settlementToken = AuthSession.token ?? '';

  final ImagePicker _picker = ImagePicker();
  final TextEditingController _settlementAmountCtrl = TextEditingController();
  final TextEditingController _kakaoPayLinkCtrl = TextEditingController();

  int? _currentReceiptId;
  String? _currentReceiptImageUrl;
  bool _isSettlementProcessing = false;
  bool _showAttachPanel = false;
  bool _isNoticeExpanded = false;
  // 우선 주석처리
  // final ImagePicker _picker = ImagePicker();
  // bool _showAttachPanel = false;

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
    _loadPendingSettlementsForThisRoom();
  }

  void _connectWebSocket() {
    final wsUrl = Uri.parse('${AppConfig.wsBaseUrl}/ws/chat/${widget.room.id}/');
    _channel = WebSocketChannel.connect(wsUrl);

    _channel!.stream.listen((data) {
      final decodedRaw = jsonDecode(data);

      if (decodedRaw is! Map) {
        return;
      }

      final decoded = Map<String, dynamic>.from(decodedRaw);

      if (!mounted) return;

      setState(() {
        final messageType = decoded['type']?.toString();

        if (messageType == 'settlement_request') {
          final settlementRaw = decoded['settlement'];

          final settlementJson = settlementRaw is Map
              ? Map<String, dynamic>.from(settlementRaw)
              : decoded;

          _messages.add(
            _Message(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              userId: decoded['sender']?.toString() ?? 'system',
              text: '정산 요청이 도착했습니다.',
              time: TimeOfDay.now().format(context),
              isMe: false,
              isSettlement: true,
              settlement: SettlementMessage.fromJson(settlementJson),
            ),
          );
        } else {
          _messages.add(
            _Message(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              userId: decoded['sender']?.toString() ?? '',
              text: decoded['message']?.toString() ?? '',
              time: TimeOfDay.now().format(context),
              isMe: decoded['sender'] == widget.myNickname,
            ),
          );
        }
      });

      _scrollToBottom();
    });
  }

  Future<void> _loadPendingSettlementsForThisRoom() async {
    try {
      final settlements = await SettlementService.getMyPaySettlements(
        token: AuthSession.token ?? '',
      );

      final roomSettlements = settlements.where((item) {
        final map = Map<String, dynamic>.from(item as Map);
        final tripId = _toInt(map['trip_id']);
        final status = map['status']?.toString();

        return tripId == widget.room.tripId &&
            ['REQUEST', 'LINK_OPENED', 'PAID_SELF'].contains(status);
      }).toList();

      if (!mounted || roomSettlements.isEmpty) return;

      setState(() {
        for (final item in roomSettlements) {
          final map = Map<String, dynamic>.from(item as Map);

          _messages.add(
            _Message(
              id: 'settlement_${map['id']}',
              userId: 'system',
              text: '정산 요청이 도착했습니다.',
              time: TimeOfDay.now().format(context),
              isMe: false,
              isSettlement: true,
              settlement: SettlementMessage.fromJson(map),
            ),
          );
        }
      });

      _scrollToBottom();
    } catch (e) {
      print('정산 요청 목록 불러오기 실패: $e');
    }
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
    _settlementAmountCtrl.dispose();
    _kakaoPayLinkCtrl.dispose();
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.secondary),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F1EF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person,
                color: AppColors.gray,
                size: 21,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.room.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.secondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '• 참여 중',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.secondary),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: AppColors.secondary),
            onPressed: _showMoreMenu,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildNoticeBar(),
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
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
    if (msg.isSettlement && msg.settlement != null) {
      return _buildSettlementRequestCard(msg.settlement!);
    }

    if (msg.imageFile != null) {
      return Align(
        alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          constraints: const BoxConstraints(
            maxWidth: 220,
            maxHeight: 220,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.file(
            msg.imageFile!,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    return Align(
      alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: const BoxConstraints(maxWidth: 260),
        child: Column(
          crossAxisAlignment:
              msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!msg.isMe)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Text(
                  '@${msg.userId}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.gray,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (msg.isMe)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      msg.time,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.gray,
                      ),
                    ),
                  ),

                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: msg.isMe ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: msg.isMe
                          ? null
                          : Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      msg.text,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: msg.isMe ? Colors.white : AppColors.secondary,
                        decoration: msg.isLink
                            ? TextDecoration.underline
                            : TextDecoration.none,
                      ),
                    ),
                  ),
                ),

                if (!msg.isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text(
                      msg.time,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.gray,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettlementRequestCard(SettlementMessage settlement) {
   return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.receipt_long, color: AppColors.primary, size: 20),
                SizedBox(width: 6),
                Text(
                  '정산 요청이 도착했습니다',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '총 결제액과 1인당 정산금액을 확인한 뒤 정산을 진행해주세요.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.gray,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _showSettlementDialog(settlement),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('정산 정보 확인하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  void _showSettlementDialog(SettlementMessage settlement) {
    bool isChecked = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text(
                '정산 확인',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.secondary,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSettlementInfoRow('총 결제액', settlement.totalAmountText),
                  const SizedBox(height: 8),
                  _buildSettlementInfoRow('1인당 정산금액', settlement.shareAmountText),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _openReceiptImage(settlement.receiptImageUrl),
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('이용내역 확인하기'),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: isChecked,
                        onChanged: (value) {
                          setDialogState(() {
                            isChecked = value ?? false;
                          });
                        },
                      ),
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            '이용내역과 금액을 확인했습니다.\n체크 후 정산하기 버튼이 활성화됩니다.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: AppColors.secondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('닫기'),
                ),
                ElevatedButton(
                  onPressed: isChecked
                    ? () async {
                        try {
                          final result = await SettlementService.openSettlementLink(
                            token: AuthSession.token ?? '',
                            settlementId: settlement.settlementId,
                          );

                          String? link = result['kakaopay_link']?.toString()
                              ?? result['payment_link']?.toString()
                              ?? result['link']?.toString();

                          final paymentChannel = result['payment_channel'];
                          if ((link == null || link.isEmpty) && paymentChannel is Map) {
                            final paymentChannelMap = Map<String, dynamic>.from(paymentChannel);
                            link = paymentChannelMap['kakaopay_link']?.toString()
                                ?? paymentChannelMap['payment_link']?.toString();
                          }

                          link ??= settlement.paymentLink;

                          if (link == null || link.isEmpty) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('등록된 송금 링크가 없습니다.')),
                            );
                            return;
                          }

                          if (mounted) {
                            Navigator.pop(dialogContext);
                          }

                          final uri = Uri.parse(link);
                          final opened = await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );

                          if (!opened && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('송금 링크를 열 수 없습니다.')),
                            );
                          }
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('송금 링크 열림 처리 실패: $e')),
                          );
                        }
                      }
                    : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('정산하기'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSettlementInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.gray,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.secondary,
          ),
        ),
      ],
    );
  }

  void _openReceiptImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('등록된 이용내역 이미지가 없습니다.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('이미지를 불러올 수 없습니다.'),
                    );
                  },
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoticeBar() {
    final noticeText = widget.room.pinnedNotice.isNotEmpty
        ? widget.room.pinnedNotice
        : '택시 번호 및 만날 위치를 꼭 공유해주세요!';

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFFEAF5EF),
        border: Border(
          top: BorderSide(color: AppColors.border),
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isNoticeExpanded = !_isNoticeExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.push_pin,
                    size: 17,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '공지',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _isNoticeExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),

          if (_isNoticeExpanded)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                noticeText,
                style: const TextStyle(
                  color: AppColors.secondary,
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
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
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDADADA),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                _buildMoreMenuItem(
                  icon: Icons.notifications,
                  title: '채팅 알림',
                  trailing: Switch(
                    value: true,
                    activeColor: AppColors.primary,
                    onChanged: (_) {},
                  ),
                ),
                _buildMoreMenuItem(
                  icon: Icons.search,
                  title: '채팅방 검색',
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                _buildMoreMenuItem(
                  icon: Icons.group_add_outlined,
                  title: '참여자 목록',
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                const Divider(height: 18),
                _buildMoreMenuItem(
                  icon: Icons.exit_to_app,
                  title: '채팅방 나가기',
                  color: Colors.redAccent,
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMoreMenuItem({
    required IconData icon,
    required String title,
    Color color = AppColors.secondary,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(
        title,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _buildInputBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_showAttachPanel)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildAttachAction(
                      icon: Icons.image_outlined,
                      label: '사진',
                      onTap: () async {
                        setState(() => _showAttachPanel = false);
                        await _pickAndSendImage(ImageSource.gallery);
                      },
                    ),
                    _buildAttachAction(
                      icon: Icons.camera_alt_outlined,
                      label: '카메라',
                      onTap: () async {
                        setState(() => _showAttachPanel = false);
                        await _pickAndSendImage(ImageSource.camera);
                      },
                    ),
                    _buildAttachAction(
                      icon: Icons.receipt_long,
                      label: '정산 요청',
                      onTap: _isSettlementProcessing
                          ? null
                          : () {
                              setState(() => _showAttachPanel = false);
                              _startLeaderSettlementFlow();
                            },
                    ),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showAttachPanel = !_showAttachPanel;
                      });
                    },
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _showAttachPanel
                            ? AppColors.primary
                            : const Color(0xFFF4F4F2),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Icon(
                        _showAttachPanel ? Icons.close : Icons.add,
                        size: 22,
                        color: _showAttachPanel ? Colors.white : AppColors.gray,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F4F2),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: TextField(
                        controller: _inputCtrl,
                        decoration: const InputDecoration(
                          hintText: '메시지 입력...',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F4F2),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(
                        Icons.arrow_upward,
                        size: 20,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachAction({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF5EF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.gray,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source);

      if (pickedFile == null) return;

      setState(() {
        _messages.add(
          _Message(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            userId: widget.myNickname,
            text: '',
            time: TimeOfDay.now().format(context),
            isMe: true,
            imageFile: File(pickedFile.path),
          ),
        );
      });

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지 선택 실패: $e')),
      );
    }
  }

  Future<void> _startLeaderSettlementFlow() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);

      if (pickedFile == null) {
        return;
      }

      setState(() {
        _isSettlementProcessing = true;
      });

      final uploadResult = await SettlementService.uploadReceiptImage(
        token: AuthSession.token ?? '',
        tripId: widget.room.tripId,
        imageFile: File(pickedFile.path),
      );

      final receiptId = _toInt(uploadResult['id']);

      if (receiptId == 0) {
        throw Exception('receipt_id를 찾을 수 없습니다.');
      }

      final analyzeResult = await SettlementService.analyzeReceiptOcr(
        token: AuthSession.token ?? '',
        receiptId: receiptId,
      );

      final extractedAmount = _toInt(analyzeResult['extracted_total_amount']);

      _currentReceiptId = receiptId;
      _currentReceiptImageUrl = analyzeResult['receipt_image_url']?.toString();

      if (extractedAmount > 0) {
        _settlementAmountCtrl.text = extractedAmount.toString();
      }

      try {
        final channel = await SettlementService.getPaymentChannel(
          token: AuthSession.token ?? '',
          tripId: widget.room.tripId,
        );

        final savedLink = channel['kakaopay_link']?.toString() ?? '';
        _kakaoPayLinkCtrl.text = savedLink;
      } catch (e) {
        _kakaoPayLinkCtrl.clear();
        print('송금 링크 불러오기 실패: $e');
      }

      if (!mounted) return;

      _showLeaderSettlementDialog();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('영수증 분석 실패: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSettlementProcessing = false;
        });
      }
    }
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  void _showLeaderSettlementDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            '정산 요청',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: AppColors.secondary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _settlementAmountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '총 결제 금액',
                  hintText: '예: 18400',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _kakaoPayLinkCtrl,
                decoration: const InputDecoration(
                  labelText: '카카오페이 송금 링크',
                  hintText: 'https://qr.kakaopay.com/...',
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openReceiptImage(_currentReceiptImageUrl),
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('업로드한 이용내역 확인'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('닫기'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _submitLeaderSettlement(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('정산 요청하기'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitLeaderSettlement(BuildContext dialogContext) async {
    final receiptId = _currentReceiptId;
    final amountText = _settlementAmountCtrl.text.replaceAll(',', '').trim();
    final amount = int.tryParse(amountText);
    final link = _kakaoPayLinkCtrl.text.trim();

    if (receiptId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('영수증 정보가 없습니다.')),
      );
      return;
    }

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('올바른 금액을 입력해주세요.')),
      );
      return;
    }

    if (link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('송금 링크를 입력해주세요.')),
      );
      return;
    }

    try {
      await SettlementService.confirmReceiptAmount(
        token: AuthSession.token ?? '',
        receiptId: receiptId,
        totalAmount: amount,
      );

      await SettlementService.upsertPaymentChannel(
        token: AuthSession.token ?? '',
        tripId: widget.room.tripId,
        kakaopayLink: link,
      );

      final settlements = await SettlementService.createSettlements(
        token: AuthSession.token ?? '',
        tripId: widget.room.tripId,
      );

      if (!mounted) return;

      Navigator.pop(dialogContext);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('정산 요청이 생성되었습니다.')),
      );

      if (settlements.isNotEmpty) {
        final first = Map<String, dynamic>.from(settlements.first as Map);

        _channel?.sink.add(jsonEncode({
          'type': 'settlement_request',
          'message': '정산 요청이 도착했습니다.',
          'settlement': first,
        }));
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('정산 요청 실패: $e')),
      );
    }
  }
  }