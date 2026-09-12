import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'mychat.dart';
import '../tab_widget/tab_controller.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'location_picker.dart';
import '../map_view.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class ChatPage extends StatefulWidget {
  final int roomId;
  final int userId;
  const ChatPage({
    super.key,
    required this.roomId,
    required this.userId,
  });
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  static const Color primary = Color(0xFFFF7A00);
  static const String baseUrl = "http://35.216.34.21/together";

  static const Map<String, String> regionNameMap = {
    "cheonan": "천안", "asan": "아산", "dangjin": "당진", "seosan": "서산",
    "taean": "태안", "yesan": "예산", "hongseong": "홍성", "cheongyang": "청양",
    "gongju": "공주", "boryeong": "보령", "buyeo": "부여", "seocheon": "서천",
    "nonsan": "논산", "gyeryong": "계룡", "geumsan": "금산",
  };

  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final TextEditingController amountController = TextEditingController();
  List<dynamic> messages = [];
  Map<String, dynamic>? roomInfo;
  bool isLoading = true;
  bool isSending = false;
  bool isSettling = false;
  bool isAttaching = false;
  int settlementPeopleCount = 1;
  int lastMessageId = 0;
  bool roomDeletedHandled = false;
  bool kickedHandled = false;
  bool timeExpiredNotified = false;
  bool isLeaving = false; // ⭐ 추가: 자발적으로 나가는 중인지 표시
  Timer? pollTimer;
  IO.Socket? _socket;

  final Map<int, WebViewController> _locationControllers = {};

  @override
  void initState() {
    super.initState();
    loadMessages(initial: true);
    _connectSocket(); // ⭐ 추가

    // ⭐ 소켓이 즉시 알림을 쏴주므로, 폴링은 "소켓이 끊겼을 때의 안전망" 역할로 주기를 늘림
    pollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      loadMessages(initial: false);
    });
  }

// ⭐ 추가: 소켓 연결 및 이벤트 구독
  void _connectSocket() {

    _socket = IO.io(
      'http://35.216.34.21:3001',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _socket!.connect();

    _socket!.onConnect((_) {
      _socket!.emit('join_room', {
        'room_id': widget.roomId,
        'user_id': widget.userId,
      });
    });

    // ⭐ 누군가 메시지를 보냈을 때 (chat_emoji_send.php 등에서 notifyRoomUpdate 호출됨)
    _socket!.on('new_message', (_) {
      if (!mounted) return;
      loadMessages(initial: false);
    });

    // ⭐ 핵심: 누군가 읽었을 때 -> 즉시 재조회해서 안읽음 숫자를 실시간으로 갱신
    _socket!.on('read_updated', (_) {
      if (!mounted) return;
      loadMessages(initial: false);
    });

    _socket!.on('member_left', (_) {
      if (!mounted) return;
      loadMessages(initial: false);
    });

    _socket!.on('room_deleted', (_) {
      if (!mounted || roomDeletedHandled) return;
      roomDeletedHandled = true;
      handleRoomDeleted();
    });

  }
  // ⭐ 위치기반서비스 비신고 상태 대응: 위치 전송 기능 일시 잠금
  void _showFeatureLockedNotice() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("위치기반서비스사업자 신고 승인 대기중..\n현재 이용할 수 없습니다")),
    );
  }

  @override
  void dispose() {
    pollTimer?.cancel();
    _socket?.dispose(); // ⭐ 추가
    messageController.dispose();
    scrollController.dispose();
    amountController.dispose();
    super.dispose();
  }

  Future<void> loadMessages({required bool initial}) async {
    if (roomDeletedHandled || kickedHandled || isLeaving) return; // ⭐ 나가는 중이면 폴링 결과 무시
    try {
      final response = await http.get(
        Uri.parse(
          "${dotenv.env['PHP_URL']}chat2.php"
              "?room_id=${widget.roomId}"
              "&after_id=${initial ? 0 : lastMessageId}"
              "&user_id=${widget.userId}",
        ),
      );
      final data = jsonDecode(response.body);
      if (!mounted) return;
      if (data["success"] == true) {
        final bool roomExists = data["roomExists"] != false;
        if (!roomExists) {
          if (!roomDeletedHandled) {
            roomDeletedHandled = true;
            handleRoomDeleted();
          }
          return;
        }
        if (data["isMember"] == false) {
          if (!kickedHandled) {
            kickedHandled = true;
            handleKicked();
          }
          return;
        }
        final newMessages = List<dynamic>.from(data["messages"] ?? []);

        // ⭐ 이미 표시된 메시지(과거에 받았던 것)도 unread_count가 갱신되었을 수 있으므로
        //    매 폴링마다 messages 전체를 최신 응답으로 다시 구성
        setState(() {
          roomInfo = data["room"];
          if (initial) {
            messages = newMessages;
          } else if (newMessages.isNotEmpty) {
            _mergeUnreadCounts(newMessages);
            messages.addAll(newMessages);
          }

          // ⭐ 추가: 새 메시지 유무와 무관하게, 매 폴링마다 내가 보낸 과거 메시지들의
          //    최신 읽음 상태를 반영해서 채팅방을 나갔다 들어오지 않아도 실시간으로 숫자가 줄어들게 함
          final ownReads = data["own_reads"];
          if (ownReads != null) {
            _applyOwnReads(List<dynamic>.from(ownReads));
          }

          if (messages.isNotEmpty) {
            lastMessageId =
                int.tryParse(messages.last["id"].toString()) ?? lastMessageId;
          }
          isLoading = false;
        });

        if (data["expired"] == true && !timeExpiredNotified) {
          timeExpiredNotified = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showTimeExpiredDialog();
          });
        }
        if (!initial && newMessages.isNotEmpty) {
          scrollToBottom();
        }
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  // ⭐ 새로 받아온 메시지 중 이미 목록에 있는 id는 unread_count만 최신화 (중복 방지)
  void _mergeUnreadCounts(List<dynamic> newMessages) {
    for (final newMsg in newMessages) {
      final idx = messages.indexWhere((m) => m["id"].toString() == newMsg["id"].toString());
      if (idx != -1) {
        messages[idx]["unread_count"] = newMsg["unread_count"];
      }
    }
  }

  // ⭐ 추가: 서버가 내려준 own_reads(내가 보낸 메시지들의 최신 unread_count)를
//    현재 화면에 있는 messages 목록에 매칭해서 갱신
  void _applyOwnReads(List<dynamic> ownReads) {
    for (final entry in ownReads) {
      final id = entry["id"].toString();
      final idx = messages.indexWhere((m) => m["id"].toString() == id);
      if (idx != -1) {
        messages[idx]["unread_count"] = entry["unread_count"];
      }
    }
  }

  // =========================
  // 공용 다이얼로그 헬퍼 (단일 버튼 알림)
  // =========================
  Future<void> _showInfoDialog({
    required IconData icon,
    required String title,
    required String message,
    bool barrierDismissible = true,
  }) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      useRootNavigator: false,
      barrierDismissible: barrierDismissible,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.redAccent, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "확인",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================
  // 공용 다이얼로그 헬퍼 (취소/확인 2버튼)
  // =========================
  Future<bool> _showConfirmDialog({
    required IconData icon,
    required String title,
    required String message,
    required String confirmLabel,
    Color confirmColor = Colors.redAccent,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.redAccent, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text(
                        "취소",
                        style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: confirmColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(
                        confirmLabel,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return confirmed == true;
  }

  Future<void> handleRoomDeleted() async {
    pollTimer?.cancel();
    await _showInfoDialog(
      icon: Icons.error_outline_rounded,
      title: "방이 사라졌습니다",
      message: "방장이 채팅방을 나가 더 이상 이용할 수 없습니다",
    );
    if (!mounted) return;
    goToMyChat();
  }

  Future<void> handleKicked() async {
    pollTimer?.cancel();
    await _showInfoDialog(
      icon: Icons.person_remove_rounded,
      title: "채팅방에서 퇴장당하셨습니다",
      message: "방장에 의해 채팅방에서 제외되었습니다",
      barrierDismissible: false,
    );
    if (!mounted) return;
    goToMyChat();
  }

  Future<void> _showTimeExpiredDialog() async {
    await _showInfoDialog(
      icon: Icons.schedule_rounded,
      title: "채팅방 노출이 종료되었습니다",
      message: "지정된 시간으로부터 시간이 지나서\n채팅방이 노출되지 않아요",
    );
  }

  Future<void> _showAccountRequiredDialog() async {
    await _showInfoDialog(
      icon: Icons.account_balance_rounded,
      title: "계좌정보가 없어요",
      message: "회원 페이지에서 계좌정보를 업데이트해주세요",
    );
  }

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty || isSending) {
      return;
    }
    setState(() {
      isSending = true;
    });
    try {
      final response = await http.post(
        Uri.parse("${dotenv.env['PHP_URL']}send_message.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "room_id": widget.roomId,
          "user_id": widget.userId,
          "message": text,
        }),
      );
      final data = jsonDecode(response.body);
      if (data["success"] == true) {
        messageController.clear();
        await loadMessages(initial: false);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data["message"] ?? "전송 실패")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("에러 : $e")),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        isSending = false;
      });
    }
  }

  // =========================
  // 사진/위치 첨부
  // =========================
  Future<void> showAttachmentSheet() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useRootNavigator: false,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _AttachTile(
                    icon: Icons.photo_rounded,
                    label: "사진",
                    color: primary,
                    onTap: () {
                      Navigator.pop(context);
                      pickAndSendImage();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AttachTile(
                    icon: Icons.location_on_rounded,
                    label: "지도",
                    color: Colors.grey.shade400, // ⭐ 잠금 상태 표시(회색)
                    onTap: () {
                      Navigator.pop(context);
                      _showFeatureLockedNotice(); // ⭐ pickAndSendLocation() 호출 자체를 막음
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _AttachTile(
                    icon: Icons.local_taxi_rounded,
                    label: "택시비 산출",
                    color: primary,
                    onTap: () {
                      Navigator.pop(context);
                      showTaxiFareDialog();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AttachTile(
                    icon: Icons.landscape_rounded,
                    label: "관광지",
                    color: primary,
                    onTap: () {
                      Navigator.pop(context);
                      showSpotDialog();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // =========================
  // 이모티콘
  // =========================
  Future<void> showEmojiSheet() async {
    FocusScope.of(context).unfocus();
    Map<String, List<dynamic>>? categories;
    try {
      final response = await http.get(Uri.parse("${dotenv.env['PHP_URL']}chat_emoji.php"));
      final data = jsonDecode(response.body);
      if (data["success"] == true) {
        final raw = data["categories"] as Map<String, dynamic>;
        categories = raw.map((key, value) => MapEntry(key, value as List<dynamic>));
      }
    } catch (e) {
      // 실패 시 categories = null 유지
    }
    if (!mounted) return;
    if (categories == null || categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("이모티콘을 불러올 수 없습니다")),
      );
      return;
    }
    final List<String> categoryKeys = categories.keys.toList();
    String selectedCategory = categoryKeys.first;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final List<dynamic> emojis = categories![selectedCategory] ?? [];
            return Container(
              height: 380,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  if (categoryKeys.length > 1)
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: categoryKeys.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final cat = categoryKeys[index];
                          final bool selected = cat == selectedCategory;
                          return GestureDetector(
                            onTap: () => setSheetState(() => selectedCategory = cat),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: selected ? primary : const Color(0xFFF7F7F9),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                cat,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: selected ? Colors.white : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  if (categoryKeys.length > 1) const SizedBox(height: 12),
                  Expanded(
                    child: emojis.isEmpty
                        ? Center(
                      child: Text(
                        "등록된 이모티콘이 없습니다",
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      ),
                    )
                        : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: emojis.length,
                      itemBuilder: (context, index) {
                        final Map<String, dynamic> emoji = emojis[index] as Map<String, dynamic>;
                        final String fileName = (emoji['file_name'] ?? '').toString();
                        final String label = (emoji['label'] ?? '').toString();
                        final String url = "$baseUrl/uploads/emoji/$fileName";
                        return GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            sendEmoji(fileName);
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    url,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: Colors.grey.shade100,
                                      child: Icon(Icons.broken_image_rounded, color: Colors.grey.shade300, size: 20),
                                    ),
                                  ),
                                ),
                              ),
                              if (label.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // =========================
  // 관광지 (spot 계열 축소판)
  // =========================
  void showSpotDialog() {
    if (roomInfo == null) return;
    final String regionId = (roomInfo!["region"] ?? "").toString();
    final String regionName = regionNameMap[regionId] ?? regionId;
    if (regionName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("지역 정보를 확인할 수 없습니다")),
      );
      return;
    }
    showDialog(
      context: context,
      useRootNavigator: false,
      builder: (_) => _SpotListDialogContent(
        regionName: regionName,
        roomId: widget.roomId,
        userId: widget.userId,
        primary: primary,
        onSent: () => loadMessages(initial: false),
      ),
    );
  }

  Future<void> sendEmoji(String fileName) async {
    try {
      final response = await http.post(
        Uri.parse("${dotenv.env['PHP_URL']}chat_emoji_send.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "room_id": widget.roomId,
          "user_id": widget.userId,
          "file_name": fileName,
        }),
      );
      final data = jsonDecode(response.body);
      if (data["success"] != true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data["message"] ?? "이모티콘 전송 실패")),
        );
      }
      await loadMessages(initial: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("에러 : $e")),
      );
    }
  }

  Future<void> pickAndSendImage() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;
    setState(() => isAttaching = true);
    try {
      final uri = Uri.parse("${dotenv.env['PHP_URL']}upload_chat_image.php");
      final request = http.MultipartRequest('POST', uri)
        ..fields['room_id'] = widget.roomId.toString()
        ..fields['user_id'] = widget.userId.toString()
        ..files.add(await http.MultipartFile.fromPath('image', picked.path));
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);
      if (data["success"] != true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data["message"] ?? "이미지 전송 실패")),
        );
      }
      await loadMessages(initial: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("에러 : $e")),
      );
    } finally {
      if (!mounted) return;
      setState(() => isAttaching = false);
    }
  }

  Future<void> pickAndSendLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LocationPickerPage()),
    );
    if (result == null) return;
    setState(() => isAttaching = true);
    try {
      final response = await http.post(
        Uri.parse("${dotenv.env['PHP_URL']}send_location.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "room_id": widget.roomId,
          "user_id": widget.userId,
          "lat": result["lat"],
          "lng": result["lng"],
        }),
      );
      final data = jsonDecode(response.body);
      if (data["success"] != true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data["message"] ?? "위치 전송 실패")),
        );
      }
      await loadMessages(initial: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("에러 : $e")),
      );
    } finally {
      if (!mounted) return;
      setState(() => isAttaching = false);
    }
  }
  // =========================
  // 신고하기
  // =========================
  Future<void> showReportDialog() async {

    // ⭐ 방 멤버 목록 조회 (기존 fetchMembers() 재사용)
    final members = await fetchMembers();

    if (!mounted) return;

    // 나 자신을 제외한 멤버만
    final targetMembers = members.where((m) {
      final memberId = int.tryParse(m["user_id"].toString()) ?? -1;
      return memberId != widget.userId;
    }).toList();

    if (targetMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("신고할 수 있는 참여자가 없습니다")),
      );
      return;
    }

    showDialog(
      context: context,
      useRootNavigator: false,
      builder: (_) => _ReportDialogContent(
        primary: primary,
        roomId: widget.roomId,
        reporterId: widget.userId,
        members: targetMembers,
      ),
    );

  }

  // =========================
  // 택시비 산출
  // =========================
  Future<void> showTaxiFareDialog() async {
    if (roomInfo == null) return;
    final String? startName = roomInfo!["start"];
    final String endName = roomInfo!["end"] ?? "";
    final String region = roomInfo!["region"] ?? "";
    final bool hasStartDefault = startName != null;
    const bool hasEndDefault = true;
    bool startManual = !hasStartDefault;
    double? startLat;
    double? startLng;
    bool endManual = false;
    double? endLat;
    double? endLng;
    bool isCalculating = false;
    bool hasResult = false;
    int? fareResult;
    double? distanceResult;
    int? durationResult;
    String? errorMessage;
    await showDialog(
      context: context,
      useRootNavigator: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> calculateFare() async {
            setDialogState(() {
              isCalculating = true;
              errorMessage = null;
            });
            try {
              final body = {
                "region": region,
                if (!startManual && hasStartDefault) "start_name": startName,
                if (startManual && startLat != null) "pickup_lat": startLat,
                if (startManual && startLng != null) "pickup_lng": startLng,
                if (!endManual) "end_name": endName,
                if (endManual && endLat != null) "dropoff_lat": endLat,
                if (endManual && endLng != null) "dropoff_lng": endLng,
              };
              final response = await http.post(
                Uri.parse("${dotenv.env['PHP_URL']}chat_taxi.php"),
                headers: {"Content-Type": "application/json"},
                body: jsonEncode(body),
              );
              final data = jsonDecode(response.body);
              if (data["success"] == true) {
                setDialogState(() {
                  hasResult = true;
                  fareResult = data["fare"];
                  distanceResult = (data["distance_km"] as num).toDouble();
                  durationResult = data["duration_min"];
                  isCalculating = false;
                });
              } else {
                setDialogState(() {
                  errorMessage = data["message"] ?? "택시비를 계산할 수 없습니다";
                  isCalculating = false;
                });
              }
            } catch (e) {
              setDialogState(() {
                errorMessage = "에러 발생: $e";
                isCalculating = false;
              });
            }
          }

          Future<void> pickStartLocation() async {
            _showFeatureLockedNotice(); // ⭐ LocationPickerPage 진입 자체를 차단
            return;
          }

          Future<void> pickEndLocation() async {
            _showFeatureLockedNotice(); // ⭐ 잠금
            return;
          }

          /*Future<void> pickStartLocation() async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LocationPickerPage()),
            );
            if (result == null) return;
            setDialogState(() {
              startLat = (result["lat"] as num).toDouble();
              startLng = (result["lng"] as num).toDouble();
            });
          }

          Future<void> pickEndLocation() async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LocationPickerPage()),
            );
            if (result == null) return;
            setDialogState(() {
              endLat = (result["lat"] as num).toDouble();
              endLng = (result["lng"] as num).toDouble();
            });
          }*/

          void toggleStartManual() {
            setDialogState(() {
              if (!hasStartDefault) {
                startLat = null;
                startLng = null;
                return;
              }
              startManual = !startManual;
              if (!startManual) {
                startLat = null;
                startLng = null;
              }
            });
          }

          void toggleEndManual() {
            setDialogState(() {
              endManual = !endManual;
              if (!endManual) {
                endLat = null;
                endLng = null;
              }
            });
          }

          Widget buildLocationRow({
            required IconData icon,
            required bool hasDefault,
            required String? defaultValue,
            required bool isManual,
            required double? manualLat,
            required double? manualLng,
            required VoidCallback onToggle,
            required VoidCallback onPickLocation,
          }) {
            final bool showingDefault = !isManual && hasDefault;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: Colors.grey.shade500),
                const SizedBox(width: 8),
                Expanded(
                  child: showingDefault
                      ? Text(
                    defaultValue ?? "",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                  )
                      : (manualLat != null
                      ? Row(
                    children: [
                      const Text("위치 지정됨", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onPickLocation,
                        child: Text("변경", style: TextStyle(fontSize: 12, color: primary, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  )
                      : OutlinedButton.icon(
                    onPressed: onPickLocation,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      side: BorderSide(color: primary.withOpacity(0.4)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: Icon(Icons.add_location_alt_rounded, size: 14, color: primary),
                    label: Text("위치 선택", style: TextStyle(fontSize: 12, color: primary, fontWeight: FontWeight.w700)),
                  )),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onToggle,
                  child: Text(
                    showingDefault ? "위치 직접 지정" : "되돌리기",
                    style: TextStyle(fontSize: 12, color: primary, fontWeight: FontWeight.w700, decoration: TextDecoration.underline),
                  ),
                ),
              ],
            );
          }

          final bool startResolved = (!startManual && hasStartDefault) || (startManual && startLat != null);
          final bool endResolved = (!endManual) || (endManual && endLat != null);
          final bool canCalculate = startResolved && endResolved;

          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: primary.withOpacity(0.1), shape: BoxShape.circle),
                        child: Icon(Icons.local_taxi_rounded, color: primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          "택시비 산출",
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  buildLocationRow(
                    icon: Icons.trip_origin_rounded,
                    hasDefault: hasStartDefault,
                    defaultValue: startName,
                    isManual: startManual,
                    manualLat: startLat,
                    manualLng: startLng,
                    onToggle: toggleStartManual,
                    onPickLocation: pickStartLocation,
                  ),
                  const SizedBox(height: 14),
                  buildLocationRow(
                    icon: Icons.place_rounded,
                    hasDefault: hasEndDefault,
                    defaultValue: endName,
                    isManual: endManual,
                    manualLat: endLat,
                    manualLng: endLng,
                    onToggle: toggleEndManual,
                    onPickLocation: pickEndLocation,
                  ),
                  const SizedBox(height: 20),
                  if (!hasResult) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: (isCalculating || !canCalculate) ? null : calculateFare,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (!canCalculate) ? Colors.grey.shade300 : primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: isCalculating
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.calculate_rounded, color: Colors.white, size: 18),
                        label: Text(
                          isCalculating ? "계산 중..." : "택시비 예상",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(errorMessage!, style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
                    ],
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFFF7F7F9), borderRadius: BorderRadius.circular(14)),
                      child: Column(
                        children: [

                          // ⭐ 추가: 금액 옆에 작은 재계산 버튼
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [

                              Text(
                                "${formatCurrency(fareResult!)}원",
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: primary),
                              ),

                              const SizedBox(width: 8),

                              GestureDetector(
                                onTap: () {
                                  setDialogState(() {
                                    // ⭐ 기존 위치 선택 상태(startManual/endManual, 좌표)는 그대로 두고
                                    //    결과 화면만 초기화해서 위치 수정 UI로 되돌아감
                                    hasResult = false;
                                    errorMessage = null;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: primary.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.refresh_rounded, size: 12, color: primary),
                                      const SizedBox(width: 3),
                                      Text(
                                        "재계산",
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: primary),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            ],
                          ),

                          const SizedBox(height: 4),

                          Text(
                            "약 ${distanceResult!.toStringAsFixed(1)}km · ${durationResult}분 예상",
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                          ),

                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              try {
                                await http.post(
                                  Uri.parse("${dotenv.env['PHP_URL']}chat_taxi_fare_message.php"),
                                  headers: {"Content-Type": "application/json"},
                                  body: jsonEncode({
                                    "room_id": widget.roomId,
                                    "fare": fareResult,
                                    "distance_km": distanceResult,
                                    "duration_min": durationResult,
                                  }),
                                );
                                await loadMessages(initial: false);
                              } catch (e) {
                                // 무시
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: primary.withOpacity(0.4)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text("출력", style: TextStyle(color: primary, fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              amountController.text = fareResult!.toString();
                              showSettlementDialog(clearAmount: false);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text("정산하기", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // =========================
  // 정산
  // =========================
  Future<void> showSettlementDialog({bool clearAmount = true}) async {
    if (roomInfo == null) return;
    if (clearAmount) {
      amountController.clear();
    }
    final int maxPeople = (roomInfo!["current_people"] ?? 1) is int
        ? roomInfo!["current_people"]
        : int.tryParse(roomInfo!["current_people"].toString()) ?? 1;
    settlementPeopleCount = maxPeople.clamp(1, maxPeople);
    await showDialog(
      context: context,
      useRootNavigator: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.calculate_rounded, color: primary, size: 28),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "정산하기",
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "총 금액과 나눌 인원을 입력해주세요",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: "총 금액을 입력하세요",
                      suffixText: "원",
                      filled: true,
                      fillColor: const Color(0xFFF7F7F9),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F7F9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "정산 인원 (최대 $maxPeople명)",
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                        ),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                if (settlementPeopleCount > 1) {
                                  setDialogState(() {
                                    settlementPeopleCount--;
                                  });
                                }
                              },
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: settlementPeopleCount > 1 ? primary.withOpacity(0.12) : Colors.grey.shade200,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.remove_rounded,
                                  size: 16,
                                  color: settlementPeopleCount > 1 ? primary : Colors.grey.shade400,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 36,
                              child: Text(
                                "$settlementPeopleCount명",
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black87),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                if (settlementPeopleCount < maxPeople) {
                                  setDialogState(() {
                                    settlementPeopleCount++;
                                  });
                                }
                              },
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: settlementPeopleCount < maxPeople ? primary.withOpacity(0.12) : Colors.grey.shade200,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.add_rounded,
                                  size: 16,
                                  color: settlementPeopleCount < maxPeople ? primary : Colors.grey.shade400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            "취소",
                            style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            sendSettlement();
                          },
                          child: const Text(
                            "확인",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> sendSettlement() async {
    if (roomInfo == null || isSettling) return;
    final amount = int.tryParse(amountController.text.trim());
    if (amount == null || amount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("올바른 금액을 입력해주세요")),
      );
      return;
    }
    setState(() {
      isSettling = true;
    });
    try {
      final response = await http.post(
        Uri.parse("${dotenv.env['PHP_URL']}send_settlement.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "room_id": widget.roomId,
          "amount": amount,
          "people": settlementPeopleCount,
          "user_id": widget.userId,
        }),
      );
      final data = jsonDecode(response.body);
      if (data["success"] == true) {
        await loadMessages(initial: false);
      } else if (data["need_account"] == true) {
        if (!mounted) return;
        await _showAccountRequiredDialog();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("정산 요청에 실패했습니다")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("에러 : $e")),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        isSettling = false;
      });
    }
  }

  // =========================
  // 참여자/방장 관리
  // =========================
  Future<List<dynamic>> fetchMembers() async {
    try {
      final response = await http.get(
        Uri.parse("${dotenv.env['PHP_URL']}room_member.php?room_id=${widget.roomId}"),
      );
      final data = jsonDecode(response.body);
      if (data["success"] == true) {
        return List<dynamic>.from(data["members"] ?? []);
      }
    } catch (e) {
      // 무시하고 빈 목록 반환
    }
    return [];
  }

  bool get isOwner =>
      roomInfo != null && roomInfo!["user_id"].toString() == widget.userId.toString();

  Future<bool> toggleDead(bool newValue) async {
    try {
      final response = await http.post(
        Uri.parse("${dotenv.env['PHP_URL']}toggle_dead.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "room_id": widget.roomId,
          "user_id": widget.userId,
          "dead": newValue ? 1 : 0,
        }),
      );
      final data = jsonDecode(response.body);
      if (data["success"] == true) {
        if (mounted) {
          setState(() {
            roomInfo?["dead"] = newValue ? 1 : 0;
          });
        }
        return true;
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data["message"] ?? "변경 실패")),
          );
        }
        return false;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("에러 : $e")),
        );
      }
      return false;
    }
  }

  Future<bool> kickMember(int targetUserId) async {
    try {
      final response = await http.post(
        Uri.parse("${dotenv.env['PHP_URL']}out_room.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "room_id": widget.roomId,
          "owner_id": widget.userId,
          "target_user_id": targetUserId,
        }),
      );
      final data = jsonDecode(response.body);
      if (data["success"] == true) {
        await loadMessages(initial: false);
        return true;
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data["message"] ?? "퇴장 처리에 실패했습니다")),
          );
        }
        return false;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("에러 : $e")),
        );
      }
      return false;
    }
  }

  Future<void> confirmKick(String memberName, int targetUserId) async {
    final confirmed = await _showConfirmDialog(
      icon: Icons.person_remove_rounded,
      title: "강제 퇴장",
      message: "$memberName님을 채팅방에서 강제 퇴장시키겠습니까?",
      confirmLabel: "확인",
    );
    if (!confirmed) return;
    final success = await kickMember(targetUserId);
    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$memberName님을 강제 퇴장시켰습니다")),
      );
    }
  }

  Future<void> showMembersSheet() async {
    final members = await fetchMembers();
    if (!mounted) return;
    bool localDead = (roomInfo?["dead"] ?? 0) == 1;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Text(
                    "참여중인 인원 (${members.length}명)",
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                    child: members.isEmpty
                        ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text("참여자 정보를 불러올 수 없습니다")),
                    )
                        : ListView.separated(
                      shrinkWrap: true,
                      itemCount: members.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final member = members[index];
                        final bool memberIsOwner = member["is_owner"] == true;
                        final String name = (member["name"] ?? "").toString();
                        final int memberUserId = int.tryParse(member["user_id"].toString()) ?? 0;
                        return Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: primary.withOpacity(0.15),
                              child: Text(
                                name.isNotEmpty ? name.substring(0, 1) : "?",
                                style: TextStyle(color: primary, fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
                              ),
                            ),
                            if (memberIsOwner)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: primary.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  "방장",
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: primary),
                                ),
                              ),
                            if (isOwner && !memberIsOwner) ...[
                              const SizedBox(width: 6),
                              IconButton(
                                onPressed: () => confirmKick(name, memberUserId),
                                icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent, size: 22),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  if (isOwner) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.block_rounded,
                            size: 18,
                            color: localDead ? Colors.redAccent : Colors.grey.shade500,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "채팅방 마감",
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87),
                                ),
                                Text(
                                  localDead ? "목록에서 숨겨진 상태예요" : "목록에 정상적으로 노출돼요",
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: localDead,
                            activeColor: Colors.redAccent,
                            onChanged: (value) async {
                              setModalState(() {
                                localDead = value;
                              });
                              final success = await toggleDead(value);
                              if (!success) {
                                setModalState(() {
                                  localDead = !value;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        leaveRoom();
                      },
                      icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                      label: const Text(
                        "채팅방 나가기",
                        style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> leaveRoom() async {
    final bool ownerLeaving = isOwner;
    final confirmed = await _showConfirmDialog(
      icon: ownerLeaving ? Icons.delete_outline_rounded : Icons.logout_rounded,
      title: ownerLeaving ? "채팅방 삭제" : "채팅방 나가기",
      message: ownerLeaving
          ? "방장이 나가면 채팅방이 모든 참여자에게서 삭제됩니다.\n정말 나가시겠습니까?"
          : "채팅방을 나가면 대화 내용을 다시 볼 수 없습니다",
      confirmLabel: ownerLeaving ? "삭제" : "나가기",
    );
    if (!confirmed) return;

    // ⭐ 수정: owner 여부와 무관하게, 나가기가 확정된 순간 폴링을 즉시 멈춰서
    //    나가는 도중 타이머가 한 번 더 돌아 "강퇴당함"으로 오판되는 경합을 차단
    isLeaving = true;
    pollTimer?.cancel();

    try {
      final response = await http.post(
        Uri.parse("${dotenv.env['PHP_URL']}leave_room.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "room_id": widget.roomId,
          "user_id": widget.userId,
        }),
      );
      final data = jsonDecode(response.body);
      if (!mounted) return;
      if (data["success"] == true) {
        Navigator.pop(context);
        AppTabController.switchTo(1);
        AppTabController.refreshChatTab();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data["message"] ?? "나가기 실패")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("에러 : $e")),
      );
    }
  }

  void goToMyChat() {
    Navigator.pop(context);
    AppTabController.switchTo(1);
    AppTabController.refreshChatTab();
  }

  // =========================
  // 포맷/판별 헬퍼
  // =========================
  String formatTime(String? createdAt) {
    if (createdAt == null) return "";
    final dt = DateTime.tryParse(createdAt);
    if (dt == null) return "";
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour < 12 ? "오전" : "오후";
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return "$period $displayHour:$minute";
  }

  String formatDateSeparator(String? createdAt) {
    if (createdAt == null) return "";
    final dt = DateTime.tryParse(createdAt);
    if (dt == null) return "";
    return "${dt.year}년 ${dt.month}월 ${dt.day}일";
  }

  bool isSpotMessage(dynamic msg) {
    return (msg["message"] ?? "").toString().startsWith("SPOT|");
  }

  bool isSameDate(String? a, String? b) {
    if (a == null || b == null) return false;
    final da = DateTime.tryParse(a);
    final db = DateTime.tryParse(b);
    if (da == null || db == null) return false;
    return da.year == db.year && da.month == db.month && da.day == db.day;
  }

  bool isSystemMessage(dynamic msg) {
    return msg["is_system"].toString() == "1" || msg["user_id"] == null;
  }

  bool isSettlementMessage(dynamic msg) {
    return isSystemMessage(msg) && (msg["message"] ?? "").toString().startsWith("SETTLEMENT|");
  }

  bool isTaxiFareMessage(dynamic msg) {
    return isSystemMessage(msg) && (msg["message"] ?? "").toString().startsWith("TAXI_FARE|");
  }

  bool isEmojiMessage(dynamic msg) {
    return (msg["message_type"] ?? "text") == "emoji";
  }

  bool isImageMessage(dynamic msg) {
    return (msg["message_type"] ?? "text") == "image";
  }

  bool isLocationMessage(dynamic msg) {
    return (msg["message_type"] ?? "text") == "location";
  }

  // ⭐ 추가: 메시지의 unread_count를 안전하게 int로 변환
  int? unreadCountOf(dynamic msg) {
    final raw = msg["unread_count"];
    if (raw == null) return null;
    if (raw is int) return raw;
    return int.tryParse(raw.toString());
  }

  String formatCurrency(int value) {
    final str = value.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i != 0) {
        buffer.write(',');
      }
    }
    return buffer.toString().split('').reversed.join();
  }

  WebViewController _getLocationController(int messageId, double lat, double lng) {
    if (_locationControllers.containsKey(messageId)) {
      return _locationControllers[messageId]!;
    }
    final jsKey = dotenv.env['kakaojava'] ?? '';
    final html = """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
      <style>
        html, body, #map { width: 100%; height: 100%; margin: 0; padding: 0; }
      </style>
    </head>
    <body>
      <div id="map"></div>
      <script src="https://dapi.kakao.com/v2/maps/sdk.js?appkey=$jsKey"></script>
      <script>
        try {
          var markerPosition = new kakao.maps.LatLng($lat, $lng);
          var container = document.getElementById('map');
          var options = {
            center: markerPosition,
            level: 4,
            draggable: false,
            scrollwheel: false
          };
          var map = new kakao.maps.Map(container, options);
          map.setZoomable(false);
          var marker = new kakao.maps.Marker({
            position: markerPosition
          });
          marker.setMap(map);
          setTimeout(function() {
            map.relayout();
            map.setCenter(markerPosition);
          }, 150);
        } catch (e) {}
      </script>
    </body>
    </html>
    """;
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..loadHtmlString(html);
    _locationControllers[messageId] = controller;
    return controller;
  }

  Widget buildMessageBubbleContent(dynamic msg, bool isMine) {
    if (isEmojiMessage(msg)) {
      final String imageUrl = "$baseUrl/${msg["message"]}";
      return Image.network(
        imageUrl,
        width: 128,
        height: 128,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Container(
          width: 96,
          height: 96,
          color: Colors.grey.shade200,
          child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
        ),
      );
    }
    if (isImageMessage(msg)) {
      final String imageUrl = "$baseUrl/${msg["message"]}";
      return GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            useRootNavigator: false,
            builder: (_) => Dialog(
              backgroundColor: Colors.transparent,
              child: InteractiveViewer(
                child: Image.network(imageUrl),
              ),
            ),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            imageUrl,
            width: 180,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 180,
              height: 180,
              color: Colors.grey.shade200,
              child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
            ),
          ),
        ),
      );
    }
    if (isLocationMessage(msg)) {
      final parts = (msg["message"] ?? "").toString().split(",");
      final lat = double.tryParse(parts.isNotEmpty ? parts[0] : "") ?? 0;
      final lng = double.tryParse(parts.length > 1 ? parts[1] : "") ?? 0;
      final int messageId = int.tryParse(msg["id"].toString()) ?? 0;
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MapViewPage(
                lat: lat,
                lng: lng,
                title: "공유된 위치",
              ),
            ),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 200,
            height: 130,
            child: Stack(
              children: [
                IgnorePointer(
                  child: WebViewWidget(
                    controller: _getLocationController(messageId, lat, lng),
                  ),
                ),
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on_rounded, color: Colors.white, size: 12),
                        const SizedBox(width: 4),
                        const Text(
                          "위치 공유됨",
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Text(
      msg["message"] ?? "",
      style: TextStyle(
        color: isMine ? Colors.white : Colors.black87,
        fontSize: 14,
        height: 1.3,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        goToMyChat();
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7F9),
        appBar: AppBar(
          titleSpacing: 0,
          title: roomInfo == null
              ? Text(
            "채팅방 #${widget.roomId}",
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black87,
              fontSize: 16,
            ),
          )
              : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                roomInfo!["start"] == null
                    ? "${roomInfo!["end"]}"
                    : "${roomInfo!["start"]} → ${roomInfo!["end"]}",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87, fontSize: 15),
              ),
              Text(
                "참여 ${roomInfo!["current_people"]}/${roomInfo!["people"]}명"
                    "${roomInfo!["time"] == null ? " · 시간 조율" : ""}",
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
            onPressed: goToMyChat,
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.black12,
          actions: [
            IconButton(
              icon: Icon(Icons.flag_outlined, color: Colors.grey.shade500, size: 20), // ⭐ 추가
              onPressed: roomInfo == null ? null : showReportDialog,
              tooltip: "신고하기",
            ),
            TextButton.icon(
              onPressed: roomInfo == null ? null : showSettlementDialog,
              icon: Icon(Icons.calculate_rounded, size: 18, color: primary),
              label: Text(
                "정산",
                style: TextStyle(
                  color: primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.menu_rounded, color: Colors.black87),
              onPressed: showMembersSheet,
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: isLoading
                  ? Center(child: CircularProgressIndicator(color: primary))
                  : messages.isEmpty
                  ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 56,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "첫 메시지를 보내보세요",
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                controller: scrollController,
                reverse: true,
                padding: const EdgeInsets.fromLTRB(15, 15, 15, 15),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final int reversedIndex = messages.length - 1 - index;
                  final msg = messages[reversedIndex];
                  final bool isSystem = isSystemMessage(msg);
                  final bool isSettlement = isSettlementMessage(msg);
                  final bool isTaxiFare = isTaxiFareMessage(msg);
                  final bool isSpotInfo = isSpotMessage(msg);
                  final prevMsg = reversedIndex > 0 ? messages[reversedIndex - 1] : null;
                  final nextMsg = reversedIndex + 1 < messages.length ? messages[reversedIndex + 1] : null;
                  final showDateSeparator = prevMsg == null || !isSameDate(prevMsg["created_at"], msg["created_at"]);

                  if (isTaxiFare) {
                    final parts = (msg["message"] as String).split("|");
                    final fare = int.tryParse(parts.length > 1 ? parts[1] : "0") ?? 0;
                    final distanceKm = double.tryParse(parts.length > 2 ? parts[2] : "0") ?? 0;
                    final durationMin = int.tryParse(parts.length > 3 ? parts[3] : "0") ?? 0;
                    return Column(
                      children: [
                        if (showDateSeparator)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  formatDateSeparator(msg["created_at"]),
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: primary.withOpacity(0.25)),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.local_taxi_rounded, size: 16, color: primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    "예상 택시비 ${formatCurrency(fare)}원",
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "(${distanceKm.toStringAsFixed(1)}km · ${durationMin}분)",
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  if (isSpotInfo) {
                    final parts = (msg["message"] as String).split("|");
                    final name = parts.length > 1 ? parts[1] : "";
                    final catL = parts.length > 2 ? parts[2] : "";
                    final catM = parts.length > 3 ? parts[3] : "";
                    final lat = double.tryParse(parts.length > 4 ? parts[4] : "");
                    final lng = double.tryParse(parts.length > 5 ? parts[5] : "");
                    final crowdInfo = parts.length > 6 ? parts[6] : "";
                    return Column(
                      children: [
                        if (showDateSeparator)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  formatDateSeparator(msg["created_at"]),
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: GestureDetector(
                            onTap: (lat != null && lng != null)
                                ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => MapViewPage(lat: lat, lng: lng, title: name)),
                              );
                            }
                                : null,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: primary.withOpacity(0.25)),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(color: primary.withOpacity(0.12), shape: BoxShape.circle),
                                    child: Icon(Icons.landscape_rounded, size: 18, color: primary),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87)),
                                        const SizedBox(height: 2),
                                        Text(
                                          crowdInfo.isNotEmpty ? "$catL · $catM · $crowdInfo" : "$catL · $catM",
                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (lat != null && lng != null)
                                    Icon(Icons.map_rounded, size: 16, color: Colors.grey.shade400),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  if (isSettlement) {
                    final parts = (msg["message"] as String).split("|");
                    final amount = int.tryParse(parts.length > 1 ? parts[1] : "0") ?? 0;
                    final people = int.tryParse(parts.length > 2 ? parts[2] : "1") ?? 1;
                    final perPerson = int.tryParse(parts.length > 3 ? parts[3] : "0") ?? 0;
                    final accountNumber = parts.length > 4 ? parts[4] : "";
                    return Column(
                      children: [
                        if (showDateSeparator)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  formatDateSeparator(msg["created_at"]),
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: primary.withOpacity(0.25)),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(color: primary.withOpacity(0.12), shape: BoxShape.circle),
                                      child: Icon(Icons.calculate_rounded, size: 16, color: primary),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      "정산 요청",
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("총 금액", style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                    Text(
                                      "${formatCurrency(amount)}원",
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("인원", style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                    Text(
                                      "$people명",
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: primary.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      Text("1인당", style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                      const SizedBox(height: 2),
                                      Text(
                                        "${formatCurrency(perPerson)}원",
                                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: primary),
                                      ),
                                    ],
                                  ),
                                ),
                                if (accountNumber.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    "아래 계좌로 입금해주세요",
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF7F7F9),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.account_balance_rounded, size: 14, color: Colors.grey.shade600),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            accountNumber,
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black87),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  if (isSystem) {
                    return Column(
                      children: [
                        if (showDateSeparator)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  formatDateSeparator(msg["created_at"]),
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                msg["message"] ?? "",
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  final isMine = msg["user_id"].toString() == widget.userId.toString();
                  final isSameSenderAsPrev = prevMsg != null &&
                      !showDateSeparator &&
                      !isSystemMessage(prevMsg) &&
                      prevMsg["user_id"].toString() == msg["user_id"].toString();
                  final bool showTime = nextMsg == null
                      || isSystemMessage(nextMsg)
                      || nextMsg["user_id"].toString() != msg["user_id"].toString()
                      || !isSameDate(nextMsg["created_at"], msg["created_at"])
                      || formatTime(nextMsg["created_at"]) != formatTime(msg["created_at"]);

                  // ⭐ 추가: 내가 보낸 메시지에 표시할 안읽음 인원 수
                  final int? unread = isMine ? unreadCountOf(msg) : null;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showDateSeparator)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                formatDateSeparator(msg["created_at"]),
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                      Padding(
                        padding: EdgeInsets.only(top: isSameSenderAsPrev ? 3 : 12),
                        child: Row(
                          mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!isMine) ...[
                              isSameSenderAsPrev
                                  ? const SizedBox(width: 32)
                                  : CircleAvatar(
                                radius: 16,
                                backgroundColor: primary.withOpacity(0.15),
                                child: Text(
                                  (msg["name"] ?? "?").toString().isNotEmpty
                                      ? msg["name"].toString().substring(0, 1)
                                      : "?",
                                  style: TextStyle(color: primary, fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Column(
                                crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  if (!isMine && !isSameSenderAsPrev)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 3, left: 2),
                                      child: Text(
                                        msg["name"] ?? "",
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                                      ),
                                    ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      // ⭐ 내가 보낸 메시지: 안읽음 숫자는 메시지마다, 시간은 그룹 마지막에만
                                      if (isMine && ((unread != null && unread > 0) || showTime)) ...[
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            if (unread != null && unread > 0)
                                              Padding(
                                                padding: EdgeInsets.only(bottom: showTime ? 2 : 0),
                                                child: Text(
                                                  "$unread",
                                                  style: TextStyle(fontSize: 10, color: primary, fontWeight: FontWeight.w700),
                                                ),
                                              ),
                                            if (showTime)
                                              Text(
                                                formatTime(msg["created_at"]),
                                                style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      Flexible(
                                        child: isEmojiMessage(msg)
                                            ? buildMessageBubbleContent(msg, isMine)
                                            : Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                          constraints: const BoxConstraints(maxWidth: 240),
                                          decoration: BoxDecoration(
                                            color: isMine ? primary : Colors.white,
                                            borderRadius: BorderRadius.only(
                                              topLeft: const Radius.circular(16),
                                              topRight: const Radius.circular(16),
                                              bottomLeft: Radius.circular(isMine ? 16 : 4),
                                              bottomRight: Radius.circular(isMine ? 4 : 16),
                                            ),
                                            boxShadow: isMine
                                                ? []
                                                : [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.04),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: buildMessageBubbleContent(msg, isMine),
                                        ),
                                      ),
                                      if (!isMine && showTime) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          formatTime(msg["created_at"]),
                                          style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: isAttaching ? null : showAttachmentSheet,
                      child: Container(
                        width: 42,
                        height: 42,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F7F9),
                          shape: BoxShape.circle,
                        ),
                        child: isAttaching
                            ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2, color: primary),
                        )
                            : const Icon(Icons.add_rounded, color: primary),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 120),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F7F9),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: TextField(
                          controller: messageController,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => sendMessage(),
                          decoration: InputDecoration(
                            hintText: "메시지를 입력하세요",
                            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            suffixIcon: GestureDetector(
                              onTap: showEmojiSheet,
                              child: Icon(
                                Icons.emoji_emotions_outlined,
                                color: Colors.grey.shade400,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: isSending ? null : sendMessage,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: isSending ? Colors.grey.shade300 : primary,
                          shape: BoxShape.circle,
                        ),
                        child: isSending
                            ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                            : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _AttachTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _SpotListDialogContent extends StatefulWidget {
  final String regionName;
  final int roomId;
  final int userId;
  final Color primary;
  final VoidCallback onSent;
  const _SpotListDialogContent({
    required this.regionName,
    required this.roomId,
    required this.userId,
    required this.primary,
    required this.onSent,
  });
  @override
  State<_SpotListDialogContent> createState() => _SpotListDialogContentState();
}

enum _ChatSpotTab { tour, leisure, shopping, lodging }

class _SpotListDialogContentState extends State<_SpotListDialogContent> {
  _ChatSpotTab selectedTab = _ChatSpotTab.tour;
  bool showDetail = false;
  Map<String, dynamic>? selectedSpot;
  double? crowdRate;
  Future<List<Map<String, dynamic>>>? _hubFuture;
  List<Map<String, String>>? _crowdSpots;
  final Map<String, WebViewController> _mapControllers = {};

  @override
  void initState() {
    super.initState();
    _hubFuture = _fetchAll();
    _loadCrowdData();
  }

  String _lastMonthYm() {
    final now = DateTime.now();
    final d = DateTime(now.year, now.month - 2, 1);
    return "${d.year}${d.month.toString().padLeft(2, '0')}";
  }

  Future<List<String>> _fetchSignguCdList() async {
    final url = '${dotenv.env['PHP_URL']}information.php?regionname=${Uri.encodeComponent(widget.regionName)}';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) return [];
    final data = jsonDecode(response.body);
    if (data['success'] != true) return [];
    final String raw = (data['signguCd'] ?? '').toString();
    return raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchAll() async {
    final signguCdList = await _fetchSignguCdList();
    if (signguCdList.isEmpty) return [];
    final baseYm = _lastMonthYm();
    final Set<String> seen = {};
    final List<Map<String, dynamic>> all = [];
    for (final cd in signguCdList) {
      try {
        final url = '${dotenv.env['PHP_URL']}api_zoongsim.php'
            '?areaCd=44&signguCd=${Uri.encodeComponent(cd)}&baseYm=$baseYm&numOfRows=1000';
        final response = await http.get(Uri.parse(url));
        if (response.statusCode != 200) continue;
        final data = jsonDecode(response.body);
        if (data['success'] != true) continue;
        final itemsContainer = data['data']?['response']?['body']?['items'];
        if (itemsContainer == null || itemsContainer is String) continue;
        final rawItems = itemsContainer['item'];
        if (rawItems == null) continue;
        final items = (rawItems is List) ? rawItems : [rawItems];
        for (final raw in items) {
          final item = Map<String, dynamic>.from(raw);
          final name = (item['hubTatsNm'] ?? '').toString();
          if (name.isEmpty || seen.contains(name)) continue;
          seen.add(name);
          all.add(item);
        }
      } catch (e) {}
    }
    return all;
  }

  Future<void> _loadCrowdData() async {
    try {
      final url = '${dotenv.env['PHP_URL']}api_people.php?regionname=${Uri.encodeComponent(widget.regionName)}';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return;
      final data = jsonDecode(response.body);
      if (data['error'] != null) return;
      final itemsContainer = data['response']?['body']?['items'];
      if (itemsContainer == null || itemsContainer is String) return;
      final items = itemsContainer['item'];
      if (items == null) return;
      final list = (items is List) ? items : [items];
      final spots = list.map((item) => {
        "name": (item['tAtsNm'] ?? '').toString(),
        "rate": (item['cnctrRate'] ?? '').toString(),
      }).toList();
      if (!mounted) return;
      setState(() => _crowdSpots = List<Map<String, String>>.from(spots));
    } catch (e) {}
  }

  String _cleanName(String raw) {
    String c = raw.replaceAll(RegExp(r'[\(（][^\)）]*[\)）]'), '');
    c = c.replaceAll(widget.regionName, '');
    return c.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  List<String> _buildCandidates(String cleaned, String raw) {
    final s = <String>{};
    if (cleaned.isNotEmpty) {
      s.add(cleaned);
      final noSpace = cleaned.replaceAll(' ', '');
      if (noSpace.isNotEmpty) s.add(noSpace);
      for (final w in cleaned.split(' ')) {
        if (w.trim().length >= 2) s.add(w.trim());
      }
    }
    if (raw.isNotEmpty) s.add(raw);
    return s.toList();
  }

  double? _matchCrowd(String hubTatsNm) {
    if (_crowdSpots == null) return null;
    for (final crowd in _crowdSpots!) {
      final crowdName = crowd['name'] ?? '';
      if (crowdName.isEmpty) continue;
      final candidates = _buildCandidates(_cleanName(crowdName), crowdName);
      for (final c in candidates) {
        if (c.isNotEmpty && hubTatsNm.contains(c)) {
          return double.tryParse(crowd['rate'] ?? '');
        }
      }
    }
    return null;
  }

  _ChatSpotTab? _classify(String mclsNm) {
    if (mclsNm == '숙박') return _ChatSpotTab.lodging;
    if (mclsNm == '레저스포츠') return _ChatSpotTab.leisure;
    if (mclsNm == '쇼핑') return _ChatSpotTab.shopping;
    if (mclsNm.endsWith('관광')) return _ChatSpotTab.tour;
    return null;
  }

  WebViewController _getMapController(String key, double lat, double lng) {
    if (_mapControllers.containsKey(key)) return _mapControllers[key]!;
    final jsKey = dotenv.env['kakaojava'] ?? '';
    final html = """
    <!DOCTYPE html><html><head><meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
    <style>html,body,#map{width:100%;height:100%;margin:0;padding:0;}</style>
    </head><body><div id="map"></div>
    <script src="https://dapi.kakao.com/v2/maps/sdk.js?appkey=$jsKey"></script>
    <script>
      try{
        var pos=new kakao.maps.LatLng($lat,$lng);
        var map=new kakao.maps.Map(document.getElementById('map'),{center:pos,level:4,draggable:false,scrollwheel:false});
        map.setZoomable(false);
        new kakao.maps.Marker({position:pos}).setMap(map);
        setTimeout(function(){map.relayout();map.setCenter(pos);},150);
      }catch(e){}
    </script></body></html>
    """;
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..loadHtmlString(html);
    _mapControllers[key] = controller;
    return controller;
  }

  Future<void> _sendToChat() async {
    if (selectedSpot == null) return;
    final name = (selectedSpot!['hubTatsNm'] ?? '').toString();
    final catL = (selectedSpot!['hubCtgryLclsNm'] ?? '').toString();
    final catM = (selectedSpot!['hubCtgryMclsNm'] ?? '').toString();
    final mapX = (selectedSpot!['mapX'] ?? '').toString();
    final mapY = (selectedSpot!['mapY'] ?? '').toString();
    final crowdText = crowdRate != null ? "혼잡도 ${crowdRate!.toStringAsFixed(1)}%" : "";
    final message = "SPOT|$name|$catL|$catM|$mapY|$mapX|$crowdText";
    try {
      await http.post(
        Uri.parse("${dotenv.env['PHP_URL']}send_message.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "room_id": widget.roomId,
          "user_id": widget.userId,
          "message": message,
        }),
      );
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSent();
    } catch (e) {}
  }

  IconData _categoryIcon(String c) {
    if (c.contains("숙박")) return Icons.hotel_rounded;
    if (c.contains("쇼핑")) return Icons.shopping_bag_rounded;
    if (c.contains("관광")) return Icons.landscape_rounded;
    return Icons.place_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: showDetail ? _buildDetail() : _buildList(),
      ),
    );
  }

  Widget _buildList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("${widget.regionName} 관광지", style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.black87)),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.close_rounded, color: Colors.grey.shade400),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _tab("관광", _ChatSpotTab.tour)),
            const SizedBox(width: 6),
            Expanded(child: _tab("레저스포츠", _ChatSpotTab.leisure)),
            const SizedBox(width: 6),
            Expanded(child: _tab("쇼핑", _ChatSpotTab.shopping)),
            const SizedBox(width: 6),
            Expanded(child: _tab("숙박", _ChatSpotTab.lodging)),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _hubFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: widget.primary));
              }
              final all = snapshot.data ?? [];
              final filtered = all.where((item) => _classify((item['hubCtgryMclsNm'] ?? '').toString()) == selectedTab).toList();
              filtered.sort((a, b) {
                final ra = int.tryParse((a['hubRank'] ?? '999').toString()) ?? 999;
                final rb = int.tryParse((b['hubRank'] ?? '999').toString()) ?? 999;
                return ra.compareTo(rb);
              });
              if (filtered.isEmpty) {
                return Center(child: Text("해당하는 장소가 없습니다", style: TextStyle(color: Colors.grey.shade500, fontSize: 13)));
              }
              return ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  final name = (item['hubTatsNm'] ?? '').toString();
                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      setState(() {
                        selectedSpot = item;
                        crowdRate = _matchCrowd(name);
                        showDetail = true;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(color: const Color(0xFFF7F7F9), borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
                          Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _tab(String label, _ChatSpotTab tab) {
    final bool selected = selectedTab == tab;
    return GestureDetector(
      onTap: () => setState(() => selectedTab = tab),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? widget.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? widget.primary : Colors.grey.shade200),
        ),
        child: Center(
          child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: selected ? Colors.white : Colors.grey.shade500)),
        ),
      ),
    );
  }

  Widget _buildDetail() {
    final item = selectedSpot!;
    final name = (item['hubTatsNm'] ?? '').toString();
    final catL = (item['hubCtgryLclsNm'] ?? '').toString();
    final catM = (item['hubCtgryMclsNm'] ?? '').toString();
    final mapX = double.tryParse((item['mapX'] ?? '').toString());
    final mapY = double.tryParse((item['mapY'] ?? '').toString());
    final hasLocation = mapX != null && mapY != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => setState(() => showDetail = false),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
            IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: Colors.grey.shade400)),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(color: widget.primary.withOpacity(0.12), shape: BoxShape.circle),
                      child: Icon(_categoryIcon(catL), color: widget.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  children: [
                    Chip(label: Text(catL, style: const TextStyle(fontSize: 12))),
                    if (catM.isNotEmpty && catM != catL) Chip(label: Text(catM, style: const TextStyle(fontSize: 12))),
                    if (crowdRate != null) Chip(label: Text("혼잡도 ${crowdRate!.toStringAsFixed(1)}%", style: const TextStyle(fontSize: 12))),
                  ],
                ),
                if (hasLocation) ...[
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => MapViewPage(lat: mapY, lng: mapX, title: name)));
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        height: 130,
                        child: IgnorePointer(
                          child: WebViewWidget(controller: _getMapController(name, mapY, mapX)),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _sendToChat,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
            label: const Text("채팅방 전송", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}
enum _ReportStep { selectUser, selectReason, confirm }

class _ReportDialogContent extends StatefulWidget {

  final Color primary;
  final int roomId;
  final int reporterId;
  final List<dynamic> members;

  const _ReportDialogContent({
    required this.primary,
    required this.roomId,
    required this.reporterId,
    required this.members,
  });

  @override
  State<_ReportDialogContent> createState() => _ReportDialogContentState();

}

class _ReportDialogContentState extends State<_ReportDialogContent> {

  _ReportStep step = _ReportStep.selectUser;

  Map<String, dynamic>? selectedMember;

  String? selectedReasonType; // 'unpleasant' / 'payment' / 'other'

  final TextEditingController otherReasonController = TextEditingController();

  bool isSubmitting = false;

  bool submitted = false;

  static const Map<String, String> reasonLabels = {
    "unpleasant": "불쾌감 조성 채팅 유저",
    "payment": "금전 거래 불이행",
    "other": "기타",
  };

  @override
  void dispose() {
    otherReasonController.dispose();
    super.dispose();
  }

  bool get canProceedToConfirm {

    if (selectedReasonType == null) return false;

    if (selectedReasonType == "other" && otherReasonController.text.trim().isEmpty) {
      return false;
    }

    return true;

  }

  Future<void> _submitReport() async {

    setState(() => isSubmitting = true);

    try {

      final reportedId = int.tryParse(selectedMember!["user_id"].toString()) ?? 0;

      final response = await http.post(
        Uri.parse("${dotenv.env['PHP_URL']}chat_user_report.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "room_id": widget.roomId,
          "reporter_id": widget.reporterId,
          "reported_id": reportedId,
          "reason_type": selectedReasonType,
          "reason_detail": selectedReasonType == "other" ? otherReasonController.text.trim() : "",
        }),
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (data["success"] == true) {

        setState(() {
          submitted = true;
          isSubmitting = false;
        });

      } else {

        setState(() => isSubmitting = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data["message"] ?? "신고 접수에 실패했습니다")),
        );

      }

    } catch (e) {

      if (!mounted) return;

      setState(() => isSubmitting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("에러 발생: $e")),
      );

    }

  }

  @override
  Widget build(BuildContext context) {

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: submitted ? _buildSubmittedView() : _buildStepView(),
        ),
      ),
    );

  }

  Widget _buildStepView() {

    switch (step) {
      case _ReportStep.selectUser:
        return _buildSelectUserStep();
      case _ReportStep.selectReason:
        return _buildSelectReasonStep();
      case _ReportStep.confirm:
        return _buildConfirmStep();
    }

  }

  Widget _buildHeader(String title, {VoidCallback? onBack}) {

    return Row(
      children: [

        if (onBack != null)
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          )
        else
          const SizedBox(width: 4),

        Expanded(
          child: Text(
            title,
            textAlign: onBack != null ? TextAlign.center : TextAlign.start,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.black87),
          ),
        ),

        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.close_rounded, color: Colors.grey.shade400),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),

      ],
    );

  }

  Widget _buildSelectUserStep() {

    return Column(
      key: const ValueKey('selectUser'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        _buildHeader("신고할 사용자 선택"),

        const SizedBox(height: 16),

        ...widget.members.map((m) {

          final String name = (m["name"] ?? "알 수 없음").toString();

          return InkWell(

            borderRadius: BorderRadius.circular(14),

            onTap: () {
              setState(() {
                selectedMember = Map<String, dynamic>.from(m);
                step = _ReportStep.selectReason;
              });
            },

            child: Container(

              margin: const EdgeInsets.only(bottom: 8),

              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),

              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F9),
                borderRadius: BorderRadius.circular(14),
              ),

              child: Row(
                children: [

                  CircleAvatar(
                    radius: 16,
                    backgroundColor: widget.primary.withOpacity(0.15),
                    child: Text(
                      name.isNotEmpty ? name.substring(0, 1) : "?",
                      style: TextStyle(color: widget.primary, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                  ),

                  Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),

                ],
              ),

            ),

          );

        }),

      ],
    );

  }

  Widget _buildSelectReasonStep() {

    final String name = (selectedMember?["name"] ?? "").toString();

    return Column(
      key: const ValueKey('selectReason'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        _buildHeader(
          "신고 사유 선택",
          onBack: () => setState(() => step = _ReportStep.selectUser),
        ),

        const SizedBox(height: 4),

        Text(
          "$name님을 신고합니다",
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
        ),

        const SizedBox(height: 16),

        ...reasonLabels.entries.map((entry) {

          final bool selected = selectedReasonType == entry.key;

          return InkWell(

            borderRadius: BorderRadius.circular(14),

            onTap: () {
              setState(() {
                selectedReasonType = entry.key;
              });
            },

            child: Container(

              margin: const EdgeInsets.only(bottom: 8),

              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),

              decoration: BoxDecoration(
                color: selected ? widget.primary.withOpacity(0.1) : const Color(0xFFF7F7F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: selected ? widget.primary : Colors.transparent, width: 1.4),
              ),

              child: Row(
                children: [

                  Icon(
                    selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    size: 20,
                    color: selected ? widget.primary : Colors.grey.shade400,
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: selected ? widget.primary : Colors.black87,
                      ),
                    ),
                  ),

                ],
              ),

            ),

          );

        }),

        if (selectedReasonType == "other") ...[

          const SizedBox(height: 4),

          TextField(
            controller: otherReasonController,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: "신고 사유를 자세히 입력해주세요",
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              filled: true,
              fillColor: const Color(0xFFF7F7F9),
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),

        ],

        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: canProceedToConfirm
                ? () => setState(() => step = _ReportStep.confirm)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canProceedToConfirm ? widget.primary : Colors.grey.shade300,
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text("제출", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ),

      ],
    );

  }

  Widget _buildConfirmStep() {

    return Column(
      key: const ValueKey('confirm'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [

        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.flag_rounded, color: Colors.redAccent, size: 26),
        ),

        const SizedBox(height: 16),

        const Text(
          "정말 신고하시겠습니까?",
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.black87),
        ),

        const SizedBox(height: 8),

        Text(
          "허위 신고는 서비스 이용에 제한이 있을 수 있어요",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
        ),

        const SizedBox(height: 24),

        Row(
          children: [

            Expanded(
              child: OutlinedButton(
                onPressed: isSubmitting ? null : () => setState(() => step = _ReportStep.selectReason),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text("아니요", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: ElevatedButton(
                onPressed: isSubmitting ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: isSubmitting
                    ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : const Text("예", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),

          ],
        ),

      ],
    );

  }

  Widget _buildSubmittedView() {

    return Column(
      key: const ValueKey('submitted'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [

        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
        ),

        const SizedBox(height: 16),

        const Text(
          "신고되었습니다! 감사합니다.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87),
        ),

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text("확인", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ),

      ],
    );

  }

}