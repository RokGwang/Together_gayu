import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:together_gayu/photo.dart';
import 'room.dart';
import 'tab_widget/widget.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'information.dart'; // 이 줄이 없으면 추가하세요.
import 'dart:ui';

// ===== 지역 정보 모델 =====
class RegionInfo {

  final String id;        // room.php 등에 넘길 roomTable 값 (영문)

  final String name;      // 화면에 표시할 지역명 (한글)

  final double leftRatio;  // 지도 위 가로 위치 비율 (0~1)

  final double topRatio;   // 지도 위 세로 위치 비율 (0~1)

  final String areaCd;   // 추가
  final String signguCd; // 추가

  const RegionInfo({
    required this.id,
    required this.name,
    required this.leftRatio,
    required this.topRatio,
    required this.areaCd,
    required this.signguCd,
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
      final url = '${dotenv.env['PHP_URL']}api_photo2.php?keyword=${Uri.encodeComponent(regionName)}&numOfRows=5';
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
      // photo2.php를 호출하고 keyword에 지역명을 넣습니다.
      final url = '${dotenv.env['PHP_URL']}api_photo2.php?keyword=${Uri.encodeComponent(regionName)}&numOfRows=10';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // API 응답 구조에 맞게 파싱
        final responseData = data['response'];
        if (responseData == null) return [];

        final body = responseData['body'];
        if (body == null) return [];

        final itemsContainer = body['items'];
        if (itemsContainer == null || itemsContainer is String) return [];

        final items = itemsContainer['item'];
        if (items == null) return [];

        return (items is List) ? items : [items];
      }
    } catch (e) {
      debugPrint('통신 오류: $e');
    }
    return [];
  }
  Future<String> fetchCrowdLevel(String areaCd, String signguCd) async {
    try {
      final url = '${dotenv.env['PHP_URL']}api_people.php?areaCd=$areaCd&signguCd=$signguCd&numOfRows=1';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // 데이터가 없는 경우 방어 코드
        if (data['response'] == null || data['response']['body'] == null || data['response']['body']['items'] == null) {
          return "정보 없음";
        }

        final itemsContainer = data['response']['body']['items'];
        if (itemsContainer == "" || itemsContainer is String) return "정보 없음";

        final items = itemsContainer['item'];
        // 리스트가 배열(List) 형태일 때만 첫 번째 항목 가져오기
        final item = (items is List) ? items[0] : items;

        // 💡 여기서 키 값을 'cnctrRate'로 수정했습니다.
        final rate = item['cnctrRate'] ?? "정보 없음";
        return "$rate%"; // 뒤에 % 기호 붙이기
      }
    } catch (e) {
      debugPrint('집중률 통신 오류: $e');
    }
    return "정보 없음";
  }

  static const Color primary = Color(0xFFFF7A00);

  // ===== 지역 목록 (일단 균등 배치, 위치는 나중에 조정) =====
  static const List<RegionInfo> regions = [

    RegionInfo(id: "cheonan",    name: "천안", leftRatio: 0.76, topRatio: 0.22, areaCd: "44", signguCd: "44133"),
    RegionInfo(id: "asan",       name: "아산", leftRatio: 0.60, topRatio: 0.24, areaCd: "44", signguCd: "44200"),
    RegionInfo(id: "dangjin",    name: "당진", leftRatio: 0.40, topRatio: 0.20, areaCd: "44", signguCd: "44270"),
    RegionInfo(id: "seosan",     name: "서산", leftRatio: 0.28, topRatio: 0.26, areaCd: "44", signguCd: "44210"),
    RegionInfo(id: "taean",      name: "태안", leftRatio: 0.16, topRatio: 0.30, areaCd: "44", signguCd: "44825"),
    RegionInfo(id: "yesan",      name: "예산", leftRatio: 0.50, topRatio: 0.34, areaCd: "44", signguCd: "44810"),
    RegionInfo(id: "hongseong",  name: "홍성", leftRatio: 0.38, topRatio: 0.44, areaCd: "44", signguCd: "44800"),
    RegionInfo(id: "cheongyang", name: "청양", leftRatio: 0.50, topRatio: 0.52, areaCd: "44", signguCd: "44790"),
    RegionInfo(id: "gongju",     name: "공주", leftRatio: 0.66, topRatio: 0.48, areaCd: "44", signguCd: "44150"),
    RegionInfo(id: "boryeong",   name: "보령", leftRatio: 0.36, topRatio: 0.60, areaCd: "44", signguCd: "44180"),
    RegionInfo(id: "buyeo",      name: "부여", leftRatio: 0.54, topRatio: 0.68, areaCd: "44", signguCd: "44760"),
    RegionInfo(id: "seocheon",   name: "서천", leftRatio: 0.44, topRatio: 0.80, areaCd: "44", signguCd: "44770"),
    RegionInfo(id: "nonsan",     name: "논산", leftRatio: 0.70, topRatio: 0.72, areaCd: "44", signguCd: "44230"),
    RegionInfo(id: "gyeryong",   name: "계룡", leftRatio: 0.78, topRatio: 0.66, areaCd: "44", signguCd: "44250"),
    RegionInfo(id: "geumsan",    name: "금산", leftRatio: 0.92, topRatio: 0.80, areaCd: "44", signguCd: "44710"),

  ];

  Future<Map<String, String>> fetchRegionData(String regionName) async {
    try {
      // popup2.php 호출
      final url = '${dotenv.env['PHP_URL']}popup2.php?name=${Uri.encodeComponent(regionName)}';
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
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
                              FutureBuilder<String>(
                                future: fetchCrowdLevel(region.areaCd, region.signguCd),
                                builder: (context, crowdSnapshot) {
                                  final crowd = crowdSnapshot.data ?? "정보 없음";
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                    child: Text("혼잡도 예상: $crowd", style: const TextStyle(fontSize: 12, color: primary, fontWeight: FontWeight.bold)),
                                  );
                                },
                              ),
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
                          itemCount: photos.length > 3 ? 4 : photos.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            if (index == 3) {
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
                            final photo = photos[index]; // 1. 현재 인덱스의 데이터 가져오기
                            final String originalUrl = photo['galWebImageUrl'] ?? '';
                            final String proxyUrl = '${dotenv.env['PHP_URL']}api_photo2.php?proxy_url=${Uri.encodeComponent(originalUrl)}';

                            return InkWell(
                              onTap: () => _showFullImage(photo), // 2. URL 대신 전체 데이터(photo) 전달
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
                      child: const Text('관광지 소개', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 입장 버튼
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        Navigator.push(pageContext, MaterialPageRoute(builder: (context) => RoomPage(userId: widget.userId, roomTable: region.id, roomTitle: region.name)));
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
                          '어디로 떠나볼까요?',
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
                      '지도 위 지역을 눌러 채팅방을 찾아보세요',
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

              const Text(
                '지역 바로가기',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 12),

              // ===== 지역 바로가기 카드 (그리드) =====
              GridView.builder(

                shrinkWrap: true,

                physics: const NeverScrollableScrollPhysics(),

                itemCount: regions.length,

                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.05,
                ),

                itemBuilder: (context, index) {

                  final region = regions[index];

                  return _RegionCard(
                    title: region.name,
                    icon: Icons.directions_car_rounded,
                    color: primary,
                    onTap: () => showRegionPopup(region),
                  );

                },

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

class _RegionCard extends StatelessWidget {

  final String title;

  final IconData icon;

  final Color color;

  final VoidCallback onTap;

  const _RegionCard({

    required this.title,

    required this.icon,

    required this.color,

    required this.onTap,

  });

  @override
  Widget build(BuildContext context) {

    return InkWell(

      borderRadius: BorderRadius.circular(16),

      onTap: onTap,

      child: Container(

        padding: const EdgeInsets.all(12),

        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 17),
            ),

            const SizedBox(height: 8),

            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),

          ],
        ),

      ),

    );

  }

}