import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'final.dart';
import 'GPS.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EndPage extends StatefulWidget {
  final int userId;
  final String type;
  final String? startPlace;
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

  List<dynamic> type0Places = []; // ⭐ 리턴
  List<dynamic> type1Places = []; // ⭐ 출발(end.dart 기준 목적지)

  String? selectedEnd;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadPlaces();
  }

  Future<void> loadPlaces() async {
    try {
      final response = await http.get(
        Uri.parse("${dotenv.env['PHP_URL']}create.php?roomTable=${widget.roomTable}"),
      );
      final data = jsonDecode(response.body);
      if (data["success"] == true) {

        List<dynamic> t0 = data["type0"] ?? [];
        List<dynamic> t1 = data["type1"] ?? [];

        // ⭐ 이전 페이지에서 선택한 출발지는 목록에서 제외
        if (widget.startPlace != null) {
          t0 = t0.where((p) => p["name"].toString() != widget.startPlace).toList();
          t1 = t1.where((p) => p["name"].toString() != widget.startPlace).toList();
        }

        setState(() {
          type0Places = t0;
          type1Places = t1;
          isLoading = false;
        });

      } else {
        setState(() {
          isLoading = false;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data["message"] ?? "장소를 불러올 수 없습니다")),
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

  void _selectPlace(String name) {
    setState(() {
      selectedEnd = (selectedEnd == name) ? null : name;
    });
  }

  void goToNext(String selectedEndPlace) {
    if (widget.startPlace != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FinalPage(
            userId: widget.userId,
            type: widget.type,
            roomTable: widget.roomTable,
            startPlace: widget.startPlace!,
            endPlace: selectedEndPlace,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GPSPage(
            userId: widget.userId,
            type: widget.type,
            roomTable: widget.roomTable,
            endPlace: selectedEndPlace,
          ),
        ),
      );
    }
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          title,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color),
        ),
      ),
    );
  }

  Widget _buildPlaceTile(dynamic place) {

    final String name = place["name"].toString();
    final bool isSelected = selectedEnd == name;

    return GestureDetector(
      onTap: () => _selectPlace(name),
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
                color: isSelected ? primary.withOpacity(0.12) : const Color(0xFFF7F7F9),
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
                name,
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      appBar: AppBar(
        title: const Text(
          '목적지 선택',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87, fontSize: 18),
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
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
            ],
            const Text(
              '목적지를 선택해주세요',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.black87),
            ),
            const SizedBox(height: 4),
            Text(
              '어디로 이동하는지 선택해주세요',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: isLoading
                  ? Center(child: CircularProgressIndicator(color: primary))
                  : (type0Places.isEmpty && type1Places.isEmpty)
                  ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_off_outlined, size: 56, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text(
                      '목적지가 없습니다',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              )
                  : ListView(
                padding: const EdgeInsets.only(bottom: 100),
                children: [

                  if (type1Places.isNotEmpty) ...[
                    _buildSectionHeader("관광지 도착", Colors.blueAccent),
                    const SizedBox(height: 10),
                    ...type1Places.map((place) => _buildPlaceTile(place)),
                    const SizedBox(height: 8),
                  ],

                  if (type0Places.isNotEmpty) ...[
                    Divider(color: Colors.grey.shade200, height: 32),
                    _buildSectionHeader("교통지 도착", primary),
                    const SizedBox(height: 10),
                    ...type0Places.map((place) => _buildPlaceTile(place)),
                  ],

                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: selectedEnd == null
              ? []
              : [
            BoxShadow(color: primary.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: selectedEnd == null ? null : () => goToNext(selectedEnd!),
          backgroundColor: selectedEnd == null ? Colors.grey.shade300 : primary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: Icon(
            Icons.arrow_forward_rounded,
            color: selectedEnd == null ? Colors.grey.shade500 : Colors.white,
          ),
          label: Text(
            '다음',
            style: TextStyle(
              color: selectedEnd == null ? Colors.grey.shade500 : Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}