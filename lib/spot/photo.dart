import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import '../map_view.dart';

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
  static const Color primary = Color(0xFFFF7A00);
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

  // ⭐ 로딩 다이얼로그(showDialog) 완전 제거 -> pop 후 fetch, 그 다음 push 한 번만.
  // spot2.dart의 "미리보기 탭 -> 바로 push"와 동일한 구조.
  Future<void> _goToMap(String title) async {

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("장소명 정보가 없습니다")),
      );
      return;
    }

    // 로딩 안내는 스낵바로만 (네비게이터 스택을 건드리지 않음)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("위치를 찾는 중이에요..."),
        duration: Duration(seconds: 2),
      ),
    );

    try {

      final url = '${dotenv.env['PHP_URL']}photo.php'
          '?title=${Uri.encodeComponent(title)}'
          '&regionname=${Uri.encodeComponent(widget.regionName)}';

      final response = await http.get(Uri.parse(url));

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (data["success"] == true) {

        // ⭐ 여기서 pop 없이, 순수 push 한 번만 실행 (spot2.dart와 동일)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MapViewPage(
              lat: (data["lat"] as num).toDouble(),
              lng: (data["lng"] as num).toDouble(),
              title: title,
            ),
          ),
        );

      } else {

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data["message"] ?? "위치를 찾을 수 없습니다")),
        );

      }

    } catch (e) {

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("에러 발생: $e")),
      );

    }

  }

  Future<List<dynamic>> fetchFilteredPhotos() async {
    try {
      final url = '${dotenv.env['PHP_URL']}api_photo.php?keyword=${Uri.encodeComponent(widget.regionName)}&numOfRows=800';
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
    final String proxyUrl = '${dotenv.env['PHP_URL']}api_photo.php?proxy_url=${Uri.encodeComponent(originalUrl)}';
    final String title = (photo['galTitle'] ?? '').toString().trim();

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            color: Colors.black.withOpacity(0.65),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: GestureDetector(
                  onTap: () {}, // 내부 탭은 닫힘 방지
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: InteractiveViewer(
                          clipBehavior: Clip.none,
                          child: CachedNetworkImage(
                            imageUrl: proxyUrl,
                            fit: BoxFit.contain,
                            placeholder: (context, url) => const SizedBox(
                              height: 200,
                              child: Center(
                                child: CircularProgressIndicator(color: Colors.white),
                              ),
                            ),
                            errorWidget: (context, url, error) => const SizedBox(
                              height: 200,
                              child: Icon(Icons.broken_image_rounded, color: Colors.white, size: 40),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white.withOpacity(0.15)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    photo['galTitle'] ?? '제목 없음',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "id · ${photo['galContentId'] ?? '정보 없음'}",
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "작가 · ${photo['galPhotographer'] ?? '정보 없음'}",
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            _blurIconButton(
                              icon: Icons.location_on_rounded,
                              onTap: () {
                                // ⭐ 팝업만 닫고, 곧바로 fetch -> push (그 사이에 다른 다이얼로그 없음)
                                Navigator.pop(context);
                                _goToMap(title);
                              },
                            ),
                            const SizedBox(width: 8),
                            _blurIconButton(
                              icon: Icons.search_rounded,
                              onTap: () {},
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
      ),
    );
  }

  Widget _blurIconButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      appBar: AppBar(
        title: Text(
          '${widget.regionName}의 사진',
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
      body: FutureBuilder<List<dynamic>>(
        future: _photoFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: primary));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_outlined, size: 56, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text(
                    "관련 사진이 없습니다",
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          }
          final photos = snapshot.data!;
          final int totalPages = (photos.length / 9).ceil();
          return Column(
            children: [
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
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: pagePhotos.length,
                        itemBuilder: (context, index) {
                          return InkWell(
                            onTap: () => _showFullImage(pagePhotos[index]),
                            borderRadius: BorderRadius.circular(12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: '${dotenv.env['PHP_URL']}api_photo.php?proxy_url=${Uri.encodeComponent(pagePhotos[index]['galWebImageUrl'] ?? '')}',
                                fit: BoxFit.cover,
                                memCacheWidth: 200,
                                placeholder: (context, url) => Container(
                                  color: Colors.grey.shade100,
                                  child: const Center(
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: primary),
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.grey.shade100,
                                  child: Icon(Icons.broken_image_rounded, color: Colors.grey.shade400, size: 18),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
              if (totalPages > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Row(
                    children: [
                      Text(
                        "${_currentPage + 1}",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: primary),
                      ),
                      Text(
                        " / $totalPages",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade400),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            activeTrackColor: primary,
                            inactiveTrackColor: Colors.grey.shade200,
                            thumbColor: primary,
                            overlayColor: primary.withOpacity(0.15),
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                          ),
                          child: Slider(
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
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}