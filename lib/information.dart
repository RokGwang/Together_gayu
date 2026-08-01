import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'photo.dart';

class InformationPage extends StatefulWidget {
  final String regionName;

  const InformationPage({super.key, required this.regionName});

  @override
  State<InformationPage> createState() => _InformationPageState();
}

class _InformationPageState extends State<InformationPage> {
  late Future<Map<String, dynamic>> _infoFuture;

  @override
  void initState() {
    super.initState();
    _infoFuture = _fetchInfo();
  }

  Future<Map<String, dynamic>> _fetchInfo() async {
    final url = '${dotenv.env['PHP_URL']}information.php?regionname=${Uri.encodeComponent(widget.regionName)}';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('데이터 로드 실패');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.regionName} 정보')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _infoFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.containsKey('error')) {
            return const Center(child: Text("정보를 불러올 수 없습니다."));
          }

          final data = snapshot.data!;
          final List<dynamic> images = data['images'];

          return Column(
            children: [
              // 1. 상단 정보 영역 (스크롤 가능)
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['subtext'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Text(data[''], style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 20),
                      Text(data['text'], style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 20),
                      // 이미지 5개 출력
                      ...images.where((img) => img != null && img.toString().isNotEmpty).map((img) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              // 원본 URL(img)을 api_photo2.php?proxy_url=... 형태로 감싸서 보냅니다.
                              imageUrl: '${dotenv.env['PHP_URL']}api_photo2.php?proxy_url=${Uri.encodeComponent(img)}',
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) => const SizedBox.shrink(),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              // 2. 하단 버튼 영역
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildIconButton(icon: Icons.map_rounded, label: '지도 보기', onPressed: () {}),
                    const SizedBox(width: 40),
                    _buildIconButton(
                      icon: Icons.photo_library_rounded,
                      label: '갤러리',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => PhotoPage(regionName: widget.regionName)),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildIconButton({required IconData icon, required String label, required VoidCallback onPressed}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: 40, color: const Color(0xFFFF7A00)),
          padding: const EdgeInsets.all(16),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFFF7A00).withOpacity(0.1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}