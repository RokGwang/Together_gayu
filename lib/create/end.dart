import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'final.dart';
import 'GPS.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EndPage extends StatefulWidget {
  final int userId;
  final String type;
  final String? startPlace; // ⭐ nullable로 변경 (빠르게 찾기로 넘어온 경우 null)
  final String roomTable;

  const EndPage({
    super.key,
    required this.userId,
    required this.type,
    required this.startPlace,
    required this.roomTable,
  });

  @override
  State<EndPage> createState() => _EndPageState();
}

class _EndPageState extends State<EndPage> {

  static const Color primary = Color(0xFFFF7A00);

  List<dynamic> places = [];
  int selectedIndex = -1;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadPlaces();
  }

  Future<void> loadPlaces() async {
    try {
      final response = await http.get(
        Uri.parse("${dotenv.env['PHP_URL']}end.php?roomTable=${widget.roomTable}"),
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
          SnackBar(content: Text(data["message"])),
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("에러 발생: $e")),
      );
    }
  }

  void goToNext(String selectedEnd) {
    if (widget.startPlace != null) {

      // 1️⃣ 출발지가 있는 정상 흐름 -> FinalPage로
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FinalPage(
            userId: widget.userId,
            type: widget.type,
            roomTable: widget.roomTable,
            startPlace: widget.startPlace!,
            endPlace: selectedEnd,
          ),
        ),
      );
    } else {

      // 2️⃣ 빠르게 찾기로 출발지 없이 넘어온 흐름 -> GPSPage로
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GPSPage(
            userId: widget.userId,
            type: widget.type,
            roomTable: widget.roomTable,
            endPlace: selectedEnd,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      backgroundColor: const Color(0xFFF7F7F9),

      appBar: AppBar(
        title: const Text(
          '목적지 선택',
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ⭐ 출발지가 있을 때만 요약 박스 표시
            if (widget.startPlace != null) ...[

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.trip_origin_rounded, size: 16, color: primary),
                    const SizedBox(width: 8),
                    Text(
                      '출발지  ${widget.startPlace}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: primary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

            ],

            const Text(
              '목적지를 선택해주세요',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              '어디로 이동하는지 선택해주세요',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 24),

            Expanded(
              child: isLoading
                  ? Center(child: CircularProgressIndicator(color: primary))
                  : places.isEmpty
                  ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_off_outlined, size: 56, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text(
                      '목적지가 없습니다',
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

                  final isSelected = selectedIndex == index;
                  final place = places[index];

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
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected ? primary : Colors.transparent,
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
                              Icons.place_rounded,
                              color: isSelected ? primary : Colors.grey.shade500,
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
                                color: isSelected ? primary : Colors.black87,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(Icons.check_circle_rounded, color: primary, size: 22),
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

      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: selectedIndex == -1
              ? []
              : [
            BoxShadow(
              color: primary.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: selectedIndex == -1
              ? null
              : () {
            final selectedEnd = places[selectedIndex]["name"].toString();
            goToNext(selectedEnd);
          },
          backgroundColor: selectedIndex == -1 ? Colors.grey.shade300 : primary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

    );
  }
}