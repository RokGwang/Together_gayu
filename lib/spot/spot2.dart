import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../map_view.dart'; // ⭐ 실제 경로에 맞게 조정해주세요

class Spot2Page extends StatefulWidget {
  final String regionName;
  final String signguCd;
  final String name;
  const Spot2Page({
    super.key,
    required this.regionName,
    required this.signguCd,
    required this.name,
  });
  @override
  State<Spot2Page> createState() => _Spot2PageState();
}

class _Spot2PageState extends State<Spot2Page> {
  static const Color primary = Color(0xFFFF7A00);
  late Future<List<Map<String, dynamic>>> _detailFuture;

  // ⭐ 지도 미리보기 컨트롤러 캐시
  final Map<String, WebViewController> _mapControllers = {};

  // ⭐ AI 관련 상태
  bool isAiLoading = false;
  String? aiDescription;
  double? aiLat;
  double? aiLng;

  @override
  void initState() {
    super.initState();
    _detailFuture = _fetchDetails();
  }

  Future<List<Map<String, dynamic>>> _fetchDetails() async {
    final url = '${dotenv.env['PHP_URL']}spot.php'
        '?signguCd=${Uri.encodeComponent(widget.signguCd)}'
        '&name=${Uri.encodeComponent(widget.name)}'
        '&regionname=${Uri.encodeComponent(widget.regionName)}';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('데이터 로드 실패');
    }
    final data = jsonDecode(response.body);
    if (data['error'] != null) {
      throw Exception(data['error']);
    }
    final List<dynamic> items = data['items'] ?? [];
    return items.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  // ⭐ AI에게 물어보기
  Future<void> askAI() async {

    setState(() {
      isAiLoading = true;
      aiDescription = null;
      aiLat = null;
      aiLng = null;
    });

    try {

      final response = await http.post(
        Uri.parse("${dotenv.env['PHP_URL']}spot_ai2.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "name": widget.name,
          "regionname": widget.regionName,
        }),
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (data["success"] == true) {

        setState(() {

          aiDescription = data["description"];

          final bool hasLocation = data["has_location"] == true;

          aiLat = hasLocation && data["lat"] != null ? (data["lat"] as num).toDouble() : null;
          aiLng = hasLocation && data["lng"] != null ? (data["lng"] as num).toDouble() : null;

        });

      } else {

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data["message"] ?? "AI 응답을 받지 못했습니다")),
        );

      }

    } catch (e) {

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("에러: $e")),
      );

    } finally {

      if (!mounted) return;

      setState(() => isAiLoading = false);

    }

  }
  // ⭐ 지도 미리보기용 WebViewController 생성/캐싱
  WebViewController _getMapController(String key, double lat, double lng, String title) {
    if (_mapControllers.containsKey(key)) {
      return _mapControllers[key]!;
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

          // ⭐ 프리뷰 컨테이너 크기가 늦게 확정되는 문제 보정
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
      ..setBackgroundColor(const Color(0xFFF7F7F9))
      ..loadHtmlString(html);

    _mapControllers[key] = controller;

    return controller;
  }

  // ⭐ 지도 미리보기 위젯 (탭하면 map_view.dart로 크게 보기)
  Widget _buildMapPreview({
    required String cacheKey,
    required double lat,
    required double lng,
    required String title,
  }) {

    return GestureDetector(

      onTap: () {

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MapViewPage(lat: lat, lng: lng, title: title),
          ),
        );

      },

      child: ClipRRect(

        borderRadius: BorderRadius.circular(14),

        child: SizedBox(

          height: 130,

          child: Stack(
            children: [

              IgnorePointer(
                child: WebViewWidget(
                  controller: _getMapController(cacheKey, lat, lng, title),
                ),
              ),

              Positioned(
                left: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.map_rounded, color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Text("지도 크게 보기", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      appBar: AppBar(
        title: Text(
          widget.name,
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
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _detailFuture,
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
          final items = snapshot.data ?? [];

          // ===== 관련 정보가 없을 때: 안내 + AI에게 물어보기 =====
          if (items.isEmpty) {

            return SingleChildScrollView(

              padding: const EdgeInsets.all(20),

              child: Column(
                children: [

                  const SizedBox(height: 40),

                  Icon(Icons.info_outline_rounded, size: 56, color: Colors.grey.shade300),

                  const SizedBox(height: 12),

                  Text(
                    "관련 정보가 없습니다",
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontWeight: FontWeight.w500),
                  ),

                  const SizedBox(height: 20),

                  if (aiDescription == null) ...[

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: isAiLoading ? null : askAI,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: primary.withOpacity(0.4)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: isAiLoading
                            ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: primary),
                        )
                            : Icon(Icons.auto_awesome_rounded, color: primary, size: 18),
                        label: Text(
                          isAiLoading ? "AI가 찾아보는 중..." : "AI에게 물어보기",
                          style: TextStyle(color: primary, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),

                  ] else ...[

                    Container(

                      width: double.infinity,

                      padding: const EdgeInsets.all(16),

                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: primary.withOpacity(0.2)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),

                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          Row(
                            children: [
                              Icon(Icons.auto_awesome_rounded, color: primary, size: 16),
                              const SizedBox(width: 6),
                              const Text("AI 소개", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            ],
                          ),

                          const SizedBox(height: 10),

                          Text(
                            aiDescription!,
                            textAlign: TextAlign.left,
                            style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
                          ),

                          if (aiLat != null && aiLng != null) ...[

                            const SizedBox(height: 16),

                            _buildMapPreview(
                              cacheKey: "ai_${widget.name}",
                              lat: aiLat!,
                              lng: aiLng!,
                              title: widget.name,
                            ),

                            const SizedBox(height: 6),

                            Text(
                              "※ AI가 추정한 위치로 실제와 다를 수 있어요",
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            ),

                          ],

                        ],
                      ),

                    ),

                  ],

                ],
              ),

            );

          }

          // ===== 관련 정보가 있을 때: 기존 카드 목록 + 지도 미리보기 =====
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              final String hubTatsNm = (item['hubTatsNm'] ?? '').toString();
              final String categoryL = (item['hubCtgryLclsNm'] ?? '').toString();
              final String categoryM = (item['hubCtgryMclsNm'] ?? '').toString();
              final String signguNm = (item['signguNm'] ?? '').toString();
              final String rank = (item['hubRank'] ?? '').toString();
              final String baseYm = (item['baseYm'] ?? '').toString();

              final String mapXStr = (item['mapX'] ?? '').toString();
              final String mapYStr = (item['mapY'] ?? '').toString();

              final double? mapX = double.tryParse(mapXStr); // 경도
              final double? mapY = double.tryParse(mapYStr); // 위도

              final bool hasLocation = mapXStr.isNotEmpty && mapYStr.isNotEmpty && mapX != null && mapY != null;

              return Container(
                padding: const EdgeInsets.all(18),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: primary.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_categoryIcon(categoryL), color: primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hubTatsNm,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                signguNm,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (rank.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "인기 ${rank}위",
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: primary),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _InfoChip(icon: Icons.category_rounded, label: categoryL),
                        if (categoryM.isNotEmpty && categoryM != categoryL)
                          _InfoChip(icon: Icons.label_rounded, label: categoryM),
                        if (baseYm.length == 6)
                          _InfoChip(
                            icon: Icons.calendar_month_rounded,
                            label: "${baseYm.substring(0, 4)}년 ${baseYm.substring(4)}월 기준",
                          ),
                        if (hasLocation)
                          _InfoChip(
                            icon: Icons.pin_drop_rounded,
                            label: "${mapY.toStringAsFixed(4)}, ${mapX.toStringAsFixed(4)}",
                          ),
                      ],
                    ),

                    // ⭐ 지도 미리보기 (mapX/mapY가 있을 때만)
                    if (hasLocation) ...[

                      const SizedBox(height: 14),

                      _buildMapPreview(
                        cacheKey: (item['hubTatsCd'] ?? hubTatsNm).toString(),
                        lat: mapY,
                        lng: mapX,
                        title: hubTatsNm,
                      ),

                    ],

                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
  IconData _categoryIcon(String category) {
    if (category.contains("숙박")) return Icons.hotel_rounded;
    if (category.contains("음식")) return Icons.restaurant_rounded;
    if (category.contains("쇼핑")) return Icons.shopping_bag_rounded;
    if (category.contains("관광")) return Icons.landscape_rounded;
    if (category.contains("문화")) return Icons.museum_rounded;
    return Icons.place_rounded;
  }
}
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}