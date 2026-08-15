import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'spot2.dart';

class SpotPage extends StatefulWidget {

  final String regionName;

  const SpotPage({super.key, required this.regionName});

  @override
  State<SpotPage> createState() => _SpotPageState();
}

enum _CrowdTab { crowded, normal, comfortable }

class _SpotPageState extends State<SpotPage> {

  static const Color primary = Color(0xFFFF7A00);

  late Future<_SpotResult> _spotFuture;

  _CrowdTab selectedTab = _CrowdTab.crowded; // ⭐ 기본값 혼잡

  @override
  void initState() {
    super.initState();
    _spotFuture = _fetchSpots();
  }

  Future<_SpotResult> _fetchSpots() async {

    final url = '${dotenv.env['PHP_URL']}api_people.php?regionname=${Uri.encodeComponent(widget.regionName)}';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception('데이터 로드 실패');
    }

    final data = jsonDecode(response.body);

    if (data['error'] != null) {
      throw Exception(data['error']);
    }

    // ⭐ 이 페이지가 소유한 signguCd (spot2.dart로 넘겨줄 값)
    final String signguCd = _extractSignguCd(data);

    final itemsContainer = data['response']?['body']?['items'];

    if (itemsContainer == null || itemsContainer is String) {
      return _SpotResult(spots: [], signguCd: signguCd);
    }

    final items = itemsContainer['item'];

    if (items == null) {
      return _SpotResult(spots: [], signguCd: signguCd);
    }

    final List<dynamic> list = (items is List) ? items : [items];

    final spots = list.map((item) {

      return {
        "name": (item['tAtsNm'] ?? '').toString(),
        "rate": (item['cnctrRate'] ?? '').toString(),
      };

    }).toList();

    spots.sort((a, b) {

      final rateA = double.tryParse(a["rate"] ?? '') ?? 0;
      final rateB = double.tryParse(b["rate"] ?? '') ?? 0;

      return rateB.compareTo(rateA);

    });

    return _SpotResult(
      spots: List<Map<String, String>>.from(spots),
      signguCd: signguCd,
    );

  }

  String _extractSignguCd(Map<String, dynamic> data) {

    final itemsContainer = data['response']?['body']?['items'];

    if (itemsContainer == null || itemsContainer is String) return '';

    final items = itemsContainer['item'];

    if (items == null) return '';

    final List<dynamic> list = (items is List) ? items : [items];

    if (list.isEmpty) return '';

    return (list.first['signguCd'] ?? '').toString();

  }

  Color _rateColor(double rate) {

    if (rate >= 70) return Colors.redAccent;

    if (rate >= 40) return const Color(0xFFFFA000);

    return Colors.green;

  }

  String _rateLabel(double rate) {

    if (rate >= 70) return "혼잡";

    if (rate >= 40) return "보통";

    return "쾌적"; // ⭐ 여유 -> 쾌적

  }

  List<Map<String, String>> _filterByTab(List<Map<String, String>> spots) {

    return spots.where((spot) {

      final double rate = double.tryParse(spot["rate"] ?? '') ?? 0;

      final String label = _rateLabel(rate);

      switch (selectedTab) {
        case _CrowdTab.crowded:
          return label == "혼잡";
        case _CrowdTab.normal:
          return label == "보통";
        case _CrowdTab.comfortable:
          return label == "쾌적";
      }

    }).toList();

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0xFFF7F7F9),

      appBar: AppBar(
        title: Text(
          '${widget.regionName} 관광지 목록',
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

      body: FutureBuilder<_SpotResult>(
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

          final result = snapshot.data!;

          final filteredSpots = _filterByTab(result.spots);

          return Column(

            children: [

              // ===== 혼잡/보통/쾌적 탭 =====
              Padding(

                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),

                child: Row(
                  children: [

                    Expanded(
                      child: _CrowdTabButton(
                        label: "혼잡",
                        color: Colors.redAccent,
                        selected: selectedTab == _CrowdTab.crowded,
                        onTap: () => setState(() => selectedTab = _CrowdTab.crowded),
                      ),
                    ),

                    const SizedBox(width: 8),

                    Expanded(
                      child: _CrowdTabButton(
                        label: "보통",
                        color: const Color(0xFFFFA000),
                        selected: selectedTab == _CrowdTab.normal,
                        onTap: () => setState(() => selectedTab = _CrowdTab.normal),
                      ),
                    ),

                    const SizedBox(width: 8),

                    Expanded(
                      child: _CrowdTabButton(
                        label: "쾌적",
                        color: Colors.green,
                        selected: selectedTab == _CrowdTab.comfortable,
                        onTap: () => setState(() => selectedTab = _CrowdTab.comfortable),
                      ),
                    ),

                  ],
                ),

              ),

              const SizedBox(height: 8),

              Expanded(

                child: filteredSpots.isEmpty

                    ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.travel_explore_rounded, size: 56, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        "해당하는 관광지가 없습니다",
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                )

                    : ListView.separated(

                  padding: const EdgeInsets.all(16),

                  itemCount: filteredSpots.length,

                  separatorBuilder: (_, __) => const SizedBox(height: 10),

                  itemBuilder: (context, index) {

                    final spot = filteredSpots[index];

                    final String name = spot["name"] ?? "이름 없음";

                    final double rate = double.tryParse(spot["rate"] ?? '') ?? 0;

                    final Color color = _rateColor(rate);

                    return InkWell(

                      borderRadius: BorderRadius.circular(18),

                      onTap: () {

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => Spot2Page(
                              regionName: widget.regionName,
                              signguCd: result.signguCd,
                              name: name,
                            ),
                          ),
                        );

                      },

                      child: Container(

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

                            const SizedBox(width: 6),

                            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade300),

                          ],
                        ),

                      ),

                    );

                  },

                ),

              ),

            ],

          );

        },
      ),

    );
  }
}

class _SpotResult {

  final List<Map<String, String>> spots;

  final String signguCd;

  _SpotResult({required this.spots, required this.signguCd});

}

class _CrowdTabButton extends StatelessWidget {

  final String label;

  final Color color;

  final bool selected;

  final VoidCallback onTap;

  const _CrowdTabButton({
    required this.label,
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

        padding: const EdgeInsets.symmetric(vertical: 11),

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

        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : Colors.grey.shade500,
            ),
          ),
        ),

      ),

    );

  }

}