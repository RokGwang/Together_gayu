import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:together_gayu/spot/photo.dart';
import 'room.dart';
import 'tab_widget/widget.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'spot/information.dart'; // 이 줄이 없으면 추가하세요.
import 'dart:ui';
import 'up.dart';
import 'dart:async';
import 'tab_widget/festival_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ===== 지역 정보 모델 =====
class RegionInfo {

  final String id;        // room.php 등에 넘길 roomTable 값 (영문)

  final String name;      // 화면에 표시할 지역명 (한글)

  final double leftRatio;  // 지도 위 가로 위치 비율 (0~1)

  final double topRatio;   // 지도 위 세로 위치 비율 (0~1)

  const RegionInfo({
    required this.id,
    required this.name,
    required this.leftRatio,
    required this.topRatio,
  });

}

class IntroPage extends StatefulWidget {
  final int userId;

  const IntroPage({
    super.key,
    required this.userId,
  });

  @override
  State<IntroPage> createState() => _IntroPageState();
}



class _IntroPageState extends State<IntroPage> {

  Future<List<dynamic>> fetchPhotosByRegion(String regionName) async {
    try {
      final url = '${dotenv.env['PHP_URL']}api_photo.php?keyword=${Uri.encodeComponent(regionName)}&numOfRows=1000';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // 1. response -> body -> items 경로가 존재하는지 확인
        final responseData = data['response'];
        if (responseData == null) return [];

        final body = responseData['body'];
        if (body == null) return [];

        final itemsContainer = body['items'];
        // 데이터가 없는 경우 items 자체가 ""(빈 문자열)로 올 때가 있습니다.
        if (itemsContainer == null || itemsContainer is String) return [];

        final items = itemsContainer['item'];
        if (items == null) return [];

        // 2. 리스트 형태라면 그대로 반환, 단일 객체라면 리스트로 감싸서 반환
        return (items is List) ? items : [items];
      }
    } catch (e) {
      debugPrint('통신 및 파싱 오류: $e');
    }
    return [];
  }

  Future<List<dynamic>> fetchGalleryByRegion(String regionName) async {
    try {
      // 1. popup.php를 호출하여 해당 지역의 pre_image ID 3개 가져오기
      final popupUrl = '${dotenv.env['PHP_URL']}popup.php?name=${Uri.encodeComponent(regionName)}';
      final popupResponse = await http.get(Uri.parse(popupUrl));

      List<String> targetIds = [];
      if (popupResponse.statusCode == 200) {
        final popupData = jsonDecode(popupResponse.body);
        if (popupData['pre_images'] != null) {
          targetIds = List<String>.from(popupData['pre_images']);
        }
      }

      // 만약 CSV에 등록된 ID가 없다면 빈 리스트 반환
      if (targetIds.isEmpty) return [];

      // 2. api_photo.php를 호출하여 numOfRows=1000으로 데이터 대량 가져오기
      final photoUrl = '${dotenv.env['PHP_URL']}api_photo.php?keyword=${Uri.encodeComponent(regionName)}&numOfRows=1000';
      final response = await http.get(Uri.parse(photoUrl));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final responseData = data['response'];
        if (responseData == null) return [];

        final body = responseData['body'];
        if (body == null) return [];

        final itemsContainer = body['items'];
        if (itemsContainer == null || itemsContainer is String) return [];

        final items = itemsContainer['item'];
        if (items == null) return [];

        List<dynamic> allPhotos = (items is List) ? items : [items];

        // 3. targetIds(pre_image1, 2, 3)에 포함된 galContentId만 순서대로 필터링하여 최대 3개 추출
        List<dynamic> filteredPhotos = [];
        for (String id in targetIds) {
          try {
            final match = allPhotos.firstWhere(
                  (photo) => photo['galContentId'].toString() == id,
            );
            filteredPhotos.add(match);
          } catch (e) {
            // 일치하는 ID가 없으면 무시
          }
        }

        return filteredPhotos;
      }
    } catch (e) {
      debugPrint('통신 오류: $e');
    }
    return [];
  }

  static const Color primary = Color(0xFFFF7A00);

  // ===== 지역 목록 (일단 균등 배치, 위치는 나중에 조정) =====
  static const List<RegionInfo> regions = [

    RegionInfo(id: "cheonan",    name: "천안", leftRatio: 0.76, topRatio: 0.22),
    RegionInfo(id: "asan",       name: "아산", leftRatio: 0.60, topRatio: 0.24),
    RegionInfo(id: "dangjin",    name: "당진", leftRatio: 0.40, topRatio: 0.20),
    RegionInfo(id: "seosan",     name: "서산", leftRatio: 0.28, topRatio: 0.26),
    RegionInfo(id: "taean",      name: "태안", leftRatio: 0.16, topRatio: 0.30),
    RegionInfo(id: "yesan",      name: "예산", leftRatio: 0.50, topRatio: 0.34),
    RegionInfo(id: "hongseong",  name: "홍성", leftRatio: 0.38, topRatio: 0.44),
    RegionInfo(id: "cheongyang", name: "청양", leftRatio: 0.50, topRatio: 0.52),
    RegionInfo(id: "gongju",     name: "공주", leftRatio: 0.66, topRatio: 0.48),
    RegionInfo(id: "boryeong",   name: "보령", leftRatio: 0.36, topRatio: 0.60),
    RegionInfo(id: "buyeo",      name: "부여", leftRatio: 0.54, topRatio: 0.68),
    RegionInfo(id: "seocheon",   name: "서천", leftRatio: 0.44, topRatio: 0.80),
    RegionInfo(id: "nonsan",     name: "논산", leftRatio: 0.70, topRatio: 0.72),
    RegionInfo(id: "gyeryong",   name: "계룡", leftRatio: 0.78, topRatio: 0.66),
    RegionInfo(id: "geumsan",    name: "금산", leftRatio: 0.92, topRatio: 0.80),

  ];

  Future<Map<String, String>> fetchRegionData(String regionName) async {
    try {
      // popup.php 호출
      final url = '${dotenv.env['PHP_URL']}popup.php?name=${Uri.encodeComponent(regionName)}';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'subtext': data['subtext'] ?? '',
          'text': data['text'] ?? '${regionName}의 여행지로 함께 이동할\n사람들을 찾아보세요'
        };
      }
    } catch (e) {
      debugPrint('PHP 로드 오류: $e');
    }
    return {
      'subtext': '',
      'text': '${regionName}의 여행지로 함께 이동할\n사람들을 찾아보세요'
    };
  }

  @override
  void initState() {

    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {

      OnboardingPopup.showOnce(
        context: context,
        userId: widget.userId,
        popupKey: "mainview",
        title: "같이가유에 오신 걸 환영해요!",
        message: "지도 위 지역을 눌러서\n같은 목적지로 가는 사람들과 채팅방을 만들어보세요",
        icon: Icons.celebration_rounded,
      );

    });

  }

  void _showFullImage(Map<String, dynamic> photo) {
    final String originalUrl = photo['galWebImageUrl'] ?? '';
    final String proxyUrl = '${dotenv.env['PHP_URL']}api_photo.php?proxy_url=${Uri.encodeComponent(originalUrl)}';

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            color: Colors.black.withOpacity(0.6),
            child: Stack( // ⭐ Center를 Stack으로 감싸서 닫기 버튼 배치 공간 확보
              children: [

                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                    child: GestureDetector(
                      onTap: () {}, // ⭐ 내부 탭은 닫힘 방지 (닫기 버튼 오작동 방지용으로 추가)
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
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.location_on, color: Colors.white, size: 24),
                                      onPressed: () { /* GPS 동작 */ },
                                      padding: EdgeInsets.zero,
                                      style: IconButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.2), shape: const CircleBorder()),
                                    ),
                                    const SizedBox(height: 10),
                                    IconButton(
                                      icon: const Icon(Icons.search, color: Colors.white, size: 24),
                                      onPressed: () { /* 검색 동작 */ },
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

                // ⭐ 닫기 버튼
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
      ),
    );
  }

  void showRegionPopup(RegionInfo region) {
    final pageContext = context;

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
                  // 닫기 버튼
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
                  const SizedBox(height: 4),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.location_city_rounded, color: primary, size: 28),
                  ),
                  const SizedBox(height: 16),

                  // 💡 지역 데이터 FutureBuilder (Subtext + 지역명 + 본문)
                  FutureBuilder<Map<String, String>>(
                    future: fetchRegionData(region.name),
                    builder: (context, snapshot) {
                      final data = snapshot.data ?? {'subtext': '', 'text': '${region.name}의 여행지로 함께 이동할\n사람들을 찾아보세요'};

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. subtext (지역명 위)
                          if (data['subtext']!.isNotEmpty) ...[
                            Text(
                              data['subtext']!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],

                          // 2. 지역명 + 혼잡도
                          Row(
                            children: [
                              Text(
                                region.name,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black87),
                              ),
                              const SizedBox(width: 10),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // 3. 본문 텍스트
                          Text(
                            data['text']!,
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w500, height: 1.4),
                          ),
                        ],
                      );
                    },
                  ),

                  // 사진 영역
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 80,
                    child: FutureBuilder<List<dynamic>>(
                      future: fetchGalleryByRegion(region.name),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
                        final photos = snapshot.data!;
                        if (photos.isEmpty) return const Center(child: Text("사진 정보가 없습니다."));

                        return ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: photos.length + 1, // 사진 개수 + "더 둘러보기" 버튼
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            // 마지막 인덱스(photos.length)에 "더 둘러보기" 버튼 배치
                            if (index == photos.length) {
                              return InkWell(
                                onTap: () {
                                  Navigator.pop(dialogContext);
                                  Navigator.push(pageContext, MaterialPageRoute(builder: (context) => PhotoPage(regionName: region.name)));
                                },
                                child: Container(
                                  width: 80, height: 80,
                                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                                  alignment: Alignment.center,
                                  child: Text("${region.name} 사진\n더 둘러보기", textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                                ),
                              );
                            }

                            // 썸네일 이미지 생성 부분
                            final photo = photos[index];
                            final String originalUrl = photo['galWebImageUrl'] ?? '';
                            final String proxyUrl = '${dotenv.env['PHP_URL']}api_photo.php?proxy_url=${Uri.encodeComponent(originalUrl)}';

                            return InkWell(
                              onTap: () => _showFullImage(photo),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                    proxyUrl,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image)
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        Navigator.push(pageContext, MaterialPageRoute(builder: (context) => InformationPage(regionName: region.name)));
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: primary, padding: const EdgeInsets.symmetric(vertical: 14), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      child: Text('${region.name} 둘러보기', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 입장 버튼
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        Navigator.push(
                          pageContext,
                          MaterialPageRoute(
                            settings: const RouteSettings(name: 'room'), // ⭐ 이름표 추가
                            builder: (context) => RoomPage(userId: widget.userId, roomTable: region.id, roomTitle: region.name),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: primary, padding: const EdgeInsets.symmetric(vertical: 14), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      child: const Text('채팅방 입장', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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

  void _openAdvisor() {

    showDialog(
      context: context,
      builder: (_) => _AdvisorDialogContent(
        pageContext: context,
        userId: widget.userId,
        regions: regions,
        primary: primary,
      ),
    );

  }

  void _openTop10() {
    showDialog(
      context: context,
      builder: (_) => _Top10DialogContent(
        pageContext: context,
        primary: primary,
      ),
    );
  }

  void _openFestivalCalendar() {
    showDialog(
      context: context,
      builder: (_) => FestivalCalendarDialog(
        pageContext: context,
        primary: primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0xFFF7F7F9),

      body: SafeArea(

        child: SingleChildScrollView(

          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              // ===== 상단 인사말 =====
              Row(
                children: [

                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.map_rounded, color: primary, size: 22),
                  ),

                  const SizedBox(width: 12),

                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '같이가유',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.black45,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '같이 떠나볼까요?',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),

                ],
              ),

              const SizedBox(height: 20),

              // ===== 지도 카드 =====
              Container(

                width: double.infinity,

                padding: const EdgeInsets.all(12),

                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),

                child: ClipRRect(

                  borderRadius: BorderRadius.circular(18),

                  child: AspectRatio(

                    aspectRatio: 1,

                    child: Stack(

                      children: [

                        Positioned.fill(
                          child: Container(color: const Color(0xFFFFFFFF)),
                        ),

                        Positioned.fill(
                          child: Center(
                            child: Image.asset(
                              'assets/images/namdo.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),

                        LayoutBuilder(
                          builder: (context, constraints) {

                            return Stack(

                              children: regions.map((region) {

                                return Positioned(
                                  left: constraints.maxWidth * region.leftRatio - 14,
                                  top: constraints.maxHeight * region.topRatio - 14,
                                  child: _MapPin(
                                    label: region.name,
                                    color: primary,
                                    onTap: () => showRegionPopup(region),
                                  ),
                                );

                              }).toList(),

                            );

                          },
                        ),

                      ],

                    ),

                  ),

                ),

              ),

              const SizedBox(height: 8),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Icon(Icons.touch_app_rounded, size: 14, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text(
                      '출처: ⓒ한국관광콘텐츠랩',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

// ===== AI 여행 동행 어드바이저 =====
              // ===== 상단 아이콘 + 타이틀 (박스 밖) =====
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: const Icon(Icons.travel_explore_rounded, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "오늘은 어디로 떠나볼까요?",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ===== 말풍선 1: AI 관광 지역 추천 =====
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "실시간 관광 빅데이터로 지금 동행 구하기 좋은 지역을 골라드려요",
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _openAdvisor,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
                        label: const Text(
                          "AI 관광 지역 추천",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ===== 말풍선 2: 인기 관광지 TOP 10 =====
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "지금 가장 많은 사람이 찾는 곳을 확인해보세요",
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _openTop10,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 16),
                        label: const Text(
                          "인기 관광지 TOP 10",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ===== 말풍선 3: 축제 일정 달력 =====
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "충청남도 전체 축제를 달력으로 확인하세요",
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _openFestivalCalendar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 16),
                        label: const Text(
                          "축제 일정 달력",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomWidget(
        userId: widget.userId,
      ),
    );
  }
}

class _MapPin extends StatelessWidget {

  final String label;

  final Color color;

  final VoidCallback onTap;

  const _MapPin({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {

    return GestureDetector(

      onTap: onTap,

      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: Colors.white,
              size: 13,
            ),
          ),

          const SizedBox(height: 2),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.75),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

        ],
      ),

    );

  }

}

class _InfoTag extends StatelessWidget {

  final IconData icon;

  final String label;

  const _InfoTag({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
        ],
      ),
    );

  }

}

class _ScoreBar extends StatelessWidget {

  final String label;

  final double value;

  final Color color;

  const _ScoreBar({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        Text(label, style: TextStyle(fontSize: 9, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),

        const SizedBox(height: 4),

        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: (value / 100).clamp(0, 1),
            minHeight: 6,
            backgroundColor: Colors.grey.shade100,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),

      ],
    );

  }

}
enum _AdvisorStep { checking, survey, loading, result, error }

class _AdvisorDialogContent extends StatefulWidget {

  final BuildContext pageContext;
  final int userId;
  final List<RegionInfo> regions;
  final Color primary;

  const _AdvisorDialogContent({
    required this.pageContext,
    required this.userId,
    required this.regions,
    required this.primary,
  });

  @override
  State<_AdvisorDialogContent> createState() => _AdvisorDialogContentState();

}

class _AdvisorDialogContentState extends State<_AdvisorDialogContent> {

  _AdvisorStep step = _AdvisorStep.checking; // ⭐ 잠금 확인이 끝날 때까지 로딩

  String selectedAge = '3101';
  String selectedTheme = 'sports';
  String selectedBudget = 'saving';

  Map<String, dynamic>? resultData;
  String errorMessage = '';

  Timer? _loadingMessageTimer;
  int _loadingMessageIndex = 0;

  Duration? _lockRemaining;
  Timer? _lockTimer;

  static const String _prefsKey = 'ai_recommend_last_time';

  final List<String> _loadingMessages = [
    "15개 지역의 최신 관광 데이터를 모으는 중...",
    "회원님의 나이대와 잘 맞는 지역을 찾는 중...",
    "여행 취향에 맞는 지역을 분석하는 중...",
    "예산 스타일에 맞춰 우선순위를 조정하는 중...",
    "AI가 추천 코멘트를 작성하는 중...",
  ];

  static const List<Map<String, String>> ageOptions = [
    {'code': '3101', 'label': '10대'},
    {'code': '3102', 'label': '20대'},
    {'code': '3103', 'label': '30대'},
    {'code': '3104', 'label': '40대'},
    {'code': '3105', 'label': '50대'},
    {'code': '3106', 'label': '60대'},
    {'code': '3107', 'label': '70대'},
  ];

  static const List<Map<String, String>> themeOptions = [
    {'key': 'sports', 'label': '레포츠·스포츠', 'icon': '🏃'},
    {'key': 'healing', 'label': '휴식·힐링', 'icon': '🌿'},
    {'key': 'food', 'label': '미식', 'icon': '🍽️'},
    {'key': 'experience', 'label': '체험', 'icon': '🎨'},
    {'key': 'culture', 'label': '문화·역사', 'icon': '🏛️'},
    {'key': 'nature', 'label': '자연', 'icon': '🏞️'},
  ];

  static const List<Map<String, String>> budgetOptions = [
    {'key': 'saving', 'label': '알뜰하게'},
    {'key': 'balance', 'label': '균형있게'},
    {'key': 'premium', 'label': '여유롭게'},
  ];

  @override
  void initState() {
    super.initState();
    _checkLockStatus(); // ⭐ 이 안에서 완료되면 step을 survey로 넘김
  }

  @override
  void dispose() {
    _loadingMessageTimer?.cancel();
    _lockTimer?.cancel();
    super.dispose();
  }

  // ⭐ 다이얼로그가 뜨자마자, 최종 확정되기 전까진 checking 화면을 보여줘서 경합(race)을 원천 차단
  Future<void> _checkLockStatus() async {

    final prefs = await SharedPreferences.getInstance();

    final lastMillis = prefs.getInt(_prefsKey);

    if (!mounted) return;

    if (lastMillis != null) {

      final last = DateTime.fromMillisecondsSinceEpoch(lastMillis);
      final elapsed = DateTime.now().difference(last);
      const limit = Duration(hours: 24);

      if (elapsed < limit) {

        setState(() {
          _lockRemaining = limit - elapsed;
          step = _AdvisorStep.survey;
        });

        _startLockTimer();

        return;

      }

    }

    setState(() {
      _lockRemaining = null;
      step = _AdvisorStep.survey;
    });

  }

  void _startLockTimer() {

    _lockTimer?.cancel();

    _lockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {

      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {

        if (_lockRemaining == null || _lockRemaining!.inSeconds <= 1) {
          _lockRemaining = null;
          timer.cancel();
        } else {
          _lockRemaining = _lockRemaining! - const Duration(seconds: 1);
        }

      });

    });

  }

  // ⭐ 성공적으로 새로 생성했을 때 저장
  Future<void> _saveLockTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKey, DateTime.now().millisecondsSinceEpoch);
  }

  // ⭐ 서버가 "이미 오늘 썼다"(rate_limited)고 응답할 때도, 남은 시간을 역산해서 로컬에 동기화 저장
  // -> 다음에 다이얼로그를 다시 열어도 로컬 기준으로 정확히 잠금 상태가 반영됨 (기존 버그의 핵심 원인)
  Future<void> _syncLockTimestampFromServer(int remainingSeconds) async {

    final elapsedSeconds = 86400 - remainingSeconds;

    final approxOriginalTime = DateTime.now().subtract(Duration(seconds: elapsedSeconds));

    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt(_prefsKey, approxOriginalTime.millisecondsSinceEpoch);

  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _runAgent() async {

    if (_lockRemaining != null) return; // ⭐ 이중 안전장치 (버튼이 null이어도 혹시 몰라 방어)

    setState(() => step = _AdvisorStep.loading);

    _loadingMessageIndex = 0;

    _loadingMessageTimer = Timer.periodic(const Duration(seconds: 2), (timer) {

      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _loadingMessageIndex = (_loadingMessageIndex + 1) % _loadingMessages.length;
      });

    });

    try {

      final url = '${dotenv.env['PHP_URL']}AI.php';

      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "age": selectedAge,
          "theme": selectedTheme,
          "budget": selectedBudget,
        }),
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      _loadingMessageTimer?.cancel();

      if (data["rate_limited"] == true) {

        final int remaining = data["remaining_seconds"] ?? 0;

        await _syncLockTimestampFromServer(remaining); // ⭐ 핵심 수정: 로컬 저장 동기화

        if (!mounted) return;

        setState(() {
          _lockRemaining = Duration(seconds: remaining);
        });

        _startLockTimer();

        if (data["success"] == true) {

          setState(() {
            resultData = data;
            step = _AdvisorStep.result;
          });

        } else {

          setState(() => step = _AdvisorStep.survey);

        }

        return;

      }

      if (data["success"] != true) {

        setState(() {
          step = _AdvisorStep.error;
          errorMessage = data["message"] ?? "추천을 불러오지 못했습니다";
        });

        return;

      }

      await _saveLockTimestamp();

      if (!mounted) return;

      setState(() {
        resultData = data;
        step = _AdvisorStep.result;
        _lockRemaining = const Duration(hours: 24);
      });

      _startLockTimer();

    } catch (e) {

      if (!mounted) return;

      _loadingMessageTimer?.cancel();

      setState(() {
        step = _AdvisorStep.error;
        errorMessage = "에러 발생: $e";
      });

    }

  }

  @override
  Widget build(BuildContext context) {

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          child: _buildStepContent(),
        ),
      ),
    );

  }

  Widget _buildStepContent() {

    switch (step) {
      case _AdvisorStep.checking:
        return const SizedBox(
          key: ValueKey('checking'),
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        );
      case _AdvisorStep.survey:
        return _buildSurvey();
      case _AdvisorStep.loading:
        return _buildLoading();
      case _AdvisorStep.result:
        return _buildResult();
      case _AdvisorStep.error:
        return _buildError();
    }

  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    String? icon,
  }) {

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? widget.primary : const Color(0xFFF7F7F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? widget.primary : Colors.transparent, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Text(icon, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );

  }

  Widget _buildSurvey() {

    final bool locked = _lockRemaining != null;

    return Column(
      key: const ValueKey('survey'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.close_rounded, color: Colors.grey.shade400),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),

        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: widget.primary.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(Icons.auto_awesome_rounded, color: widget.primary, size: 26),
        ),

        const SizedBox(height: 14),

        const Text("여행 취향을 알려주세요", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black87)),

        const SizedBox(height: 4),

        Text(
          "간단한 정보로 더 정확한 지역을 추천해드려요",
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
        ),

        const SizedBox(height: 20),

        Text("나이대", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: ageOptions.map((o) => _chip(
            label: o['label']!,
            selected: selectedAge == o['code'],
            onTap: locked ? () {} : () => setState(() => selectedAge = o['code']!),
          )).toList(),
        ),

        const SizedBox(height: 18),

        Text("여행 테마", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: themeOptions.map((o) => _chip(
            label: o['label']!,
            icon: o['icon'],
            selected: selectedTheme == o['key'],
            onTap: locked ? () {} : () => setState(() => selectedTheme = o['key']!),
          )).toList(),
        ),

        const SizedBox(height: 18),

        Text("예산 스타일", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: budgetOptions.map((o) => _chip(
            label: o['label']!,
            selected: selectedBudget == o['key'],
            onTap: locked ? () {} : () => setState(() => selectedBudget = o['key']!),
          )).toList(),
        ),

        const SizedBox(height: 24),

        // ⭐ 잠금 상태면 onPressed 자체를 null로 만들어서 완전히 눌리지 않게 처리
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: locked ? null : _runAgent,
            style: ElevatedButton.styleFrom(
              backgroundColor: locked ? Colors.grey.shade300 : widget.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: Icon(
              locked ? Icons.lock_clock_rounded : Icons.auto_awesome_rounded,
              color: locked ? Colors.grey.shade500 : Colors.white,
              size: 16,
            ),
            label: Text(
              locked ? "${_formatDuration(_lockRemaining!)} 후 재사용 가능" : "AI 추천 받기",
              style: TextStyle(color: locked ? Colors.grey.shade500 : Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ),

        if (locked) ...[

          const SizedBox(height: 8),

          Center(
            child: Text(
              "하루에 한 번만 추천받을 수 있어요",
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.w500),
            ),
          ),

        ],

      ],
    );

  }

  Widget _buildLoading() {

    return Column(
      key: const ValueKey('loading'),
      mainAxisSize: MainAxisSize.min,
      children: [

        const SizedBox(height: 12),

        SizedBox(
          width: 64, height: 64,
          child: CircularProgressIndicator(color: widget.primary, strokeWidth: 3),
        ),

        const SizedBox(height: 20),

        const Text("AI가 분석하고 있어요", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87)),

        const SizedBox(height: 10),

        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            _loadingMessages[_loadingMessageIndex],
            key: ValueKey<int>(_loadingMessageIndex),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
          ),
        ),

        const SizedBox(height: 12),

      ],
    );

  }

  Widget _buildResult() {

    final data = resultData!;

    final RegionInfo? matched = widget.regions.where((r) => r.id == data["recommended_id"]).isNotEmpty
        ? widget.regions.firstWhere((r) => r.id == data["recommended_id"])
        : null;

    if (matched == null) {
      return _buildErrorContent("추천 지역 정보를 찾을 수 없습니다");
    }

    final String? topSpot = data["top_spot"];
    final String? themeLabel = data["theme_label"];
    final String? themeIcon = data["theme_icon"];
    final String? ageLabel = data["age_label"];
    final String? bestWeekday = data["best_weekday"];
    final Map<String, dynamic>? breakdown = data["score_breakdown"];
    final String comment = data["comment"] ?? "";

    return SingleChildScrollView(
      key: const ValueKey('result'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close_rounded, color: Colors.grey.shade400),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: widget.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded, size: 12, color: widget.primary),
                const SizedBox(width: 4),
                Text("${ageLabel ?? ''} 맞춤 추천", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: widget.primary)),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Text(matched.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.black87)),
              if (themeIcon != null) ...[
                const SizedBox(width: 8),
                Text(themeIcon, style: const TextStyle(fontSize: 20)),
              ],
            ],
          ),

          const SizedBox(height: 6),

          Wrap(
            spacing: 6, runSpacing: 6,
            children: [
              if (themeLabel != null) _InfoTag(icon: Icons.style_rounded, label: "$themeLabel 여행 강세"),
              if (topSpot != null && topSpot.isNotEmpty) _InfoTag(icon: Icons.place_rounded, label: topSpot),
              if (bestWeekday != null) _InfoTag(icon: Icons.event_rounded, label: "$bestWeekday요일 추천"),
            ],
          ),

          const SizedBox(height: 10),

          if (_lockRemaining != null)

            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_clock_rounded, size: 12, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      "다음 추천까지 ${_formatDuration(_lockRemaining!)}",
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFF7F7F9), borderRadius: BorderRadius.circular(14)),
            child: Text(comment, style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.5, fontWeight: FontWeight.w500)),
          ),

          if (breakdown != null) ...[

            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(child: _ScoreBar(label: "취향 적합도", value: (breakdown["theme_match"] ?? 0).toDouble(), color: widget.primary)),
                const SizedBox(width: 6),
                Expanded(child: _ScoreBar(label: "연령대 적합도", value: (breakdown["age_match"] ?? 0).toDouble(), color: Colors.blueAccent)),
                const SizedBox(width: 6),
                Expanded(child: _ScoreBar(label: "예산 적합도", value: (breakdown["budget_fit"] ?? 0).toDouble(), color: Colors.teal)),
              ],
            ),

          ],

          const SizedBox(height: 22),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(widget.pageContext, MaterialPageRoute(builder: (context) => InformationPage(regionName: matched.name)));
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: widget.primary.withOpacity(0.4)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('${matched.name} 둘러보기', style: TextStyle(color: widget.primary, fontWeight: FontWeight.w700)),
            ),
          ),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  widget.pageContext,
                  MaterialPageRoute(
                    settings: const RouteSettings(name: 'room'),
                    builder: (context) => RoomPage(userId: widget.userId, roomTable: matched.id, roomTitle: matched.name),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('채팅방 입장', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),

        ],
      ),
    );

  }

  Widget _buildError() => _buildErrorContent(errorMessage);

  Widget _buildErrorContent(String message) {

    return Column(
      key: const ValueKey('error'),
      mainAxisSize: MainAxisSize.min,
      children: [

        Icon(Icons.error_outline_rounded, size: 48, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text("닫기", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => setState(() => step = _AdvisorStep.survey),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text("다시 시도", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),

      ],
    );

  }

}
class _Top10DialogContent extends StatefulWidget {

  final BuildContext pageContext;

  final Color primary;

  const _Top10DialogContent({
    required this.pageContext,
    required this.primary,
  });

  @override
  State<_Top10DialogContent> createState() => _Top10DialogContentState();

}

class _Top10DialogContentState extends State<_Top10DialogContent> {

  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchTop10();
  }

  Future<List<Map<String, dynamic>>> _fetchTop10() async {

    final url = '${dotenv.env['PHP_URL']}top10.php';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception('데이터 로드 실패');
    }

    final data = jsonDecode(response.body);

    if (data['success'] != true) {
      throw Exception(data['message'] ?? '데이터 로드 실패');
    }

    final List<dynamic> items = data['items'] ?? [];

    return items.map((e) => Map<String, dynamic>.from(e)).toList();

  }

  // ⭐ 순위별 메달 색상
  Color _rankColor(int rank) {

    if (rank == 1) return const Color(0xFFFFC107); // 골드
    if (rank == 2) return const Color(0xFFB0BEC5); // 실버
    if (rank == 3) return const Color(0xFFCD7F32); // 브론즈

    return Colors.grey.shade400;

  }

  void _goToInformation(BuildContext dialogContext, String regionName) {

    // ⭐ 팝업(다이얼로그)을 먼저 닫고, 그 다음 information.dart로 이동
    // -> 뒤로가기를 눌러 mainview.dart로 복귀했을 때 팝업이 다시 뜨지 않도록 함
    Navigator.pop(dialogContext);

    Navigator.push(
      widget.pageContext,
      MaterialPageRoute(builder: (context) => InformationPage(regionName: regionName)),
    );

  }

  @override
  Widget build(BuildContext context) {

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.82),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F9),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            // ===== 헤더 (그라데이션) =====
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [widget.primary, widget.primary.withOpacity(0.75)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [

                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                    child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 24),
                  ),

                  const SizedBox(width: 12),

                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("인기 관광지 TOP 10", style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                        SizedBox(height: 2),
                        Text("지금 가장 많이 찾는 관광지예요", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),

                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),

                ],
              ),
            ),

            // ===== 목록 =====
            Flexible(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _future,
                builder: (context, snapshot) {

                  if (snapshot.connectionState == ConnectionState.waiting) {

                    return Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator(color: widget.primary)),
                    );

                  }

                  if (snapshot.hasError) {

                    return Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline_rounded, size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text("정보를 불러올 수 없습니다", style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    );

                  }

                  final items = snapshot.data ?? [];

                  if (items.isEmpty) {

                    return Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(
                        child: Text("표시할 데이터가 없습니다", style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500)),
                      ),
                    );

                  }

                  return ListView.separated(

                    shrinkWrap: true,

                    padding: const EdgeInsets.all(16),

                    itemCount: items.length,

                    separatorBuilder: (_, __) => const SizedBox(height: 10),

                    itemBuilder: (context, index) {

                      final item = items[index];

                      final int rank = item['rank'] ?? (index + 1);
                      final String regionName = (item['regionname'] ?? '').toString();
                      final String spot = (item['spot'] ?? '').toString();
                      final int people = item['people'] ?? 0;
                      final String image = (item['image'] ?? '').toString();

                      return InkWell(

                        borderRadius: BorderRadius.circular(18),

                        onTap: () => _goToInformation(context, regionName),

                        child: Container(

                          padding: const EdgeInsets.all(12),

                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
                            ],
                          ),

                          child: Row(
                            children: [

                              // ===== 이미지 + 순위 뱃지 =====
                              Stack(
                                clipBehavior: Clip.none,
                                children: [

                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Image.network(
                                      image,
                                      width: 76,
                                      height: 76,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 76,
                                        height: 76,
                                        color: Colors.grey.shade100,
                                        child: Icon(Icons.image_not_supported_rounded, color: Colors.grey.shade300, size: 24),
                                      ),
                                    ),
                                  ),

                                  Positioned(
                                    top: -6,
                                    left: -6,
                                    child: Container(
                                      width: 26,
                                      height: 26,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: _rankColor(rank),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                        boxShadow: [
                                          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4, offset: const Offset(0, 2)),
                                        ],
                                      ),
                                      child: Text(
                                        "$rank",
                                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                  ),

                                ],
                              ),

                              const SizedBox(width: 14),

                              // ===== 정보 =====
                              Expanded(

                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [

                                    Row(
                                      children: [

                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: widget.primary.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            regionName,
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: widget.primary),
                                          ),
                                        ),

                                      ],
                                    ),

                                    const SizedBox(height: 6),

                                    Text(
                                      spot,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black87),
                                    ),

                                    const SizedBox(height: 4),

                                    Row(
                                      children: [
                                        Icon(Icons.groups_rounded, size: 13, color: Colors.grey.shade400),
                                        const SizedBox(width: 4),
                                        Text(
                                          "방문객 : ${people}천명",
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),

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
              ),
            ),

          ],
        ),
      ),
    );

  }

}