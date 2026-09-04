import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../map_view.dart';

class Spot2Page extends StatefulWidget {

  final String regionName;
  final String hubTatsNm;
  final String hubCtgryLclsNm;
  final String hubCtgryMclsNm;
  final String mapX;
  final String mapY;

  const Spot2Page({
    super.key,
    required this.regionName,
    required this.hubTatsNm,
    required this.hubCtgryLclsNm,
    required this.hubCtgryMclsNm,
    required this.mapX,
    required this.mapY,
  });

  @override
  State<Spot2Page> createState() => _Spot2PageState();

}

class _Spot2PageState extends State<Spot2Page> {

  static const Color primary = Color(0xFFFF7A00);

  final Map<String, WebViewController> _mapControllers = {};

  late Future<double?> _crowdRateFuture;

  @override
  void initState() {
    super.initState();
    _crowdRateFuture = _loadAndMatchCrowd();
  }

  Future<double?> _loadAndMatchCrowd() async {

    try {

      final url = '${dotenv.env['PHP_URL']}api_people.php?regionname=${Uri.encodeComponent(widget.regionName)}';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);

      if (data['error'] != null) return null;

      final itemsContainer = data['response']?['body']?['items'];

      if (itemsContainer == null || itemsContainer is String) return null;

      final items = itemsContainer['item'];

      if (items == null) return null;

      final List<dynamic> list = (items is List) ? items : [items];

      double? best;

      for (final raw in list) {

        final tAtsNm = (raw['tAtsNm'] ?? '').toString();

        final rate = double.tryParse((raw['cnctrRate'] ?? '').toString());

        if (tAtsNm.isEmpty || rate == null) continue;

        final candidates = _buildCandidates(tAtsNm);

        for (final c in candidates) {

          if (c.isNotEmpty && widget.hubTatsNm.contains(c)) {

            if (best == null || rate > best) best = rate;

            break;

          }

        }

      }

      return best;

    } catch (e) {
      return null;
    }

  }

  // ⭐ 말씀하신 규칙 그대로 후보 생성
  List<String> _buildCandidates(String tAtsNm) {

    final String regionName = widget.regionName;

    final candidates = <String>{};

    // 괄호(반각/전각) 탐지
    final parenMatch = RegExp(r'[\(（]([^\)）]*)[\)）]').firstMatch(tAtsNm);

    if (parenMatch == null) {

      // ===== 괄호 없는 경우 =====
      candidates.add(tAtsNm); // 원본

      String regionRemoved = tAtsNm.replaceAll(regionName, '');
      regionRemoved = regionRemoved.replaceAll(RegExp(r'\s+'), ' ').trim();

      if (regionRemoved.isNotEmpty) {

        candidates.add(regionRemoved);

        candidates.add(regionRemoved.replaceAll(' ', ''));

        for (final w in regionRemoved.split(' ')) {
          final tw = w.trim();
          if (tw.isNotEmpty) candidates.add(tw);
        }

      }

    } else {

      // ===== 괄호 있는 경우 =====
      // 괄호 앞 공백 제거 (예: "예술의 전당 (천안)" -> "예술의 전당(천안)")
      final normalized = tAtsNm.replaceAll(RegExp(r'\s+[\(（]'), '(');

      final normalizedMatch = RegExp(r'[\(（]([^\)）]*)[\)）]').firstMatch(normalized);

      final String bracketContent = (normalizedMatch?.group(1) ?? '').trim();

      final int startIdx = normalizedMatch?.start ?? normalized.length;

      final String outerPart = normalized.substring(0, startIdx).trim();

      if (bracketContent == regionName) {

        // 괄호 속이 정확히 regionName인 경우 -> 괄호 전체 제거하고 outerPart만 사용
        if (outerPart.isNotEmpty) {

          candidates.add(outerPart);

          candidates.add(outerPart.replaceAll(' ', ''));

        }

      } else {

        if (outerPart.isNotEmpty) {

          candidates.add(outerPart); // 예: "천안 광덕의 산"

          String outerRegionRemoved = outerPart.replaceAll(regionName, '');
          outerRegionRemoved = outerRegionRemoved.replaceAll(RegExp(r'\s+'), ' ').trim();

          if (outerRegionRemoved.isNotEmpty) {

            candidates.add(outerRegionRemoved); // "광덕의 산"

            candidates.add(outerRegionRemoved.replaceAll(' ', '')); // "광덕의산"

          }

        }

        if (bracketContent.isNotEmpty) {
          candidates.add(bracketContent); // "광덕사"
        }

      }

    }

    candidates.removeWhere((c) => c.isEmpty);

    return candidates.toList();

  }

  Color _rateColor(double rate) {
    if (rate >= 70) return Colors.redAccent;
    if (rate >= 40) return const Color(0xFFFFA000);
    return Colors.green;
  }

  String _rateLabel(double rate) {
    if (rate >= 70) return "혼잡";
    if (rate >= 40) return "보통";
    return "쾌적";
  }

  // ⭐ spot2.dart와 완전히 동일한 지도 컨트롤러 생성/캐싱 로직
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

  // ⭐ spot2.dart와 완전히 동일한 미리보기 위젯 (탭하면 map_view.dart 풀스크린으로 이동)
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

  IconData _categoryIcon(String category) {
    if (category.contains("숙박")) return Icons.hotel_rounded;
    if (category.contains("음식")) return Icons.restaurant_rounded;
    if (category.contains("쇼핑")) return Icons.shopping_bag_rounded;
    if (category.contains("관광")) return Icons.landscape_rounded;
    if (category.contains("문화")) return Icons.museum_rounded;
    return Icons.place_rounded;
  }

  @override
  Widget build(BuildContext context) {

    final double? mapX = double.tryParse(widget.mapX);
    final double? mapY = double.tryParse(widget.mapY);

    final bool hasLocation = mapX != null && mapY != null;

    return Scaffold(

      backgroundColor: const Color(0xFFF7F7F9),

      appBar: AppBar(
        title: Text(
          widget.hubTatsNm,
          style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87, fontSize: 18),
        ),
        centerTitle: false,
        backgroundColor: const Color(0xFFF7F7F9),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),

      body: ListView(

        padding: const EdgeInsets.all(16),

        children: [

          Container(

            padding: const EdgeInsets.all(18),

            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
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
                      decoration: BoxDecoration(color: primary.withOpacity(0.12), shape: BoxShape.circle),
                      child: Icon(_categoryIcon(widget.hubCtgryLclsNm), color: primary, size: 22),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Text(
                        widget.hubTatsNm,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87),
                      ),
                    ),

                  ],
                ),

                const SizedBox(height: 14),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [

                    _InfoChip(icon: Icons.category_rounded, label: widget.hubCtgryLclsNm),

                    if (widget.hubCtgryMclsNm.isNotEmpty && widget.hubCtgryMclsNm != widget.hubCtgryLclsNm)
                      _InfoChip(icon: Icons.label_rounded, label: widget.hubCtgryMclsNm),

                    // ⭐ 혼잡도 매칭 결과 (있을 때만)
                    FutureBuilder<double?>(
                      future: _crowdRateFuture,
                      builder: (context, snapshot) {

                        if (snapshot.connectionState != ConnectionState.done) {
                          return const SizedBox.shrink();
                        }

                        final rate = snapshot.data;

                        if (rate == null) return const SizedBox.shrink();

                        final color = _rateColor(rate);

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.groups_rounded, size: 13, color: color),
                              const SizedBox(width: 4),
                              Text(
                                "혼잡도 ${rate.toStringAsFixed(1)}% · ${_rateLabel(rate)}",
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
                              ),
                            ],
                          ),
                        );

                      },
                    ),

                  ],
                ),

                if (hasLocation) ...[

                  const SizedBox(height: 14),

                  _buildMapPreview(
                    cacheKey: "spot3_${widget.hubTatsNm}",
                    lat: mapY,
                    lng: mapX,
                    title: widget.hubTatsNm,
                  ),

                ],

              ],
            ),

          ),

        ],

      ),

    );

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
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}