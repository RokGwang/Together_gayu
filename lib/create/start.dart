import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'end.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../up.dart';

class StartPage extends StatefulWidget {

  final int userId;

  final String type;
  final String roomTable;

  const StartPage({
    super.key,
    required this.userId,
    required this.type,
    required this.roomTable,
  });

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {

  static const Color primary = Color(0xFFFF7A00);

  List<dynamic> places = [];

  int selectedIndex = -1;

  bool isLoading = true;

  @override
  void initState() {

    super.initState();

    loadPlaces();

    WidgetsBinding.instance.addPostFrameCallback((_) {

      OnboardingPopup.showOnce(
        context: context,
        userId: widget.userId,
        popupKey: "start",
        title: "엔빵 채팅방을 만들어요",
        message: "출발지를 선택하시면 목적지까지 함께 이동할\n사람들을 모을 수 있어요",
        icon: Icons.directions_car_rounded,
      );

    });

  }

  Future<void> loadPlaces() async {

    try {

      final response = await http.get(
        Uri.parse(
          "${dotenv.env['PHP_URL']}start.php"
              "?roomTable=${widget.roomTable}",
        ),
      );

      final data = jsonDecode(response.body);

      if (data["success"] == true) {

        setState(() {

          places = data["spots"];

          isLoading = false;
        });

      } else {

        setState(() {
          isLoading = false;
        });

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data["message"]),
          ),
        );
      }

    } catch (e) {

      setState(() {
        isLoading = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("에러 발생: $e"),
        ),
      );
    }
  }

  void goToEnd({required String? startPlace}) {

    Navigator.push(

      context,

      MaterialPageRoute(

          builder:(context)=>EndPage(

            userId: widget.userId,

            type: widget.type,

            roomTable: widget.roomTable,

            startPlace: startPlace,

          )
      ),
    );

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0xFFF7F7F9),

      appBar: AppBar(
        title: const Text(
          '출발 위치 선택',
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
        iconTheme: const IconThemeData(color: Colors.black87),
      ),

      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),

        child: Column(

          crossAxisAlignment:
          CrossAxisAlignment.start,

          children: [

            const Text(
              '출발 위치를 선택해주세요',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              '어디서 출발하는지 알려주시면 인원을 모으는 데 도움이 돼요',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 24),

            Expanded(

              child: isLoading

                  ? Center(
                child: CircularProgressIndicator(
                  color: primary,
                ),
              )

                  : places.isEmpty

                  ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_off_outlined,
                      size: 56,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '출발 장소가 없습니다',
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

                padding: const EdgeInsets.only(bottom: 100),

                itemCount: places.length,

                itemBuilder: (context, index) {

                  final isSelected =
                      selectedIndex == index;

                  final place =
                  places[index];

                  return GestureDetector(

                    onTap: () {
                      setState(() {
                        if (selectedIndex == index) {
                          // 이미 선택된 항목을 다시 누르면 선택 취소 (-1로 초기화)
                          selectedIndex = -1;
                        } else {
                          // 새로운 항목을 누르면 해당 인덱스로 업데이트
                          selectedIndex = index;
                        }
                      });
                    },

                    child: Container(

                      margin:
                      const EdgeInsets.only(bottom: 12),

                      padding: const EdgeInsets.all(16),

                      decoration: BoxDecoration(

                        color: Colors.white,

                        borderRadius:
                        BorderRadius.circular(18),

                        border: Border.all(
                          color: isSelected
                              ? primary
                              : Colors.transparent,
                          width: 1.6,
                        ),

                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),

                      child: Row(

                        children: [

                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? primary.withOpacity(0.12)
                                  : const Color(0xFFF7F7F9),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.location_on_rounded,
                              color: isSelected
                                  ? primary
                                  : Colors.grey.shade500,
                              size: 22,
                            ),
                          ),

                          const SizedBox(width: 14),

                          Expanded(
                            child: Text(

                              place["name"].toString(),

                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? primary
                                    : Colors.black87,
                              ),
                            ),
                          ),

                          if (isSelected)

                            Icon(
                              Icons.check_circle_rounded,
                              color: primary,
                              size: 22,
                            ),

                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),

      bottomNavigationBar: SafeArea(

        top: false,

        child: Container(

          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),

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

            children: [

              // ⭐ 빠르게 찾기 버튼
              OutlinedButton.icon(

                onPressed: () => goToEnd(startPlace: null),

                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  side: BorderSide(color: primary.withOpacity(0.4)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),

                icon: Icon(
                  Icons.bolt_rounded,
                  color: primary,
                  size: 18,
                ),

                label: Text(
                  '빠르게 찾기',
                  style: TextStyle(
                    color: primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),

              ),

              const SizedBox(width: 10),

              Expanded(

                child: ElevatedButton.icon(

                  onPressed: selectedIndex == -1
                      ? null
                      : () {

                    final selectedStart =
                    places[selectedIndex]["name"]
                        .toString();

                    goToEnd(startPlace: selectedStart);

                  },

                  style: ElevatedButton.styleFrom(
                    backgroundColor: selectedIndex == -1
                        ? Colors.grey.shade300
                        : primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),

                  icon: Icon(
                    Icons.arrow_forward_rounded,
                    color: selectedIndex == -1 ? Colors.grey.shade500 : Colors.white,
                  ),

                  label: Text(
                    '다음',
                    style: TextStyle(
                      color: selectedIndex == -1 ? Colors.grey.shade500 : Colors.white,
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
}