import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'chat.dart';
import '../tab_widget/widget.dart';
import '../tab_widget/tab_controller.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MyChatPage extends StatefulWidget {
  final int userId;

  const MyChatPage({
    super.key,
    required this.userId,
  });

  @override
  State<MyChatPage> createState() => _MyChatPageState();
}

String formatTimeNoSeconds(String? time) {

  if (time == null) return "";

  final parts = time.split(":");

  if (parts.length >= 2) {
    return "${parts[0]}:${parts[1]}";
  }

  return time;

}

class _MyChatPageState extends State<MyChatPage> {

  static const Color primary = Color(0xFFFF7A00);

  static const Color mealColor = Color(0xFFFFC107); // ⭐ 식사 전용 노란색

  List<dynamic> rooms = [];

  Map<String, List<dynamic>> groupedRooms = {};

  bool isLoading = true;

  String selectedType = "엔빵"; // ⭐ 기본값 엔빵

  @override
  void initState() {

    super.initState();

    loadRooms();

    AppTabController.currentIndex.addListener(_onTabChanged);
    AppTabController.chatRefreshTrigger.addListener(_onRefreshTriggered);

  }

  @override
  void dispose() {

    AppTabController.currentIndex.removeListener(_onTabChanged);
    AppTabController.chatRefreshTrigger.removeListener(_onRefreshTriggered);

    super.dispose();

  }

  void _onTabChanged() {

    if (AppTabController.currentIndex.value == 1) {

      loadRooms();

    }

  }

  void _onRefreshTriggered() {

    loadRooms();

  }

  Future<void> loadRooms() async {
    try {
      final response = await http.get(
        Uri.parse(
          "${dotenv.env['PHP_URL']}mychat2.php?user_id=${widget.userId}",
        ),
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      setState(() {
        if (data["success"] == true) {
          rooms = List<dynamic>.from(data["rooms"]);

          rooms.sort((a, b) {
            DateTime aTime = DateTime.tryParse(a["time"] ?? "") ??
                DateTime(2000);
            DateTime bTime = DateTime.tryParse(b["time"] ?? "") ??
                DateTime(2000);
            return bTime.compareTo(aTime);
          });

          groupedRooms = groupByRegion(rooms);
        } else {
          rooms = [];
          groupedRooms = {};
        }

        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    }
  }

  Map<String, List<dynamic>> groupByRegion(List<dynamic> list) {

    final Map<String, List<dynamic>> map = {};

    for (final room in list) {

      final region = (room["region"] == null || room["region"].toString().isEmpty)
          ? "기타"
          : room["region"].toString();

      map.putIfAbsent(region, () => []);

      map[region]!.add(room);

    }

    return map;

  }

  // ⭐ 채팅방 탭 시 참여 여부 먼저 확인 (강퇴당했는데 목록에 아직 남아있는 경우 대응)
  Future<void> onRoomTap(dynamic room) async {

    try {

      final res = await http.post(
        Uri.parse("${dotenv.env['PHP_URL']}check_room.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "room_id": room["id"],
          "user_id": widget.userId,
        }),
      );

      final data = jsonDecode(res.body);

      final bool isJoined = data["success"] == true && data["isJoined"] == true;

      if (!mounted) return;

      if (isJoined) {

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatPage(
              roomId: room["id"],
              userId: widget.userId,
            ),
          ),
        );

      } else {

        // ⭐ 이미 강퇴당했는데 새로고침 안 해서 목록에 남아있던 경우
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
                    "더 이상 이용할 수 없는 채팅방입니다",
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

        loadRooms(); // ⭐ 목록에서 사라지도록 새로고침

      }

    } catch (e) {

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("에러 : $e")),
      );

    }

  }

  @override
  Widget build(BuildContext context) {

    // ⭐ 1) type 기준으로 먼저 필터링
    final List<dynamic> typeFiltered = rooms.where((room) {

      if (selectedType == "식사") {
        return room["type"] == "식사";
      } else {
        return room["type"] != "식사";
      }

    }).toList();

    // ⭐ 2) 필터링된 목록을 다시 지역별로 그룹핑
    final Map<String, List<dynamic>> filteredGroupedRooms = groupByRegion(typeFiltered);

    return Scaffold(

      backgroundColor: const Color(0xFFF7F7F9),

      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          "내 채팅",
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.black87,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
        backgroundColor: const Color(0xFFF7F7F9),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),

      body: isLoading
          ? Center(
        child: CircularProgressIndicator(
          color: primary,
        ),
      )
          : Column(

        children: [

          // ===== 엔빵/식사 탭 버튼 =====
          Padding(

            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),

            child: Row(

              children: [

                Expanded(
                  child: _TypeTabButton(
                    label: "엔빵",
                    icon: Icons.directions_car_rounded,
                    color: primary,
                    selected: selectedType != "식사",
                    onTap: () {

                      setState(() {
                        selectedType = "엔빵";
                      });

                    },
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: _TypeTabButton(
                    label: "식사",
                    icon: Icons.restaurant_rounded,
                    color: mealColor,
                    selected: selectedType == "식사",
                    onTap: () {

                      setState(() {
                        selectedType = "식사";
                      });

                    },
                  ),
                ),

              ],

            ),

          ),

          const SizedBox(height: 12),

          Expanded(

            child: typeFiltered.isEmpty

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
                    selectedType == "식사"
                        ? "참여중인 식사 채팅방이 없습니다"
                        : "참여중인 엔빵 채팅방이 없습니다",
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )

                : RefreshIndicator(
              color: primary,
              onRefresh: loadRooms,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                children: filteredGroupedRooms.entries.map((entry) {

                  final region = entry.key;

                  final regionRooms = entry.value;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 16,
                              color: primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              region,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "${regionRooms.length}",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                      ),

                      ...regionRooms.map((room) => _RoomCard(
                        room: room,
                        primary: primary,
                        onTap: () => onRoomTap(room),
                      )),

                      const SizedBox(height: 8),

                    ],
                  );

                }).toList(),
              ),
            ),

          ),

        ],

      ),

      bottomNavigationBar: BottomWidget(
        userId: widget.userId,
      ),
    );
  }
}

// ⭐ 엔빵/식사 탭 버튼 위젯
class _TypeTabButton extends StatelessWidget {

  final String label;

  final IconData icon;

  final Color color;

  final bool selected;

  final VoidCallback onTap;

  const _TypeTabButton({

    required this.label,

    required this.icon,

    required this.color,

    required this.selected,

    required this.onTap,

  });

  @override
  Widget build(BuildContext context) {

    return GestureDetector(

      onTap: onTap,

      child: AnimatedContainer(

        duration: const Duration(milliseconds: 200),

        padding: const EdgeInsets.symmetric(vertical: 12),

        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : Colors.grey.shade200,
            width: 1.4,
          ),
          boxShadow: selected
              ? [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ]
              : [],
        ),

        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            Icon(
              icon,
              size: 18,
              color: selected ? Colors.white : Colors.grey.shade500,
            ),

            const SizedBox(width: 6),

            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : Colors.grey.shade500,
              ),
            ),

          ],
        ),

      ),

    );

  }

}

class _RoomCard extends StatelessWidget {

  final dynamic room;

  final Color primary;

  final VoidCallback onTap;

  static const Color mealColor = Color(0xFFFFC107);

  const _RoomCard({
    required this.room,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {

    final String type = (room["type"] ?? "").toString();

    final bool isMeal = type == "식사";

    final Color accentColor = isMeal ? mealColor : primary;

    final bool isQuickMatch = room["user_id"] == null; // ⭐ 방장 없는 GPS 매칭방 판별

    final int unreadCount = (room["unread_count"] ?? 0) is int // ⭐ 추가
        ? room["unread_count"]
        : int.tryParse(room["unread_count"].toString()) ?? 0;

    final String? rawLastMessage = room["last_message"] as String?;

    final String lastMessageType = (room["last_message_type"] ?? "text").toString();

    final bool isLastMessageSystem = room["last_message_user_id"] == null;

// ⭐ 정산 메시지(SETTLEMENT|금액|인원|1인당)는 자연스러운 문구로 변환
    final String? lastMessage;

    if (rawLastMessage != null && rawLastMessage.startsWith("SETTLEMENT|")) {

      lastMessage = "정산 요청이 도착";

    } else if (lastMessageType == "image") {

      lastMessage = "사진을 보냈습니다";

    } else if (lastMessageType == "location") {

      lastMessage = "위치를 공유했습니다";

    } else {

      lastMessage = rawLastMessage;

    }

    final int currentPeople = (room["current_people"] ?? 0) is int
        ? room["current_people"]
        : int.tryParse(room["current_people"].toString()) ?? 0;

    final int maxPeople = (room["people"] ?? 0) is int
        ? room["people"]
        : int.tryParse(room["people"].toString()) ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Stack(
            children: [

        Padding(
        padding: const EdgeInsets.all(16),
        child: Row(

          crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              // ===== 왼쪽 타입 아이콘 (카카오톡 프로필 이미지 자리) =====
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  type,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w800,
                    fontSize: type.length >= 3 ? 13 : 16,
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // ===== 오른쪽 정보 영역 =====
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // 상단: 출발지 > 도착지 (+ 빠른매칭 표시)
                    Row(
                      children: [

                        if (room["start"] != null) ...[

                          Flexible(
                            child: Text(
                              "${room["start"]}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              size: 12,
                              color: Colors.grey.shade400,
                            ),
                          ),

                        ],

                        Flexible(
                          child: Text(
                            "${room["end"] ?? ""}",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: accentColor,
                            ),
                          ),
                        ),

                        if (isQuickMatch) ...[

                          const SizedBox(width: 6),

                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              "빠른매칭",
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.blueAccent,
                              ),
                            ),
                          ),

                        ],

                      ],
                    ),

                    const SizedBox(height: 6),
                    if (lastMessage != null && lastMessage.isNotEmpty)

                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          isLastMessageSystem ? "· $lastMessage" : lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: isLastMessageSystem ? Colors.grey.shade400 : Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                            fontStyle: isLastMessageSystem ? FontStyle.italic : FontStyle.normal,
                          ),
                        ),
                      ),


                    // 하단: 시간 + 인원 뱃지
                    Row(
                      children: [

                        Icon(
                          Icons.schedule_rounded,
                          size: 13,
                          color: Colors.grey.shade400,
                        ),

                        const SizedBox(width: 4),

                        Expanded(
                          child: Builder(
                            builder: (context) {

                              final bool hasTime = room["time"] != null && room["time"].toString().isNotEmpty;

                              // ⭐ 빠른매칭 방은 시간이 없어도 "시간 조율" 문구를 표시하지 않음
                              if (!hasTime && isQuickMatch) {
                                return const SizedBox.shrink();
                              }

                              return Text(
                                hasTime ? formatTimeNoSeconds(room["time"].toString()) : "시간 조율",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11, // ⭐ 12 -> 11로 축소
                                  color: hasTime ? Colors.green.shade600 : Colors.grey.shade500,
                                  fontWeight: hasTime ? FontWeight.w700 : FontWeight.w500,
                                ),
                              );

                            },
                          ),
                        ),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F7F9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.person_rounded,
                                size: 10,
                                color: Colors.black45,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                "$currentPeople/$maxPeople",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 9,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),

                      ],
                    ),

                  ],
                ),
              ),
              if (unreadCount > 0)

                Positioned(

                  top: 10,

                  right: 10,

                  child: Container(

                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),

                    constraints: const BoxConstraints(minWidth: 20),

                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(20),
                    ),

                    child: Text(

                      unreadCount > 99 ? "99+" : "$unreadCount",

                      textAlign: TextAlign.center,

                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),

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

}