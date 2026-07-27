import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'create/start.dart';
import 'chat/chat.dart';
import 'tab_widget/widget.dart';
import 'create/end2.dart'; // ⭐ import 추가
import 'package:flutter_dotenv/flutter_dotenv.dart';


class RoomPage extends StatefulWidget {

  final int userId;

  final String roomTable;

  final String roomTitle;

  const RoomPage({
    super.key,
    required this.userId,
    required this.roomTable,
    required this.roomTitle,
  });

  @override
  State<RoomPage> createState()
  => _RoomPageState();
}

class _RoomPageState
    extends State<RoomPage>{

  List<dynamic> rooms = [];

  bool loading=true;

  static const Color primary = Color(0xFFFF7A00);

  static const Color mealColor = Color(0xFFFFC107); // ⭐ 식사 전용 노란색

  Set<String> joinedRoomIds = {};

  String selectedType = "엔빵"; // ⭐ 기본값 엔빵

  final TextEditingController searchController = TextEditingController(); // ⭐ 검색어

  String searchQuery = "";

  String formatTimeNoSeconds(String? time) {

    if (time == null) return "";

    final parts = time.split(":");

    if (parts.length >= 2) {
      return "${parts[0]}:${parts[1]}";
    }

    return time;

  }

  @override
  void initState() {

    super.initState();

    loadRooms();

  }

  @override
  void dispose() {

    searchController.dispose();

    super.dispose();

  }

  Future<void> loadRooms() async {

    setState(() {
      loading = true;
    });

    try {

      final response =
      await http.get(

        Uri.parse(
          "${dotenv.env['PHP_URL']}room.php?table=${widget.roomTable}",
        ),

      );

      final data =
      jsonDecode(
        response.body,
      );

      if (!mounted) return;

      if (data["success"] == true) {

        rooms =
        List<dynamic>.from(
          data["rooms"] ?? [],
        );

        rooms.sort((a, b) {

          final aMine =
              a["user_id"].toString()
                  ==
                  widget.userId.toString();

          final bMine =
              b["user_id"].toString()
                  ==
                  widget.userId.toString();

          if (
          aMine == bMine
          ) {
            return 0;
          }

          return aMine
              ? -1
              : 1;

        });

      } else {

        rooms = [];
      }

      // 방 목록을 불러온 뒤, 각 방에 대해 내가 참여중인지 확인 (check_room.php 그대로 사용)
      await loadJoinedStatus();

      if (!mounted) return;

      setState(() {
        loading = false;
      });

    } catch (e) {

      if (!mounted) return;

      setState(() {
        loading = false;
      });

    }

  }

  Future<void> loadJoinedStatus() async {

    final Set<String> joined = {};

    await Future.wait(

      rooms.map((room) async {

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

          if (data["success"] == true && data["isJoined"] == true) {

            joined.add(room["id"].toString());

          }

        } catch (e) {

          // 개별 방 조회 실패는 무시하고 넘어감

        }

      }),

    );

    joinedRoomIds = joined;

  }

  void showMenuPopup(){

    showModalBottomSheet(

      context: context,

      backgroundColor: Colors.transparent,

      builder: (_){

        return Container(

          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),

          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(28),
            ),
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

              const Text(
                "무엇을 만들까요?",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 20),

              _MenuTile(
                icon: Icons.directions_car_rounded,
                label: "엔빵",
                subtitle: "교통비를 나눠서 정산해요",
                color: primary,
                onTap: (){

                  Navigator.pop(context);

                  Navigator.push(

                    context,

                    MaterialPageRoute(

                      builder: (_) => StartPage(
                        userId: widget.userId,
                        type: "엔빵",
                        roomTable: widget.roomTable,
                      ),

                    ),

                  ).then((_) {

                    loadRooms();

                  });

                },
              ),

              const SizedBox(height: 12),

              _MenuTile(
                icon: Icons.restaurant_rounded,
                label: "식사",
                subtitle: "식비를 나눠서 정산해요",
                color: mealColor, // ⭐ 노란색으로 변경

                onTap: (){

                  Navigator.pop(context);

                  Navigator.push(

                    context,

                    MaterialPageRoute(

                      builder: (_) => End2Page( // ⭐ StartPage 건너뛰고 바로 End2Page로
                        userId: widget.userId,
                        type: "식사",
                        roomTable: widget.roomTable,
                      ),

                    ),

                  ).then((_) {

                    loadRooms();

                  });

                },
              ),

            ],

          ),

        );

      },

    );

  }

  Future<void> onRoomTap(dynamic room) async {

    final pageContext = context;

    // 1️⃣ 먼저 참여 여부만 확인 (INSERT 없음)
    final checkRes = await http.post(
      Uri.parse("${dotenv.env['PHP_URL']}check_room.php"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "room_id": room["id"],
        "user_id": widget.userId,
      }),
    );

    final checkData = jsonDecode(checkRes.body);

    if (checkData["success"] != true) {

      if (!mounted) return;

      _showInfoDialog(
        icon: Icons.error_outline_rounded,
        iconColor: Colors.redAccent,
        title: "오류",
        content: "잠시 후 다시 시도해주세요",
        confirmText: "확인",
        onConfirm: () {
          Navigator.pop(context);
          loadRooms();
        },

      );

      return;
    }

    final bool isJoined = checkData["isJoined"] == true;

    if (!mounted) return;

    if (isJoined) {

      // 2️⃣ 이미 참여중인 경우 - 확인 누르면 그냥 팝업만 닫힘 (이동 X)
      _showInfoDialog(
        icon: Icons.info_outline_rounded,
        iconColor: primary,
        title: "알림",
        content: "이미 참여중인 채팅방입니다",
        confirmText: "확인",
        onConfirm: () {
          Navigator.pop(context);
        },
      );

      return;

    }

    // 3️⃣ 미참여인 경우 - 정원이 이미 가득 찼는지 먼저 확인 (목록에서 받아온 값 기준)
    final int currentPeople = (room["current_people"] ?? 0) is int
        ? room["current_people"]
        : int.tryParse(room["current_people"].toString()) ?? 0;

    final int maxPeople = (room["people"] ?? 0) is int
        ? room["people"]
        : int.tryParse(room["people"].toString()) ?? 0;

    if (currentPeople >= maxPeople) {

      _showInfoDialog(
        icon: Icons.lock_outline_rounded,
        iconColor: Colors.redAccent,
        title: "정원 마감",
        content: "정원이 가득 찼습니다",
        confirmText: "확인",
        onConfirm: () => Navigator.pop(context),
      );

      return;

    }

    // 4️⃣ 정원 여유 있는 경우 - 참여 여부 확인 팝업
    showDialog(
      context: context,
      useRootNavigator: false, // ⭐ 추가: 현재 홈 탭 Navigator에 다이얼로그를 붙임
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
                  Icons.groups_rounded,
                  color: primary,
                  size: 28,
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                "채팅방 참여",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                "채팅방에 참여하시겠습니까?",
                textAlign: TextAlign.center,
                style: TextStyle(
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
                      onPressed: () async {

                        Navigator.pop(context);

                        final joinRes = await http.post(
                          Uri.parse("${dotenv.env['PHP_URL']}join_room.php"),
                          headers: {"Content-Type": "application/json"},
                          body: jsonEncode({
                            "room_id": room["id"],
                            "user_id": widget.userId,
                          }),
                        );

                        final joinData = jsonDecode(joinRes.body);

                        if (joinData["success"] == true) {

                          if (!mounted) return;

                          Navigator.push(
                            pageContext,
                            MaterialPageRoute(
                              builder: (_) => ChatPage(
                                roomId: room["id"],
                                userId: widget.userId,
                              ),
                            ),
                          );

                        } else if (joinData["full"] == true) {

                          // 서버에서도 정원 초과로 최종 거부된 경우 (동시 참여 등 엣지케이스)
                          if (!mounted) return;

                          _showInfoDialog(
                            icon: Icons.lock_outline_rounded,
                            iconColor: Colors.redAccent,
                            title: "정원 마감",
                            content: "정원이 가득 찼습니다",
                            confirmText: "확인",
                            onConfirm: () {
                              Navigator.pop(context);
                              loadRooms();
                            },
                          );

                        } else {

                          if (!mounted) return;

                          _showInfoDialog(
                            icon: Icons.error_outline_rounded,
                            iconColor: Colors.redAccent,
                            title: "입장 실패",
                            content: "다시 시도해주세요",
                            confirmText: "확인",
                            onConfirm: () {
                              Navigator.pop(context);
                              loadRooms();
                            },
                          );
                        }
                      },
                      child: const Text(
                        "참여",
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

  void _showInfoDialog({

    required IconData icon,

    required Color iconColor,

    required String title,

    required String content,

    required String confirmText,

    required VoidCallback onConfirm,

  }) {

    showDialog(
      context: context,
      useRootNavigator: false, // ⭐ 추가: 현재 홈 탭 Navigator에 다이얼로그를 붙임
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
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 28,
                ),
              ),

              const SizedBox(height: 16),

              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                content,
                textAlign: TextAlign.center,
                style: const TextStyle(
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
                  onPressed: onConfirm,
                  child: Text(
                    confirmText,
                    style: const TextStyle(
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

  }

  @override
  Widget build(
      BuildContext context
      ){

    final Color accentColor = selectedType == "식사" ? mealColor : primary; // ⭐ 현재 선택된 탭 색상

    // ⭐ 1) type으로 먼저 필터링
    final List<dynamic> typeFiltered = rooms.where((room) {

      if (selectedType == "식사") {
        return room["type"] == "식사";
      } else {
        return room["type"] != "식사";
      }

    }).toList();

    // ⭐ 2) 검색어로 출발지 또는 목적지 필터링
    final String query = searchQuery.trim();

    final List<dynamic> filteredRooms = query.isEmpty
        ? typeFiltered
        : typeFiltered.where((room) {

      final String start = (room["start"] ?? "").toString().toLowerCase();
      final String end = (room["end"] ?? "").toString().toLowerCase();

      final String q = query.toLowerCase();

      return start.contains(q) || end.contains(q);

    }).toList();

    return Scaffold(

      backgroundColor: const Color(0xFFF7F7F9),

      appBar: AppBar(

        title: Text(
          widget.roomTitle,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.black87,
            fontSize: 18,
          ),
        ),

        centerTitle: false,

        backgroundColor: const Color(0xFFF7F7F9),

        elevation: 0,

        surfaceTintColor: Colors.transparent,

        iconTheme: const IconThemeData(color: Colors.black87),

        actions: [

          IconButton(
            onPressed: loadRooms,
            icon: const Icon(Icons.refresh_rounded),
          ),

        ],

      ),

      body:

      loading

          ?

      Center(
        child: CircularProgressIndicator(
          color: primary,
        ),
      )

          :

      Column(

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
                        searchController.clear();
                        searchQuery = "";
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
                        searchController.clear();
                        searchQuery = "";
                      });

                    },
                  ),
                ),

              ],

            ),

          ),

          const SizedBox(height: 12),

          // ===== 검색창 =====
          Padding(

            padding: const EdgeInsets.symmetric(horizontal: 16),

            child: Container(

              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),

              child: TextField(

                controller: searchController,

                onChanged: (value) {

                  setState(() {
                    searchQuery = value;
                  });

                },

                decoration: InputDecoration(

                  hintText: selectedType == "식사"
                      ? "식사 장소로 검색 (출발지/목적지)"
                      : "출발지 또는 목적지로 검색",

                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 13,
                  ),

                  prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 20),

                  suffixIcon: searchQuery.isEmpty
                      ? null
                      : IconButton(
                    icon: Icon(Icons.close_rounded, color: Colors.grey.shade400, size: 18),
                    onPressed: () {

                      setState(() {
                        searchController.clear();
                        searchQuery = "";
                      });

                    },
                  ),

                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),

                  contentPadding: const EdgeInsets.symmetric(vertical: 12),

                ),

              ),

            ),

          ),

          const SizedBox(height: 8),

          // ===== 방 목록 =====
          Expanded(

            child: filteredRooms.isEmpty

                ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    query.isEmpty ? Icons.map_outlined : Icons.search_off_rounded,
                    size: 56,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    query.isEmpty
                        ? "아직 채팅방이 없어요"
                        : "검색 결과가 없어요",
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )

                : GridView.builder(

              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),

              itemCount: filteredRooms.length,

              gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(

                crossAxisCount:
                2,

                mainAxisSpacing:
                14,

                crossAxisSpacing:
                14,

                childAspectRatio:
                0.95,

              ),

              itemBuilder:
                  (
                  context,
                  index
                  ){

                final room = filteredRooms[index];

                return _buildRoomCard(room, accentColor);

              },

            ),

          ),

        ],

      ),
      bottomNavigationBar:

      BottomWidget(
        userId: widget.userId,
      ),

      floatingActionButton:

      Container(

        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: primary.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),

        child: FloatingActionButton(

          onPressed:
          showMenuPopup,

          backgroundColor:
          primary,

          elevation: 0,

          child:
          const Icon(
            Icons.add_rounded,
            size: 28,
          ),

        ),

      ),

    );

  }

  // ⭐ 카드 위젯을 색상 파라미터를 받는 함수로 분리 (엔빵=primary, 식사=mealColor)
  Widget _buildRoomCard(dynamic room, Color accentColor) {

    final isMine =
        room["user_id"]
            .toString()
            ==
            widget.userId.toString();

    final isJoined =
    joinedRoomIds.contains(room["id"].toString());

    final int currentPeople = (room["current_people"] ?? 0) is int
        ? room["current_people"]
        : int.tryParse(room["current_people"].toString()) ?? 0;

    final int maxPeople = (room["people"] ?? 0) is int
        ? room["people"]
        : int.tryParse(room["people"].toString()) ?? 0;

    final bool isFull = currentPeople >= maxPeople;

    return GestureDetector(

      onTap: () => onRoomTap(room),

      child: Container(

        decoration: BoxDecoration(

          color: Colors.white,

          borderRadius: BorderRadius.circular(20),

          border: isJoined
              ? Border.all(color: accentColor.withOpacity(0.5), width: 1.4)
              : Border.all(color: Colors.transparent),

          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],

        ),

        child: Stack(

          children: [

            Padding(

              padding: const EdgeInsets.all(16),

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  Row(
                    children: [

                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isJoined
                              ? accentColor.withOpacity(0.12)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(

                          room["type"],

                          style: TextStyle(

                            fontSize: 11,

                            color:
                            isJoined
                                ? accentColor
                                : Colors.grey.shade600,

                            fontWeight: FontWeight.w700,

                          ),

                        ),
                      ),

                      if (isMine) ...[

                        const SizedBox(width: 6),

                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(

                            "방장",

                            style: TextStyle(

                              fontSize: 11,

                              color: accentColor,

                              fontWeight: FontWeight.w700,

                            ),

                          ),
                        ),

                      ],

                    ],
                  ),

                  const Spacer(),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      if (room["start"] != null) ...[

                        Text(
                          "${room["start"]}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black45,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 2),
                          child: Icon(
                            Icons.arrow_downward_rounded,
                            size: 14,
                            color: Colors.black26,
                          ),
                        ),

                      ],

                      Text(
                        "${room["end"]}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                    ],
                  ),

                  const Spacer(),

                  Row(

                    children: [

                      Expanded(

                        child: Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 13,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                room["time"] == null
                                    ? "시간 조율"
                                    : formatTimeNoSeconds(room["time"]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: room["time"] == null
                                      ? Colors.grey.shade500
                                      : Colors.green.shade600,
                                  fontWeight: room["time"] == null
                                      ? FontWeight.w500
                                      : FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),

                      ),

                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isFull
                              ? Colors.redAccent.withOpacity(0.1)
                              : const Color(0xFFF7F7F9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.person_rounded,
                              size: 12,
                              color: isFull
                                  ? Colors.redAccent
                                  : Colors.black45,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              "$currentPeople/$maxPeople",
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                color: isFull
                                    ? Colors.redAccent
                                    : Colors.black54,
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

            if (isFull)
              Positioned(

                top: 0,
                right: 0,

                child: Container(

                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),

                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(14),
                    ),
                  ),

                  child: const Text(

                    "마감",

                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),

                  ),

                ),

              ),

          ],

        ),

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

class _MenuTile extends StatelessWidget {

  final IconData icon;

  final String label;

  final String subtitle;

  final Color color;

  final VoidCallback onTap;

  const _MenuTile({

    required this.icon,

    required this.label,

    required this.subtitle,

    required this.color,

    required this.onTap,

  });

  @override
  Widget build(BuildContext context) {

    return InkWell(

      borderRadius: BorderRadius.circular(18),

      onTap: onTap,

      child: Container(

        padding: const EdgeInsets.all(16),

        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F9),
          borderRadius: BorderRadius.circular(18),
        ),

        child: Row(
          children: [

            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),

                ],
              ),
            ),

            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey.shade400,
            ),

          ],
        ),

      ),

    );

  }

}