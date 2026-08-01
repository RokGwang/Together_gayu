import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'mychat.dart';
import '../tab_widget/tab_controller.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../socket_service.dart';

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

  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final TextEditingController amountController = TextEditingController();

  List<dynamic> messages = [];

  Map<String, dynamic>? roomInfo;

  bool isLoading = true;
  bool isSending = false;
  bool isSettling = false;

  int lastMessageId = 0;

  bool roomDeletedHandled = false;

  bool kickedHandled = false; // ⭐ 강제 퇴장 중복 처리 방지

  Timer? pollTimer;

  @override
  void initState() {

    super.initState();

    loadMessages(initial: true);

    // ⭐ 소켓 연결 후 이 방에 join
    SocketService.instance.connect();
    SocketService.instance.joinRoom(widget.roomId, widget.userId);

    // ⭐ 실시간 새 메시지 수신
    SocketService.instance.onNewMessage((data) {

      if (!mounted) return;

      final newMsg = Map<String, dynamic>.from(data);

      // 이미 REST로 받아온 메시지와 중복되지 않도록 id 체크
      final alreadyExists = messages.any((m) => m["id"].toString() == newMsg["id"].toString());

      if (alreadyExists) return;

      setState(() {
        messages.add(newMsg);
        lastMessageId = int.tryParse(newMsg["id"].toString()) ?? lastMessageId;
      });

      scrollToBottom();

    });

    // ⭐ 방장이 강제 퇴장/나가기/마감/정산 등 이벤트 발생 시 -> 가볍게 REST 재조회로 상태 갱신
    for (final event in ["member_kicked", "member_left", "dead_toggled", "settlement_created"]) {

      SocketService.instance.onRoomEvent(event, (_) {
        loadMessages(initial: false);
      });

    }

    SocketService.instance.onRoomEvent("room_deleted", (_) {
      loadMessages(initial: false);
    });

    // ⭐ 안전망: 소켓이 끊겼을 경우를 대비한 저빈도 폴백 폴링 (30초)
    pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      loadMessages(initial: false);
    });

  }

  @override
  void dispose() {

    pollTimer?.cancel();
    messageController.dispose();
    scrollController.dispose();
    amountController.dispose();

    SocketService.instance.socket?.off('new_message');
    SocketService.instance.socket?.off('member_kicked');
    SocketService.instance.socket?.off('member_left');
    SocketService.instance.socket?.off('dead_toggled');
    SocketService.instance.socket?.off('settlement_created');
    SocketService.instance.socket?.off('room_deleted');

    super.dispose();
  }

  Future<void> loadMessages({required bool initial}) async {

    if (roomDeletedHandled || kickedHandled) return;

    try {

      final response = await http.get(

        Uri.parse(
          "${dotenv.env['PHP_URL']}chat.php"
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

          // 방장이 나가서 방이 삭제된 경우
          if (!roomDeletedHandled) {

            roomDeletedHandled = true;

            handleRoomDeleted();

          }

          return;

        }

        // ⭐ 강제 퇴장 감지: 방은 존재하지만 내가 더 이상 room_member가 아님
        if (data["isMember"] == false) {

          if (!kickedHandled) {

            kickedHandled = true;

            handleKicked();

          }

          return;

        }

        final newMessages = List<dynamic>.from(data["messages"] ?? []);

        setState(() {

          roomInfo = data["room"];

          if (initial) {
            messages = newMessages;
          } else if (newMessages.isNotEmpty) {
            messages.addAll(newMessages);
          }

          if (messages.isNotEmpty) {
            lastMessageId =
                int.tryParse(messages.last["id"].toString()) ?? lastMessageId;
          }

          isLoading = false;

        });

        if (initial || newMessages.isNotEmpty) {
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

  Future<void> handleRoomDeleted() async {

    pollTimer?.cancel();

    if (!mounted) return;

    await showDialog(
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
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.redAccent,
                  size: 28,
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                "방이 사라졌습니다",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                "방장이 채팅방을 나가 더 이상 이용할 수 없습니다",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
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
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

            ],
          ),
        ),
      ),
    );

    if (!mounted) return;

    goToMyChat();

  }

  // ⭐ 강제 퇴장 처리
  Future<void> handleKicked() async {

    pollTimer?.cancel();

    if (!mounted) return;

    await showDialog(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
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
                child: const Icon(
                  Icons.person_remove_rounded,
                  color: Colors.redAccent,
                  size: 28,
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                "채팅방에서 퇴장당하셨습니다",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                "방장에 의해 채팅방에서 제외되었습니다",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
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
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

            ],
          ),
        ),
      ),
    );

    if (!mounted) return;

    goToMyChat();

  }

  void scrollToBottom() {

    WidgetsBinding.instance.addPostFrameCallback((_) {

      if (!scrollController.hasClients) return;

      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
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

      if (SocketService.instance.isConnected) {

        // ⭐ 소켓이 연결되어 있으면 실시간 전송
        SocketService.instance.sendMessage(widget.roomId, widget.userId, text);

        messageController.clear();

      } else {

        // ⭐ 소켓 연결이 안 되어 있으면 기존 REST 방식으로 대체 (안전망)
        final response = await http.post(

          Uri.parse("http://34.22.87.81/together/send_message.php"),

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

  Future<void> showSettlementDialog() async {

    if (roomInfo == null) return;

    amountController.clear();

    await showDialog(
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
                  color: primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.calculate_rounded,
                  color: primary,
                  size: 28,
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                "정산하기",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                "현재 참여 인원 ${roomInfo!["current_people"]}명 기준으로\n금액을 나눠드려요",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                ),
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

              const SizedBox(height: 24),

              Row(
                children: [

                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "취소",
                        style: TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {

                        Navigator.pop(context);

                        sendSettlement();

                      },
                      child: const Text(
                        "확인",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
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
          "people": roomInfo!["current_people"],
        }),

      );

      final data = jsonDecode(response.body);

      if (data["success"] == true) {

        await loadMessages(initial: false);

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

  Future<List<dynamic>> fetchMembers() async {

    try {

      final response = await http.get(
        Uri.parse(
          "${dotenv.env['PHP_URL']}room_member.php?room_id=${widget.roomId}",
        ),
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
      roomInfo != null &&
          roomInfo!["user_id"].toString() == widget.userId.toString();

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

  // ⭐ 강제 퇴장 API 호출
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

  // ⭐ 강제 퇴장 확인 팝업
  Future<void> confirmKick(String memberName, int targetUserId) async {

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
                child: const Icon(
                  Icons.person_remove_rounded,
                  color: Colors.redAccent,
                  size: 28,
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                "강제 퇴장",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                "$memberName님을 채팅방에서 강제 퇴장시키겠습니까?",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text(
                        "취소",
                        style: TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        "확인",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
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

    if (confirmed != true) return;

    final success = await kickMember(targetUserId);

    if (!mounted) return;

    if (success) {

      Navigator.pop(context); // 참여자 시트 닫기

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
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),

                  const SizedBox(height: 16),

                  ConstrainedBox(

                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                    ),

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

                        final int memberUserId =
                            int.tryParse(member["user_id"].toString()) ?? 0;

                        return Row(
                          children: [

                            CircleAvatar(
                              radius: 18,
                              backgroundColor: primary.withOpacity(0.15),
                              child: Text(
                                name.isNotEmpty ? name.substring(0, 1) : "?",
                                style: TextStyle(
                                  color: primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),

                            const SizedBox(width: 12),

                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
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
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: primary,
                                  ),
                                ),
                              ),

                            // ⭐ 방장 전용 강제 퇴장 버튼 (본인/방장 본인 행에는 표시 안 함)
                            if (isOwner && !memberIsOwner) ...[

                              const SizedBox(width: 6),

                              IconButton(

                                onPressed: () => confirmKick(name, memberUserId),

                                icon: const Icon(
                                  Icons.remove_circle_outline_rounded,
                                  color: Colors.redAccent,
                                  size: 22,
                                ),

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
                                Text(
                                  "채팅방 마감",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  localDead ? "목록에서 숨겨진 상태예요" : "목록에 정상적으로 노출돼요",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        leaveRoom();
                      },
                      icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                      label: const Text(
                        "채팅방 나가기",
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w700,
                        ),
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
                child: Icon(
                  ownerLeaving
                      ? Icons.delete_outline_rounded
                      : Icons.logout_rounded,
                  color: Colors.redAccent,
                  size: 28,
                ),
              ),

              const SizedBox(height: 16),

              Text(
                ownerLeaving ? "채팅방 삭제" : "채팅방 나가기",
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                ownerLeaving
                    ? "방장이 나가면 채팅방이 모든 참여자에게서 삭제됩니다.\n정말 나가시겠습니까?"
                    : "채팅방을 나가면 대화 내용을 다시 볼 수 없습니다",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text(
                        "취소",
                        style: TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(
                        ownerLeaving ? "삭제" : "나가기",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
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

    if (confirmed != true) return;

    if (ownerLeaving) {
      // 방장 퇴장(=방 삭제)은 본인도 더 이상 폴링할 필요가 없으므로 타이머 정지
      pollTimer?.cancel();
    }

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

  String formatTimeNoSeconds(String? time) {

    if (time == null) return "";

    // "YYYY-MM-DD HH:MM:SS" -> "YYYY-MM-DD HH:MM"
    final parts = time.split(":");

    if (parts.length >= 2) {
      return "${parts[0]}:${parts[1]}";
    }

    return time;

  }

  String formatDateSeparator(String? createdAt) {

    if (createdAt == null) return "";

    final dt = DateTime.tryParse(createdAt);

    if (dt == null) return "";

    return "${dt.year}년 ${dt.month}월 ${dt.day}일";

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
    return isSystemMessage(msg) &&
        (msg["message"] ?? "").toString().startsWith("SETTLEMENT|");
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
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                  fontSize: 15,
                ),
              ),

              Row(
                children: [
                  Text(
                    roomInfo!["time"] == null
                        ? "시간 조율"
                        : formatTimeNoSeconds(roomInfo!["time"]),
                    style: TextStyle(
                      fontSize: 11,
                      color: roomInfo!["time"] == null
                          ? Colors.grey.shade500
                          : Colors.green.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
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

                  ? Center(
                child: CircularProgressIndicator(color: primary),
              )

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
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )

                  : ListView.builder(

                controller: scrollController,

                padding: const EdgeInsets.fromLTRB(15, 15, 15, 15),

                itemCount: messages.length,

                itemBuilder: (context, index) {

                  final msg = messages[index];

                  final bool isSystem = isSystemMessage(msg);

                  final bool isSettlement = isSettlementMessage(msg);

                  final prevMsg = index > 0 ? messages[index - 1] : null;

                  final showDateSeparator = prevMsg == null ||
                      !isSameDate(prevMsg["created_at"], msg["created_at"]);

                  // ===== 정산 메시지 (전용 카드) =====
                  if (isSettlement) {

                    final parts = (msg["message"] as String).split("|");

                    final amount = int.tryParse(parts.length > 1 ? parts[1] : "0") ?? 0;
                    final people = int.tryParse(parts.length > 2 ? parts[2] : "1") ?? 1;
                    final perPerson = int.tryParse(parts.length > 3 ? parts[3] : "0") ?? 0;

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
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w600,
                                  ),
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
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
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
                                      decoration: BoxDecoration(
                                        color: primary.withOpacity(0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.calculate_rounded,
                                        size: 16,
                                        color: primary,
                                      ),
                                    ),

                                    const SizedBox(width: 8),

                                    const Text(
                                      "정산 요청",
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black87,
                                      ),
                                    ),

                                  ],
                                ),

                                const SizedBox(height: 12),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "총 금액",
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                    ),
                                    Text(
                                      "${formatCurrency(amount)}원",
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 4),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "인원",
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                    ),
                                    Text(
                                      "$people명",
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black87,
                                      ),
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
                                      Text(
                                        "1인당",
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "${formatCurrency(perPerson)}원",
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 12),

                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      // 아직 기능 없음 (추후 구현 예정)
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primary,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                                    label: const Text(
                                      "송금하기",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),

                              ],
                            ),

                          ),

                        ),

                      ],
                    );

                  }

                  // ===== 일반 시스템 메시지 (입장/퇴장/강퇴 알림) =====
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
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w600,
                                  ),
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
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),

                      ],
                    );

                  }

                  final isMine =
                      msg["user_id"].toString() == widget.userId.toString();

                  final isSameSenderAsPrev = prevMsg != null &&
                      !showDateSeparator &&
                      !isSystemMessage(prevMsg) &&
                      prevMsg["user_id"].toString() == msg["user_id"].toString();

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
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),

                      Padding(
                        padding: EdgeInsets.only(top: isSameSenderAsPrev ? 3 : 12),
                        child: Row(

                          mainAxisAlignment: isMine
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,

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
                                  style: TextStyle(
                                    color: primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),

                              const SizedBox(width: 8),

                            ],

                            Flexible(
                              child: Column(
                                crossAxisAlignment: isMine
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [

                                  if (!isMine && !isSameSenderAsPrev)

                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 3, left: 2),
                                      child: Text(
                                        msg["name"] ?? "",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ),

                                  Row(

                                    mainAxisSize: MainAxisSize.min,

                                    crossAxisAlignment: CrossAxisAlignment.end,

                                    children: [

                                      if (isMine) ...[

                                        Text(
                                          formatTime(msg["created_at"]),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade400,
                                          ),
                                        ),

                                        const SizedBox(width: 6),

                                      ],

                                      Flexible(
                                        child: Container(

                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 10,
                                          ),

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

                                          child: Text(
                                            msg["message"] ?? "",
                                            style: TextStyle(
                                              color: isMine ? Colors.white : Colors.black87,
                                              fontSize: 14,
                                              height: 1.3,
                                            ),
                                          ),

                                        ),
                                      ),

                                      if (!isMine) ...[

                                        const SizedBox(width: 6),

                                        Text(
                                          formatTime(msg["created_at"]),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade400,
                                          ),
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

                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
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
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                            : const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),

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