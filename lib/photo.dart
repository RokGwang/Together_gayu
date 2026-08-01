import 'dart:convert';
import 'dart:ui'; // [수정] 블러 처리를 위해 추가
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
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _photoFuture = fetchFilteredPhotos();
  }

  @override
  void dispose() {
    _pageController.dispose();
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

  void _showFullImage(Map<String, dynamic> photo) {
    final String originalUrl = photo['galWebImageUrl'] ?? '';
    final String proxyUrl = '${dotenv.env['PHP_URL']}api_photo2.php?proxy_url=${Uri.encodeComponent(originalUrl)}';

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            color: Colors.black.withOpacity(0.6),
            child: Center(
              // [수정] 팝업 내용을 SingleChildScrollView로 감싸서 내용이 길어도 스크롤 가능하게 함
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min, // 내용물 높이만큼만 팝업 크기 조절
                  children: [
                    // 이미지 영역
                    InteractiveViewer(
                      clipBehavior: Clip.none,
                      child: Image.network(
                        proxyUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // 텍스트 정보 투명 팝업
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      width: double.infinity,
                      child: Row(
                        children: [
                          // 1. 텍스트 정보 영역 (Expanded를 사용하여 버튼 밀림 방지)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  photo['galTitle'] ?? '제목 없음',
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "작가: ${photo['galPhotographer'] ?? '정보 없음'}",
                                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                              ],
                            ),
                          ),

                          // 2. 우측 버튼 영역
                          Column(
                            children: [
                              // GPS 마커 버튼
                              IconButton(
                                icon: const Icon(Icons.location_on, color: Colors.white, size: 24),
                                onPressed: () {
                                  // GPS 버튼 클릭 시 동작
                                },
                                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                padding: EdgeInsets.zero,
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.white.withOpacity(0.2),
                                  shape: const CircleBorder(),
                                ),
                              ),
                              const SizedBox(height: 10), // 버튼 간 간격
                              // 돋보기 버튼
                              IconButton(
                                icon: const Icon(Icons.search, color: Colors.white, size: 24),
                                onPressed: () {
                                  // 돋보기 버튼 클릭 시 동작
                                },
                                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                padding: EdgeInsets.zero,
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.white.withOpacity(0.2),
                                  shape: const CircleBorder(),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
          final int totalPages = (photos.length / 9).ceil();

          return Column(
            children: [
              // 1. PageView: Expanded로 그리드 영역 확보
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemCount: totalPages,
                  itemBuilder: (context, pageIndex) {
                    final int start = pageIndex * 9;
                    final int end = (start + 9 > photos.length) ? photos.length : start + 9;
                    final List<dynamic> pagePhotos = photos.sublist(start, end);

                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: pagePhotos.length,
                        itemBuilder: (context, index) {
                          final String originalUrl = pagePhotos[index]['galWebImageUrl'] ?? '';
                          final String proxyUrl = '${dotenv.env['PHP_URL']}api_photo2.php?proxy_url=${Uri.encodeComponent(originalUrl)}';

                          return InkWell(
                            onTap: () => _showFullImage(pagePhotos[index]), // 전체 데이터 전달
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                '${dotenv.env['PHP_URL']}api_photo2.php?proxy_url=${Uri.encodeComponent(pagePhotos[index]['galWebImageUrl'] ?? '')}',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image)),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),

              // 2. [수정] 슬라이더 위치: Grid 바로 밑에 붙이기 위해 Padding 조정
              if (totalPages > 1)
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, bottom: 30, top: 0),
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    ),
                    child: Slider(
                      activeColor: const Color(0xFFFF7A00),
                      inactiveColor: Colors.grey.shade200,
                      min: 0,
                      max: (totalPages - 1).toDouble(),
                      divisions: totalPages > 1 ? totalPages - 1 : 1,
                      value: _currentPage.toDouble().clamp(0, (totalPages - 1).toDouble()),
                      onChanged: (value) {
                        _pageController.animateToPage(
                          value.toInt(),
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                        setState(() {
                          _currentPage = value.toInt();
                        });
                      },
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