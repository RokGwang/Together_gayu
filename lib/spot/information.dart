import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'photo.dart';
import 'spot.dart';

class InformationPage extends StatefulWidget {
  final String regionName;

  const InformationPage({super.key, required this.regionName});

  @override
  State<InformationPage> createState() => _InformationPageState();
}

class _InformationPageState extends State<InformationPage> {

  static const Color primary = Color(0xFFFF7A00);

  late Future<Map<String, dynamic>> _infoFuture;

  @override
  void initState() {
    super.initState();
    _infoFuture = _fetchInfo();
  }

  Future<Map<String, dynamic>> _fetchInfo() async {
    final infoUrl = '${dotenv.env['PHP_URL']}information.php?regionname=${Uri.encodeComponent(widget.regionName)}';
    final spotUrl = '${dotenv.env['PHP_URL']}information_spot.php?regionname=${Uri.encodeComponent(widget.regionName)}';

    final responses = await Future.wait([
      http.get(Uri.parse(infoUrl)),
      http.get(Uri.parse(spotUrl)),
    ]);

    if (responses[0].statusCode == 200) {
      final infoData = jsonDecode(responses[0].body);

      List<String> spotNames = [];
      if (responses[1].statusCode == 200) {
        final spotData = jsonDecode(responses[1].body);
        if (spotData['success'] == true && spotData['names'] != null) {
          spotNames = List<String>.from(spotData['names']);
        }
      }

      infoData['spot_names'] = spotNames;
      return infoData;
    } else {
      throw Exception('데이터 로드 실패');
    }
  }

  Widget _networkImage(String? url, {double? height}) {

    if (url == null || url.isEmpty) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: CachedNetworkImage(
        imageUrl: '${dotenv.env['PHP_URL']}api_photo.php?proxy_url=${Uri.encodeComponent(url)}',
        fit: BoxFit.cover,
        height: height,
        width: double.infinity,
        placeholder: (context, u) => Container(
          height: height,
          color: Colors.grey.shade100,
          child: Center(
            child: CircularProgressIndicator(strokeWidth: 2, color: primary),
          ),
        ),
        errorWidget: (context, u, error) => const SizedBox.shrink(),
      ),
    );

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      backgroundColor: const Color(0xFFF7F7F9),

      appBar: AppBar(
        title: Text(
          widget.regionName,
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

      body: FutureBuilder<Map<String, dynamic>>(
        future: _infoFuture,
        builder: (context, snapshot) {

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: primary));
          }

          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.containsKey('error')) {

            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline_rounded, size: 56, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text(
                    "정보를 불러올 수 없습니다",
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );

          }

          final data = snapshot.data!;
          final List<dynamic> images = data['images'];
          final List<String> spotNames = data['spot_names'] ?? [];

          final String? image1 = images.isNotEmpty ? images[0]?.toString() : null;
          final String? image2 = images.length > 1 ? images[1]?.toString() : null;
          final String? image3 = images.length > 2 ? images[2]?.toString() : null;
          final String? image4 = images.length > 3 ? images[3]?.toString() : null;
          final String? image5 = images.length > 4 ? images[4]?.toString() : null;

          final String? name2 = spotNames.isNotEmpty ? spotNames[0] : null;
          final String? name3 = spotNames.length > 1 ? spotNames[1] : null;
          final String? name4 = spotNames.length > 2 ? spotNames[2] : null;
          final String? name5 = spotNames.length > 3 ? spotNames[3] : null;

          return Column(
            children: [

              Expanded(
                child: SingleChildScrollView(

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ===== 이미지 1 (원래 크기 고정: height 지정) =====
                      if (image1 != null && image1.isNotEmpty)
                        _networkImage(image1, height: 240),

                      Padding(

                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),

                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [

                            // ===== subtext (글자 중간 나열) =====
                            Text(
                              data['subtext'] ?? '',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87,
                              ),
                            ),

                            const SizedBox(height: 10),

                            // ===== text (글자 중간 나열) =====
                            Text(
                              data['text'] ?? '',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                                height: 1.6,
                                fontWeight: FontWeight.w500,
                              ),
                            ),

                            const SizedBox(height: 24),

                            // ===== 이미지 2, 3 (원래 크기 고정: height 지정) 및 이름 표시 =====
                            if ((image2 != null && image2.isNotEmpty) || (image3 != null && image3.isNotEmpty))

                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [

                                  if (image2 != null && image2.isNotEmpty)
                                    Expanded(
                                      child: Column(
                                        children: [
                                          _networkImage(image2, height: 140),
                                          if (name2 != null) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              name2,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                                            ),
                                          ]
                                        ],
                                      ),
                                    ),

                                  if ((image2 != null && image2.isNotEmpty) && (image3 != null && image3.isNotEmpty))
                                    const SizedBox(width: 10),

                                  if (image3 != null && image3.isNotEmpty)
                                    Expanded(
                                      child: Column(
                                        children: [
                                          _networkImage(image3, height: 140),
                                          if (name3 != null) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              name3,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                                            ),
                                          ]
                                        ],
                                      ),
                                    ),

                                ],
                              ),

                            if ((image2 != null && image2.isNotEmpty) || (image3 != null && image3.isNotEmpty))
                              const SizedBox(height: 16),

                            // ===== 이미지 4, 5 (원래 크기 고정: height 지정) 및 이름 표시 =====
                            if ((image4 != null && image4.isNotEmpty) || (image5 != null && image5.isNotEmpty))

                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [

                                  if (image4 != null && image4.isNotEmpty)
                                    Expanded(
                                      child: Column(
                                        children: [
                                          _networkImage(image4, height: 140),
                                          if (name4 != null) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              name4,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                                            ),
                                          ]
                                        ],
                                      ),
                                    ),

                                  if ((image4 != null && image4.isNotEmpty) && (image5 != null && image5.isNotEmpty))
                                    const SizedBox(width: 10),

                                  if (image5 != null && image5.isNotEmpty)
                                    Expanded(
                                      child: Column(
                                        children: [
                                          _networkImage(image5, height: 140),
                                          if (name5 != null) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              name5,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                                            ),
                                          ]
                                        ],
                                      ),
                                    ),

                                ],
                              ),

                            const SizedBox(height: 24),

                          ],
                        ),

                      ),

                    ],
                  ),

                ),
              ),

              // ===== 하단 버튼 영역 =====
              Container(

                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),

                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),

                child: SafeArea(

                  top: false,

                  child: Row(
                    children: [

                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                builder: (context) => SpotPage(regionName: widget.regionName),
                            ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: primary.withOpacity(0.4)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: Icon(Icons.map_rounded, color: primary, size: 18),
                          label: Text(
                            '관광지 목록',
                            style: TextStyle(color: primary, fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {

                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => PhotoPage(regionName: widget.regionName)),
                            );

                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 18),
                          label: const Text(
                            '갤러리',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        ),
                      ),

                    ],
                  ),

                ),

              ),

            ],
          );
        },
      ),
    );
  }
}