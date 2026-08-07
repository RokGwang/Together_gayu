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

  final String jsKey = "${dotenv.env['kakaojava']}";

  @override
  void initState() {

    super.initState();

    final html = _buildHtml();

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
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
        var container = document.getElementById('map');
        var options = {
          center: new kakao.maps.LatLng(${widget.lat}, ${widget.lng}),
          level: 3
        };
        var map = new kakao.maps.Map(container, options);

        var markerPosition = new kakao.maps.LatLng(${widget.lat}, ${widget.lng});
        var marker = new kakao.maps.Marker({ position: markerPosition });
        marker.setMap(map);

        var infowindow = new kakao.maps.InfoWindow({
          content: '<div style="padding:6px 10px;font-size:13px;">${widget.title}</div>'
        });
        infowindow.open(map, marker);
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

      body: WebViewWidget(controller: controller),

    );

  }

}