import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SpotPage extends StatefulWidget {

  final String regionName;

  const SpotPage({super.key, required this.regionName});

  @override
  State<SpotPage> createState() => _SpotPageState();
}

class _SpotPageState extends State<SpotPage> {

  static const Color primary = Color(0xFFFF7A00);

  late Future<List<Map<String, String>>> _spotFuture;

  @override
  void initState() {
    super.initState();
    _spotFuture = _fetchSpots();
  }

  Future<List<Map<String, String>>> _fetchSpots() async {

    final url = '${dotenv.env['PHP_URL']}api_people2.php?regionname=${Uri.encodeComponent(widget.regionName)}';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception('데이터 로드 실패');
    }

    final data = jsonDecode(response.body);

    if (data['error'] != null) {
      throw Exception(data['error']);
    }

    final itemsContainer = data['response']?['body']?['items'];

    if (itemsContainer == null || itemsContainer is String) return [];

    final items = itemsContainer['item'];

    if (items == null) return [];

    final List<dynamic> list = (items is List) ? items : [items];

    final spots = list.map((item) {

      return {
        "name": (item['tAtsNm'] ?? '').toString(),
        "rate": (item['cnctrRate'] ?? '').toString(),
      };

    }).toList();

    // 혼잡도 높은 순으로 정렬
    spots.sort((a, b) {

      final rateA = double.tryParse(a["rate"] ?? '') ?? 0;
      final rateB = double.tryParse(b["rate"] ?? '') ?? 0;

      return rateB.compareTo(rateA);

    });

    return List<Map<String, String>>.from(spots);

  }

  Color _rateColor(double rate) {

    if (rate >= 70) return Colors.redAccent;

    if (rate >= 40) return const Color(0xFFFFA000);

    return Colors.green;

  }

  String _rateLabel(double rate) {

    if (rate >= 70) return "혼잡";

    if (rate >= 40) return "보통";

    return "여유";

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0xFFF7F7F9),

      appBar: AppBar(
        title: Text(
          '${widget.regionName} 관광지 혼잡도',
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
      ),

      body: FutureBuilder<List<Map<String, String>>>(
        future: _spotFuture,
        builder: (context, snapshot) {

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: primary));
          }

          if (snapshot.hasError) {

            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline_rounded, size: 56, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text(
                    "정보를 불러올 수 없습니다",
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );

          }

          final spots = snapshot.data ?? [];

          if (spots.isEmpty) {

            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.travel_explore_rounded, size: 56, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text(
                    "관광지 정보가 없습니다",
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );

          }

          return ListView.separated(

            padding: const EdgeInsets.all(16),

            itemCount: spots.length,

            separatorBuilder: (_, __) => const SizedBox(height: 10),

            itemBuilder: (context, index) {

              final spot = spots[index];

              final String name = spot["name"] ?? "이름 없음";

              final double rate = double.tryParse(spot["rate"] ?? '') ?? 0;

              final Color color = _rateColor(rate);

              return Container(

                padding: const EdgeInsets.all(16),

                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
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
                        color: color.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.place_rounded, color: color, size: 22),
                    ),

                    const SizedBox(width: 14),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Row(
                            children: [

                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _rateLabel(rate),
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
                                ),
                              ),

                              const SizedBox(width: 6),

                              Text(
                                "혼잡도 ${rate.toStringAsFixed(1)}%",
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                              ),

                            ],
                          ),

                        ],
                      ),
                    ),

                    Text(
                      "${rate.toStringAsFixed(0)}%",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
                    ),

                  ],
                ),

              );

            },

          );

        },
      ),

    );
  }
}