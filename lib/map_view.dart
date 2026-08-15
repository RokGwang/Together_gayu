import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MapViewPage extends StatefulWidget {
  final double lat;
  final double lng;
  final String title;
  const MapViewPage({
    super.key,
    required this.lat,
    required this.lng,
    required this.title,
  });
  @override
  State<MapViewPage> createState() => _MapViewPageState();
}

class _MapViewPageState extends State<MapViewPage> {
  late final WebViewController controller;
  final String jsKey = dotenv.env['kakaojava'] ?? '';
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    final html = _buildHtml();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..addJavaScriptChannel(
        'DebugChannel',
        onMessageReceived: (message) {
          debugPrint("🗺️ 카카오맵 JS 로그: ${message.message}");
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            debugPrint("🗺️ 페이지 로드 시작: $url");
          },
          onPageFinished: (url) {
            debugPrint("🗺️ 페이지 로드 완료: $url");
            if (mounted) {
              setState(() {
                isLoading = false;
              });
            }
          },
          onWebResourceError: (error) {
            debugPrint("🗺️ WebView 에러: ${error.description} (코드: ${error.errorCode}, 타입: ${error.errorType})");
            if (mounted) {
              setState(() {
                isLoading = false;
                errorMessage = "${error.description}";
              });
            }
          },
        ),
      )
      ..loadHtmlString(html);
  }

  String _buildHtml() {
    return """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <style>
        html, body, #map { width: 100%; height: 100%; margin: 0; padding: 0; }
      </style>
    </head>
    <body>
      <div id="map"></div>
      <script src="https://dapi.kakao.com/v2/maps/sdk.js?appkey=$jsKey"></script>
      <script>
        try {
          if (typeof kakao === 'undefined') {
            DebugChannel.postMessage('kakao SDK 로드 실패 - appkey 확인 필요');
          } else {

            var markerPosition = new kakao.maps.LatLng(${widget.lat}, ${widget.lng});

            var container = document.getElementById('map');
            var options = {
              center: markerPosition,
              level: 3
            };
            var map = new kakao.maps.Map(container, options);

            var marker = new kakao.maps.Marker({ position: markerPosition });
            marker.setMap(map);

            var infowindow = new kakao.maps.InfoWindow({
              content: '<div style="padding:6px 10px;font-size:13px;">${widget.title}</div>'
            });
            infowindow.open(map, marker);

            // ⭐ 인포윈도우가 열리면서 자동으로 지도가 위로 밀리는 현상 보정
            // -> 인포윈도우를 연 직후, 마커 위치로 강제로 다시 중앙정렬
            map.setCenter(markerPosition);

            // ⭐ WebView 레이아웃이 완전히 확정된 이후 한 번 더 재계산
            // (컨테이너 크기가 늦게 확정될 때 마커가 중앙에서 벗어나는 문제 보정)
            setTimeout(function() {
              map.relayout();
              map.setCenter(markerPosition);
            }, 150);

            DebugChannel.postMessage('지도 렌더링 성공');
          }
        } catch (e) {
          DebugChannel.postMessage('JS 에러: ' + e.message);
        }
      </script>
    </body>
    </html>
    """;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: const Color(0xFFF7F7F9),
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: controller),
          if (isLoading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF7A00)),
            ),
          if (errorMessage != null)
            Center(
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40),
                    const SizedBox(height: 12),
                    const Text(
                      "지도를 불러오지 못했습니다",
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}