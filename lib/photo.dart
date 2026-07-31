import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class PhotoPage extends StatefulWidget {
  final String regionName;

  const PhotoPage({
    super.key,
    required this.regionName,
  });

  @override
  State<PhotoPage> createState() => _PhotoPageState();
}

class _PhotoPageState extends State<PhotoPage> {
  late Future<List<dynamic>> _photoFuture;
  final ScrollController _scrollController = ScrollController();
  double _sliderValue = 0.0;

  @override
  void initState() {
    super.initState();
    _photoFuture = fetchFilteredPhotos();

    // 스크롤 위치에 따라 슬라이더 값 업데이트
    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        setState(() {
          _sliderValue = _scrollController.offset;
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<List<dynamic>> fetchFilteredPhotos() async {
    try {
      final url = '${dotenv.env['PHP_URL']}api_photo2.php?keyword=${Uri.encodeComponent(widget.regionName)}&numOfRows=800';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final itemsContainer = data['response']?['body']?['items'];
        if (itemsContainer == null || itemsContainer is String) return [];

        List<dynamic> items = (itemsContainer['item'] is List) ? itemsContainer['item'] : [itemsContainer['item']];

        return items.where((item) {
          String location = item['galPhotographyLocation'] ?? '';
          return location.contains(widget.regionName);
        }).toList();
      }
    } catch (e) {
      debugPrint('통신 오류: $e');
    }
    return [];
  }

  void _showFullImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            color: Colors.black.withOpacity(0.8),
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('${widget.regionName}의 사진들'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _photoFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFFF7A00)));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("관련 사진이 없습니다."));
          }

          final photos = snapshot.data!;

          return Column(
            children: [
              // 1. 그리드 뷰 (연속 스크롤)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: GridView.builder(
                    controller: _scrollController,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: photos.length,
                    itemBuilder: (context, index) {
                      final String originalUrl = photos[index]['galWebImageUrl'] ?? '';
                      final String proxyUrl = '${dotenv.env['PHP_URL']}api_photo2.php?proxy_url=${Uri.encodeComponent(originalUrl)}';

                      return InkWell(
                        onTap: () => _showFullImage(proxyUrl),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            proxyUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image)),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // 2. 사진 바로 밑에 위치한 슬라이더
              if (_scrollController.hasClients && _scrollController.position.maxScrollExtent > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Slider(
                    activeColor: const Color(0xFFFF7A00),
                    inactiveColor: Colors.grey.shade300,
                    min: 0,
                    max: _scrollController.position.maxScrollExtent,
                    value: _sliderValue.clamp(0.0, _scrollController.position.maxScrollExtent),
                    onChanged: (value) {
                      _scrollController.jumpTo(value);
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