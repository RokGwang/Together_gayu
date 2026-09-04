import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../map_view.dart';

class ContentPage extends StatefulWidget {

  final String regionName;

  const ContentPage({super.key, required this.regionName});

  @override
  State<ContentPage> createState() => _ContentPageState();

}

enum _ContentTopTab { content, festival }

class _ContentPageState extends State<ContentPage> {

  static const Color primary = Color(0xFFFF7A00);

  _ContentTopTab selectedTab = _ContentTopTab.content;

  late Future<List<Map<String, dynamic>>> _contentFuture;

  late Future<List<Map<String, dynamic>>> _festivalFuture;

  final Map<String, WebViewController> _mapControllers = {};

  static const List<double> _grayscaleMatrix = [
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ];

  late Future<List<Map<String, dynamic>>> _csvFestivalFuture; // ⭐ 필드 추가 (클래스 상단, _festivalFuture 선언부 근처)

  @override
  void initState() {
    super.initState();
    _contentFuture = _fetchContent();
    _festivalFuture = _fetchFestival();
    _csvFestivalFuture = _fetchCsvFestival(); // ⭐ 추가
  }

  Future<List<Map<String, dynamic>>> _fetchContent() async {

    final url = '${dotenv.env['PHP_URL']}content.php?regionname=${Uri.encodeComponent(widget.regionName)}';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) throw Exception('데이터 로드 실패');

    final data = jsonDecode(response.body);

    if (data['success'] != true) throw Exception(data['message'] ?? '데이터 로드 실패');

    final List<dynamic> items = data['data'] ?? [];

    return items.map((e) => Map<String, dynamic>.from(e)).toList();

  }

  Future<List<Map<String, dynamic>>> _fetchCsvFestival() async {

    final url = '${dotenv.env['PHP_URL']}content_festival22.php?regionname=${Uri.encodeComponent(widget.regionName)}';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body);

    if (data['success'] != true) return [];

    final List<dynamic> items = data['items'] ?? [];

    return items.map((e) => Map<String, dynamic>.from(e)).toList();

  }

  Future<List<Map<String, dynamic>>> _fetchFestival() async {

    final url = '${dotenv.env['PHP_URL']}content_festival.php';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) throw Exception('데이터 로드 실패');

    final data = jsonDecode(response.body);

    if (data['success'] != true) throw Exception(data['message'] ?? '데이터 로드 실패');

    dynamic rawItems;

    try {
      rawItems = data['raw_response']['body']['items']['item'];
    } catch (e) {
      rawItems = null;
    }

    List items = [];

    if (rawItems is List) {
      items = rawItems;
    } else if (rawItems is Map) {
      items = [rawItems];
    }

    // ⭐ regionname 키워드가 어떤 속성값에든 포함되면 통과
    final matchedList = items.where((item) {

      if (item is Map) {

        return item.values.any((value) {

          if (value != null) {
            return value.toString().contains(widget.regionName);
          }

          return false;

        });

      }

      return false;

    }).toList();

    // ⭐ 추가: fstvlEndDate 기준으로 올해(yyyy)인 항목만
    final currentYear = DateTime.now().year.toString();

    final yearFiltered = matchedList.where((item) {

      if (item is! Map) return false;

      final endDate = (item['fstvlEndDate'] ?? '').toString();

      return endDate.startsWith(currentYear);

    }).toList();

    return yearFiltered.map((e) => Map<String, dynamic>.from(e as Map)).toList();

  }

  Future<void> _openUrl(String url) async {

    if (url.isEmpty) return;

    final uri = Uri.tryParse(url);

    if (uri == null) return;

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

  }

  // ⭐ 종료일이 오늘보다 지났는지 판별 (mm-dd 기준이 아니라 실제 날짜 전체로 비교 — 이미 올해로 필터링됐으므로 이 방식이 정확)
  bool _isPastFestival(String endDate) {

    final parsed = DateTime.tryParse(endDate);

    if (parsed == null) return false;

    final today = DateTime.now();

    final todayDateOnly = DateTime(today.year, today.month, today.day);

    return parsed.isBefore(todayDateOnly);

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
      ..setBackgroundColor(Colors.white)
      ..loadHtmlString(html);

    _mapControllers[key] = controller;

    return controller;

  }

  // ⭐ onBeforeNavigate 추가: 풀스크린으로 넘어가기 직전 팝업(다이얼로그)을 먼저 닫음
  Widget _buildMapPreview({
    required String cacheKey,
    required double lat,
    required double lng,
    required String title,
    VoidCallback? onBeforeNavigate,
  }) {

    return GestureDetector(

      onTap: () {

        if (onBeforeNavigate != null) onBeforeNavigate();

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

          height: 150,

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

  void _showCsvFestivalPopup(Map<String, dynamic> item) {

    final String name = (item['name'] ?? '').toString();

    final String start = (item['start'] ?? '').toString();

    final String end = (item['end'] ?? '').toString();

    final String url = (item['url'] ?? '').toString();

    showDialog(
      context: context,
      builder: (dialogContext) {

        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: Icon(Icons.close_rounded, color: Colors.grey.shade400),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),

                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: primary.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(Icons.celebration_rounded, color: primary, size: 26),
                ),

                const SizedBox(height: 14),

                Text(
                  name.isEmpty ? "축제 정보" : name,
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.black87),
                ),

                const SizedBox(height: 8),

                if (start.isNotEmpty || end.isNotEmpty)

                  Row(
                    children: [
                      Icon(Icons.event_rounded, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Text(
                        "$start ~ $end",
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),

                const SizedBox(height: 20),

                if (url.isNotEmpty)

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _openUrl(url),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 18),
                      label: const Text(
                        "홈페이지 바로가기",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),

              ],
            ),
          ),
        );

      },
    );

  }

  void _showFestivalPopup(Map<String, dynamic> item) {

    final String name = (item['fstvlNm'] ?? '').toString();

    final String start = (item['fstvlStartDate'] ?? '').toString();

    final String end = (item['fstvlEndDate'] ?? '').toString();

    final String homepageUrl = (item['homepageUrl'] ?? '').toString();

    final double? lat = double.tryParse((item['latitude'] ?? '').toString());

    final double? lng = double.tryParse((item['longitude'] ?? '').toString());

    final bool hasLocation = lat != null && lng != null;

    showDialog(
      context: context,
      builder: (dialogContext) {

        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: Icon(Icons.close_rounded, color: Colors.grey.shade400),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),

                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(color: primary.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(Icons.celebration_rounded, color: primary, size: 26),
                  ),

                  const SizedBox(height: 14),

                  Text(
                    name.isEmpty ? "축제 정보" : name,
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.black87),
                  ),

                  const SizedBox(height: 8),

                  if (start.isNotEmpty || end.isNotEmpty)

                    Row(
                      children: [
                        Icon(Icons.event_rounded, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 6),
                        Text(
                          "$start ~ $end",
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),

                  if (hasLocation) ...[

                    const SizedBox(height: 16),

                    // ⭐ 지도 클릭 시 팝업(dialogContext)을 먼저 닫고 나서 풀스크린으로 이동
                    _buildMapPreview(
                      cacheKey: "festival_$name",
                      lat: lat,
                      lng: lng,
                      title: name,
                      onBeforeNavigate: () => Navigator.pop(dialogContext),
                    ),

                  ],

                  const SizedBox(height: 20),

                  if (homepageUrl.isNotEmpty)

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _openUrl(homepageUrl),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 18),
                        label: const Text(
                          "홈페이지 바로가기",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),

                ],
              ),
            ),
          ),
        );

      },
    );

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0xFFF7F7F9),

      appBar: AppBar(
        title: Text(
          '${widget.regionName} 콘텐츠',
          style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87, fontSize: 18),
        ),
        centerTitle: false,
        backgroundColor: const Color(0xFFF7F7F9),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),

      body: Column(
        children: [

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [

                Expanded(
                  child: _TabButton(
                    label: "콘텐츠",
                    icon: Icons.article_rounded,
                    selected: selectedTab == _ContentTopTab.content,
                    onTap: () => setState(() => selectedTab = _ContentTopTab.content),
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: _TabButton(
                    label: "축제",
                    icon: Icons.celebration_rounded,
                    selected: selectedTab == _ContentTopTab.festival,
                    onTap: () => setState(() => selectedTab = _ContentTopTab.festival),
                  ),
                ),

              ],
            ),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: selectedTab == _ContentTopTab.content
                ? _buildContentList()
                : _buildFestivalList(),
          ),

        ],
      ),

    );

  }

  Widget _buildContentList() {

    return FutureBuilder<List<Map<String, dynamic>>>(

      future: _contentFuture,

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
                Text("정보를 불러올 수 없습니다", style: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          );

        }

        final items = snapshot.data ?? [];

        if (items.isEmpty) {

          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.article_outlined, size: 56, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text("관련 콘텐츠가 없습니다", style: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          );

        }

        return ListView.separated(

          padding: const EdgeInsets.all(16),

          itemCount: items.length,

          separatorBuilder: (_, __) => const SizedBox(height: 10),

          itemBuilder: (context, index) {

            final item = items[index];

            final String title = (item['콘텐츠명'] ?? '').toString();

            final String header = (item['헤더 타이틀'] ?? '').toString();

            final String contentUrl = (item['콘텐츠 URL'] ?? '').toString();

            return InkWell(

              borderRadius: BorderRadius.circular(18),

              onTap: () => _openUrl(contentUrl),

              child: Container(

                padding: const EdgeInsets.all(16),

                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),

                child: Row(
                  children: [

                    _ContentThumbnail(contentUrl: contentUrl),

                    const SizedBox(width: 14),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          Text(
                            title.isEmpty ? "제목 없음" : title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87),
                          ),

                          if (header.isNotEmpty) ...[

                            const SizedBox(height: 4),

                            Text(
                              header,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                            ),

                          ],

                        ],
                      ),
                    ),

                    Icon(Icons.chevron_right_rounded, color: Colors.grey.shade300),

                  ],
                ),

              ),

            );

          },

        );

      },

    );

  }

  Widget _buildFestivalList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _csvFestivalFuture,
      builder: (context, csvSnapshot) {

        final csvItems = csvSnapshot.connectionState == ConnectionState.done
            ? (csvSnapshot.data ?? [])
            : <Map<String, dynamic>>[];

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _festivalFuture,
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
                    Text("정보를 불러올 수 없습니다", style: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontWeight: FontWeight.w500)),
                  ],
                ),
              );
            }
            final items = snapshot.data ?? [];

            final int totalCount = csvItems.length + items.length;

            if (totalCount == 0) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.celebration_outlined, size: 56, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text("올해 진행되는 관련 축제가 없습니다", style: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontWeight: FontWeight.w500)),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: totalCount,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {

                // ⭐ CSV 항목을 목록 맨 앞에 배치
                if (index < csvItems.length) {

                  final item = csvItems[index];

                  final String name = (item['name'] ?? '').toString();

                  final String start = (item['start'] ?? '').toString();

                  final String end = (item['end'] ?? '').toString();

                  final bool isPast = _isPastFestival(end);

                  final Widget csvCard = Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(color: primary.withOpacity(0.12), shape: BoxShape.circle),
                          child: Icon(Icons.celebration_rounded, color: primary, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name.isEmpty ? "이름 없음" : "$name의 축제 한눈에 보기!",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87),
                              ),
                              if (start.isNotEmpty || end.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.event_rounded, size: 12, color: Colors.grey.shade400),
                                    const SizedBox(width: 4),
                                    Text(
                                      "$start ~ $end",
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                                    ),
                                    if (isPast) ...[
                                      const SizedBox(width: 6),
                                      Text("(종료)", style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.w600)),
                                    ],
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: Colors.grey.shade300),
                      ],
                    ),
                  );

                  final Widget styledCsvCard = isPast
                      ? Opacity(
                    opacity: 0.6,
                    child: ColorFiltered(
                      colorFilter: const ColorFilter.matrix(_grayscaleMatrix),
                      child: csvCard,
                    ),
                  )
                      : csvCard;

                  return InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _showCsvFestivalPopup(item),
                    child: styledCsvCard,
                  );

                }

                // ⭐ 그 뒤로 기존 공공 API 축제 항목 이어서 표시
                final item = items[index - csvItems.length];

                final String name = (item['fstvlNm'] ?? '').toString();
                final String start = (item['fstvlStartDate'] ?? '').toString();
                final String end = (item['fstvlEndDate'] ?? '').toString();
                final bool isPast = _isPastFestival(end);

                final Widget card = Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: primary.withOpacity(0.12), shape: BoxShape.circle),
                        child: Icon(Icons.celebration_rounded, color: primary, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.isEmpty ? "이름 없음" : name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87),
                            ),
                            if (start.isNotEmpty || end.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.event_rounded, size: 12, color: Colors.grey.shade400),
                                  const SizedBox(width: 4),
                                  Text(
                                    "$start ~ $end",
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                                  ),
                                  if (isPast) ...[
                                    const SizedBox(width: 6),
                                    Text("(종료)", style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.w600)),
                                  ],
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: Colors.grey.shade300),
                    ],
                  ),
                );

                final Widget styledCard = isPast
                    ? Opacity(
                  opacity: 0.6,
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.matrix(_grayscaleMatrix),
                    child: card,
                  ),
                )
                    : card;

                return InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => _showFestivalPopup(item),
                  child: styledCard,
                );

              },
            );
          },
        );

      },
    );
  }

}

class _TabButton extends StatelessWidget {

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  static const Color primary = Color(0xFFFF7A00);

  @override
  Widget build(BuildContext context) {

    return GestureDetector(

      onTap: onTap,

      child: AnimatedContainer(

        duration: const Duration(milliseconds: 200),

        padding: const EdgeInsets.symmetric(vertical: 12),

        decoration: BoxDecoration(
          color: selected ? primary : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? primary : Colors.grey.shade200, width: 1.4),
          boxShadow: selected
              ? [BoxShadow(color: primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]
              : [],
        ),

        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : Colors.grey.shade500),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: selected ? Colors.white : Colors.grey.shade500),
            ),
          ],
        ),

      ),

    );

  }

}

class _ContentThumbnail extends StatefulWidget {

  final String contentUrl;

  const _ContentThumbnail({required this.contentUrl});

  @override
  State<_ContentThumbnail> createState() => _ContentThumbnailState();

}

class _ContentThumbnailState extends State<_ContentThumbnail> {

  static const Color primary = Color(0xFFFF7A00);

  late Future<String?> _imageFuture;

  @override
  void initState() {
    super.initState();
    _imageFuture = _fetchOgImage();
  }

  Future<String?> _fetchOgImage() async {

    if (widget.contentUrl.isEmpty) return null;

    try {

      final url = '${dotenv.env['PHP_URL']}content_image.php?url=${Uri.encodeComponent(widget.contentUrl)}';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        return data['image_url'];
      }

    } catch (e) {
      // 실패 시 조용히 null 반환
    }

    return null;

  }

  @override
  Widget build(BuildContext context) {

    return FutureBuilder<String?>(

      future: _imageFuture,

      builder: (context, snapshot) {

        final String? imageUrl = snapshot.data;

        if (snapshot.connectionState == ConnectionState.waiting) {

          return Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(14)),
            child: const Center(child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: primary))),
          );

        }

        if (imageUrl == null || imageUrl.isEmpty) {

          return Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: primary.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.article_rounded, color: primary, size: 22),
          );

        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.network(
            imageUrl,
            width: 56, height: 56,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 56, height: 56,
              decoration: BoxDecoration(color: primary.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.article_rounded, color: primary, size: 22),
            ),
          ),
        );

      },

    );

  }

}