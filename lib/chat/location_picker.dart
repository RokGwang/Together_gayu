import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class LocationPickerPage extends StatefulWidget {

  const LocationPickerPage({super.key});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {

  static const Color primary = Color(0xFFFF7A00);

  final String jsKey = "${dotenv.env['kakaojava']}";

  WebViewController? controller;

  bool isLoading = true;

  double? selectedLat;
  double? selectedLng;

  @override
  void initState() {

    super.initState();

    _init();

  }

  Future<void> _init() async {

    var status = await Permission.location.status;

    if (!status.isGranted) {
      status = await Permission.location.request();
    }

    if (!status.isGranted) {

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("위치 권한이 필요합니다")),
      );

      Navigator.pop(context);

      return;

    }

    try {

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      selectedLat = position.latitude;
      selectedLng = position.longitude;

      _buildController();

    } catch (e) {

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("위치를 가져올 수 없습니다: $e")),
      );

      Navigator.pop(context);

    }

  }

  void _buildController() {

    final html = _buildHtml(selectedLat!, selectedLng!);

    final ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (message) {

          final parts = message.message.split(",");

          if (parts.length == 2) {

            setState(() {
              selectedLat = double.tryParse(parts[0]) ?? selectedLat;
              selectedLng = double.tryParse(parts[1]) ?? selectedLng;
            });

          }

        },
      )
      ..loadHtmlString(html);

    setState(() {
      controller = ctrl;
      isLoading = false;
    });

  }

  String _buildHtml(double lat, double lng) {

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
        var container = document.getElementById('map');
        var options = {
          center: new kakao.maps.LatLng($lat, $lng),
          level: 3
        };
        var map = new kakao.maps.Map(container, options);

        var marker = new kakao.maps.Marker({
          position: new kakao.maps.LatLng($lat, $lng),
          draggable: true
        });
        marker.setMap(map);

        kakao.maps.event.addListener(marker, 'dragend', function() {
          var pos = marker.getPosition();
          FlutterChannel.postMessage(pos.getLat() + "," + pos.getLng());
        });

        // 지도를 탭해도 마커가 그 위치로 이동
        kakao.maps.event.addListener(map, 'click', function(mouseEvent) {
          var latlng = mouseEvent.latLng;
          marker.setPosition(latlng);
          FlutterChannel.postMessage(latlng.getLat() + "," + latlng.getLng());
        });
      </script>
    </body>
    </html>
    """;

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text(
          '위치 선택',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87, fontSize: 18),
        ),
        backgroundColor: const Color(0xFFF7F7F9),
        elevation: 0,
        foregroundColor: Colors.black87,
      ),

      body: isLoading || controller == null

          ? const Center(child: CircularProgressIndicator(color: primary))

          : Stack(

        children: [

          WebViewWidget(controller: controller!),

          Positioned(

            left: 20,
            right: 20,
            bottom: 20,

            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {

                  Navigator.pop(context, {
                    "lat": selectedLat,
                    "lng": selectedLng,
                  });

                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(
                  '이 위치로 보내기',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),

          ),

        ],

      ),

    );

  }

}