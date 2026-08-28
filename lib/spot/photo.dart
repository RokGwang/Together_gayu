import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  bool _favoritesOnly = false;
  Set<String> _favoriteIds = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _photoFuture = fetchFilteredPhotos();
    _loadFavorites();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ⭐ 검색어/즐겨찾기 필터가 바뀔 때마다 페이지 위치를 처음으로 리셋
  void _resetPageToStart() {

    _currentPage = 0;

    WidgetsBinding.instance.addPostFrameCallback((_) {

      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }

    });

  }

  // =========================
  // 즐겨찾기 (기기 로컬 저장 - 지역별로 구분)
  // =========================
  String get _favoriteStorageKey => 'photo_favorites_${widget.regionName}';

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_favoriteStorageKey) ?? [];
    if (!mounted) return;
    setState(() {
      _favoriteIds = saved.toSet();
    });
  }

  Future<void> _persistFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoriteStorageKey, _favoriteIds.toList());
  }

  void _toggleFavorite(String contentId) {
    setState(() {
      if (_favoriteIds.contains(contentId)) {
        _favoriteIds.remove(contentId);
      } else {
        _favoriteIds.add(contentId);
      }
    });
    _persistFavorites();
  }

  // =========================
  // 위치 찾기 (기존 그대로)
  // =========================
  Future<void> _goToMap(String title) async {
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("장소명 정보가 없습니다")),
      );
      return;
    }
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

  // =========================
  // 공유
  // =========================
  Future<void> _sharePhoto(Map<String, dynamic> photo) async {
    final String title = (photo['galTitle'] ?? '사진').toString();
    final String url = (photo['galWebImageUrl'] ?? '').toString();
    await Share.share('$title\n$url', subject: title);
  }

  // =========================
  // 데이터 조회
  // =========================
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

  // =========================
  // 사진 크게보기 (안정적인 롤백 버전 + 즐겨찾기/공유 연결)
  // =========================
  void _showFullImage(Map<String, dynamic> photo) {
    final String originalUrl = photo['galWebImageUrl'] ?? '';
    final String proxyUrl = '${dotenv.env['PHP_URL']}api_photo.php?proxy_url=${Uri.encodeComponent(originalUrl)}';
    final String contentId = (photo['galContentId'] ?? '').toString();
    final String title = (photo['galTitle'] ?? '').toString().trim();

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {

          final bool isFavorite = _favoriteIds.contains(contentId);

          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                color: Colors.black.withOpacity(0.6),
                child: Stack(
                  children: [
                    Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                        child: GestureDetector(
                          onTap: () {}, // 내부 탭은 닫힘 방지
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InteractiveViewer(
                                clipBehavior: Clip.none,
                                child: Image.network(
                                  proxyUrl,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white),
                                ),
                              ),
                              const SizedBox(height: 15),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                width: double.infinity,
                                child: Row(
                                  children: [
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
                                          const SizedBox(height: 8),
                                          Text(
                                            "ID: ${photo['galContentId'] ?? '정보 없음'}",
                                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.location_on, color: Colors.white, size: 24),
                                          onPressed: () {
                                            Navigator.pop(context);
                                            _goToMap(title);
                                          },
                                          padding: EdgeInsets.zero,
                                          style: IconButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.2), shape: const CircleBorder()),
                                        ),
                                        const SizedBox(height: 10),
                                        IconButton(
                                          // ⭐ 검색 아이콘 -> 즐겨찾기로 교체
                                          icon: Icon(
                                            isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                            color: isFavorite ? Colors.redAccent : Colors.white,
                                            size: 24,
                                          ),
                                          onPressed: () {
                                            _toggleFavorite(contentId);
                                            setDialogState(() {}); // 팝업 내 아이콘 즉시 갱신
                                          },
                                          padding: EdgeInsets.zero,
                                          style: IconButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.2), shape: const CircleBorder()),
                                        ),
                                        const SizedBox(height: 10),
                                        IconButton(
                                          // ⭐ 공유 버튼 추가
                                          icon: const Icon(Icons.ios_share_rounded, color: Colors.white, size: 24),
                                          onPressed: () => _sharePhoto(photo),
                                          padding: EdgeInsets.zero,
                                          style: IconButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.2), shape: const CircleBorder()),
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
                    // 닫기 버튼
                    Positioned(
                      top: 12,
                      right: 12,
                      child: SafeArea(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

        },
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
          final allPhotos = snapshot.data!;
          final List<dynamic> photos = allPhotos.where((p) {
            final String contentId = (p['galContentId'] ?? '').toString();
            if (_favoritesOnly && !_favoriteIds.contains(contentId)) return false;
            if (_searchQuery.isNotEmpty) {
              final String title = (p['galTitle'] ?? '').toString().toLowerCase();
              final String keyword = (p['galSearchKeyword'] ?? '').toString().toLowerCase();
              final String q = _searchQuery.toLowerCase();
              if (!title.contains(q) && !keyword.contains(q)) return false;
            }
            return true;
          }).toList();
          final int totalPages = (photos.length / 9).ceil();
          return Column(
            children: [
              // ===== 검색창 + 즐겨찾기 토글 =====
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                              _resetPageToStart(); // ⭐ 검색어 변경 시 스크롤/페이지 리셋
                            });
                          },
                          decoration: InputDecoration(
                            hintText: "사진 제목으로 검색",
                            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                            prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 20),
                            suffixIcon: _searchQuery.isEmpty
                                ? null
                                : IconButton(
                              icon: Icon(Icons.close_rounded, color: Colors.grey.shade400, size: 18),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = "";
                                  _resetPageToStart(); // ⭐ 검색어 초기화 시에도 리셋
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _favoritesOnly = !_favoritesOnly;
                          _resetPageToStart(); // ⭐ 즐겨찾기 필터 전환 시에도 리셋
                        });
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _favoritesOnly ? Colors.redAccent : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          _favoritesOnly ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: _favoritesOnly ? Colors.white : Colors.grey.shade400,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // ===== 사진 개수 표시 =====
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Row(
                  children: [
                    Icon(Icons.photo_library_outlined, size: 14, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text(
                      "${photos.length}장의 사진",
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: photos.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _favoritesOnly ? Icons.favorite_border_rounded : Icons.search_off_rounded,
                        size: 56,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _favoritesOnly ? "즐겨찾기한 사진이 없어요" : "검색 결과가 없어요",
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                )
                    : PageView.builder(
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
                          final String contentId = (pagePhotos[index]['galContentId'] ?? '').toString();
                          final bool isFavorite = _favoriteIds.contains(contentId);
                          return InkWell(
                            onTap: () => _showFullImage(pagePhotos[index]),
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              children: [

                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: CachedNetworkImage(
                                    imageUrl: '${dotenv.env['PHP_URL']}api_photo.php?proxy_url=${Uri.encodeComponent(pagePhotos[index]['galWebImageUrl'] ?? '')}',
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
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

                                // ⭐ 그리드에도 즐겨찾기 표시(읽기 전용 뱃지)
                                if (isFavorite)
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.45),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 12),
                                    ),
                                  ),

                              ],
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