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

  final Map<String, WebViewController> _mapControllers = {};

  bool isAiLoading = false;
  String? aiDescription;
  double? aiLat;
  double? aiLng;

  @override
  void initState() {
    super.initState();
    _detailFuture = _fetchDetails();
  }

  String _lastMonthYm() {
    final now = DateTime.now();
    final lastMonthDate = DateTime(now.year, now.month - 1, 1);
    final y = lastMonthDate.year.toString();
    final m = lastMonthDate.month.toString().padLeft(2, '0');
    return "$y$m";
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

  // ⭐ 주변 스팟 찾아보기 (기존 "연관 관광지 1", api_spot.php)
  Future<List<Map<String, dynamic>>> _fetchNearbySpots() async {
    final baseYm = _lastMonthYm();
    final url = '${dotenv.env['PHP_URL']}api_spot.php'
        '?keyword=${Uri.encodeComponent(widget.name)}'
        '&signguCd=${Uri.encodeComponent(widget.signguCd)}'
        '&baseYm=$baseYm'
        '&areaCd=44';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('데이터 로드 실패');
    }
    final data = jsonDecode(response.body);
    if (data['success'] != true) {
      throw Exception(data['message'] ?? '데이터 로드 실패');
    }
    final itemsContainer = data['data']?['response']?['body']?['items'];
    if (itemsContainer == null || itemsContainer is String) return [];
    final rawItems = itemsContainer['item'];
    if (rawItems == null) return [];
    final List<dynamic> items = (rawItems is List) ? rawItems : [rawItems];
    final list = items.map((e) => Map<String, dynamic>.from(e)).toList();
    list.sort((a, b) {
      final rankA = int.tryParse((a['rlteRank'] ?? '0').toString()) ?? 0;
      final rankB = int.tryParse((b['rlteRank'] ?? '0').toString()) ?? 0;
      return rankB.compareTo(rankA);
    });
    return list;
  }

  void _showNearbySpotsPopup() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const Text(
                "주변 스팟 찾아보기",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.black87),
              ),
              const SizedBox(height: 4),
              Text(
                "'${widget.name}'과(와) 함께 찾는 장소",
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchNearbySpots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator(color: primary)),
                      );
                    }
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text("정보를 불러올 수 없습니다", style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                        ),
                      );
                    }
                    final list = snapshot.data ?? [];
                    if (list.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text("연관 정보가 없습니다", style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                        ),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: list.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
                      itemBuilder: (context, index) {
                        final item = list[index];
                        final String rlteTatsNm = (item['rlteTatsNm'] ?? '').toString();
                        final String rank = (item['rlteRank'] ?? '').toString();
                        final String catL = (item['rlteCtgryLclsNm'] ?? '').toString();
                        final String catM = (item['rlteCtgryMclsNm'] ?? '').toString();
                        final String catS = (item['rlteCtgrySclsNm'] ?? '').toString();
                        final String signguNm = (item['rlteSignguNm'] ?? '').toString();
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  "${index + 1}",
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: primary),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      rlteTatsNm,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        if (signguNm.isNotEmpty) _MiniChip(label: signguNm),
                                        if (catL.isNotEmpty) _MiniChip(label: catL),
                                        if (catM.isNotEmpty && catM != catL) _MiniChip(label: catM),
                                        if (catS.isNotEmpty && catS != catM) _MiniChip(label: catS),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> askAI() async {
    setState(() {
      isAiLoading = true;
      aiDescription = null;
      aiLat = null;
      aiLng = null;
    });
    try {
      final response = await http.post(
        Uri.parse("${dotenv.env['PHP_URL']}spot_ai.php"),
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

  // ⭐ "주변 스팟 찾아보기" 버튼 1개만 남김
  // ⭐ "<AI에게 물어보기>" 버튼과 동일한 크기/UI/UX로 맞춘 "주변 스팟 찾아보기" 버튼
  Widget _buildRelatedButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _showNearbySpotsPopup,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14), // AI 버튼과 동일한 세로 패딩(14)
            side: BorderSide(color: primary.withOpacity(0.4)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: Icon(Icons.travel_explore_rounded, color: primary, size: 18), // AI 버튼과 동일한 아이콘 크기(18)
          label: Text(
            "주변 스팟 찾아보기",
            style: TextStyle(color: primary, fontWeight: FontWeight.w700, fontSize: 14), // AI 버튼과 동일한 폰트 사이즈
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
                      child: ElevatedButton.icon(
                        onPressed: isAiLoading ? null : askAI,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary, // ⭐ 주황색 배경 지정
                          foregroundColor: Colors.white, // 텍스트 및 아이콘 색상 흰색
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: isAiLoading
                            ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                            : const Icon(Icons.auto_awesome_rounded, size: 18),
                        label: Text(
                          isAiLoading ? "AI가 찾아보는 중..." : "AI에게 물어보기",
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
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
                  const SizedBox(height: 24),
                  _buildRelatedButton(),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            itemCount: items.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == items.length) {
                return _buildRelatedButton();
              }
              final item = items[index];
              final String hubTatsNm = (item['hubTatsNm'] ?? '').toString();
              final String categoryL = (item['hubCtgryLclsNm'] ?? '').toString();
              final String categoryM = (item['hubCtgryMclsNm'] ?? '').toString();
              final String signguNm = (item['signguNm'] ?? '').toString();
              final String rank = (item['hubRank'] ?? '').toString();
              final String baseYm = (item['baseYm'] ?? '').toString();
              final String mapXStr = (item['mapX'] ?? '').toString();
              final String mapYStr = (item['mapY'] ?? '').toString();
              final double? mapX = double.tryParse(mapXStr);
              final double? mapY = double.tryParse(mapYStr);
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
class _MiniChip extends StatelessWidget {
  final String label;
  final Color? color;
  const _MiniChip({required this.label, this.color});
  @override
  Widget build(BuildContext context) {
    final Color c = color ?? Colors.grey.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? Colors.grey).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c),
      ),
    );
  }
}