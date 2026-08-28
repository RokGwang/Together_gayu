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
    final url = '${dotenv.env['PHP_URL']}information.php?regionname=${Uri.encodeComponent(widget.regionName)}';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('데이터 로드 실패');
    }
    final data = jsonDecode(response.body);
    if (data['success'] != true) {
      throw Exception(data['error'] ?? '데이터 로드 실패');
    }
    return data;
  }

  // ⭐ 오늘 기준 지난 달을 YYYYMM으로 반환
  String _lastMonthYm() {
    final now = DateTime.now();
    final lastMonthDate = DateTime(now.year, now.month - 1, 1);
    final y = lastMonthDate.year.toString();
    final m = lastMonthDate.month.toString().padLeft(2, '0');
    return "$y$m";
  }

  // ⭐ 연령대별 방문객 비율 조회 -> touDivIxVal 내림차순 상위 3개
  Future<List<Map<String, dynamic>>> _fetchAgeStats(String signguCd) async {

    final baseYm = _lastMonthYm();

    final url = '${dotenv.env['PHP_URL']}api_age.php'
        '?areaCd=44'
        '&signguCd=${Uri.encodeComponent(signguCd)}'
        '&baseYm=$baseYm';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception('통계 로드 실패');
    }

    final data = jsonDecode(response.body);

    if (data['success'] != true) {
      throw Exception(data['message'] ?? '통계 로드 실패');
    }

    final List<dynamic> ageGroups = data['data'] ?? [];

    final List<Map<String, dynamic>> parsed = [];

    for (final group in ageGroups) {

      final String ageName = (group['age_name'] ?? '').toString();

      final List<dynamic> items = group['items'] ?? [];

      if (items.isEmpty) continue;

      final double val = double.tryParse((items[0]['touDivIxVal'] ?? '0').toString()) ?? 0;

      parsed.add({
        "age_name": ageName,
        "value": val,
      });

    }

    parsed.sort((a, b) => (b['value'] as double).compareTo(a['value'] as double));

    return parsed.take(3).toList();

  }

  Widget _remoteImage(String? url, {double? height, BorderRadius? radius}) {
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: radius ?? BorderRadius.circular(16),
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
        errorWidget: (context, u, error) => Container(
          height: height,
          color: Colors.grey.shade100,
          child: Icon(Icons.broken_image_rounded, color: Colors.grey.shade300, size: 28),
        ),
      ),
    );
  }

  // ⭐ "regionName 방문객 비율" 섹션 위젯
  Widget _buildVisitorStatsSection(String? signguCd) {

    if (signguCd == null || signguCd.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(

      padding: const EdgeInsets.only(top: 28),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Row(
            children: [
              Icon(Icons.groups_rounded, size: 18, color: Colors.black87),
              const SizedBox(width: 6),
              Text(
                "${widget.regionName} 방문객 비율",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87),
              ),
            ],
          ),

          const SizedBox(height: 14),

          FutureBuilder<List<Map<String, dynamic>>>(

            future: _fetchAgeStats(signguCd),

            builder: (context, snapshot) {

              if (snapshot.connectionState == ConnectionState.waiting) {

                return Container(
                  height: 140,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: CircularProgressIndicator(strokeWidth: 2, color: primary),
                );

              }

              if (snapshot.hasError || (snapshot.data ?? []).isEmpty) {

                return Container(
                  padding: const EdgeInsets.all(20),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      "통계 정보를 불러올 수 없습니다",
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                );

              }

              final top3 = snapshot.data!;

              final Map<String, dynamic>? first = top3.isNotEmpty ? top3[0] : null;
              final Map<String, dynamic>? second = top3.length > 1 ? top3[1] : null;
              final Map<String, dynamic>? third = top3.length > 2 ? top3[2] : null;

              return Container(

                width: double.infinity,

                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),

                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),

                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [

                    // 왼쪽: 2위
                    if (second != null)
                      _RankPodium(
                        rank: 2,
                        ageName: second['age_name'],
                        value: second['value'],
                        height: 74,
                        color: Colors.grey.shade400,
                      )
                    else
                      const SizedBox(width: 70),

                    // 가운데: 1위
                    if (first != null)
                      _RankPodium(
                        rank: 1,
                        ageName: first['age_name'],
                        value: first['value'],
                        height: 96,
                        color: primary,
                      )
                    else
                      const SizedBox(width: 70),

                    // 오른쪽: 3위
                    if (third != null)
                      _RankPodium(
                        rank: 3,
                        ageName: third['age_name'],
                        value: third['value'],
                        height: 58,
                        color: const Color(0xFFCD7F32),
                      )
                    else
                      const SizedBox(width: 70),

                  ],
                ),

              );

            },

          ),

        ],
      ),

    );

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _infoFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Stack(
              children: [
                Container(color: const Color(0xFFF7F7F9)),
                AppBar(
                  title: Text(widget.regionName, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87, fontSize: 18)),
                  backgroundColor: const Color(0xFFF7F7F9),
                  elevation: 0,
                  iconTheme: const IconThemeData(color: Colors.black87),
                ),
                Center(child: CircularProgressIndicator(color: primary)),
              ],
            );
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Stack(
              children: [
                AppBar(
                  title: Text(widget.regionName, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87, fontSize: 18)),
                  backgroundColor: const Color(0xFFF7F7F9),
                  elevation: 0,
                  iconTheme: const IconThemeData(color: Colors.black87),
                ),
                Center(
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
                ),
              ],
            );
          }
          final data = snapshot.data!;
          final List<dynamic> images = data['images'] ?? [];
          final List<String> spotNames = List<String>.from(data['spot_names'] ?? []);
          final String? signguCd = (data['signguCd'] ?? '').toString().isNotEmpty ? data['signguCd'].toString() : null; // ⭐ 추가
          final String? heroAsset = images.isNotEmpty && (images[0] ?? '').toString().isNotEmpty
              ? images[0].toString()
              : null;
          final List<String> galleryUrls = [
            if (images.length > 1) images[1]?.toString() ?? '',
            if (images.length > 2) images[2]?.toString() ?? '',
            if (images.length > 3) images[3]?.toString() ?? '',
            if (images.length > 4) images[4]?.toString() ?? '',
          ].where((e) => e.isNotEmpty).toList();
          return Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    // ===== 히어로 영역 =====
                    SliverAppBar(
                      expandedHeight: 320,
                      pinned: true,
                      backgroundColor: const Color(0xFFF7F7F9),
                      elevation: 0,
                      iconTheme: const IconThemeData(color: Colors.white),
                      leading: Padding(
                        padding: const EdgeInsets.all(6),
                        child: CircleAvatar(
                          backgroundColor: Colors.black.withOpacity(0.3),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ),
                      flexibleSpace: FlexibleSpaceBar(
                        collapseMode: CollapseMode.parallax,
                        background: Stack(
                          fit: StackFit.expand,
                          children: [
                            heroAsset != null
                                ? Image.asset(
                              'assets/images/$heroAsset',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(color: primary.withOpacity(0.15)),
                            )
                                : Container(color: primary.withOpacity(0.15)),
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.transparent,
                                    Color(0xCC000000),
                                  ],
                                  stops: [0.0, 0.5, 1.0],
                                ),
                              ),
                            ),
                            Positioned(
                              left: 20,
                              right: 20,
                              bottom: 24,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: primary,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.location_on_rounded, color: Colors.white, size: 12),
                                        SizedBox(width: 4),
                                        Text(
                                          "충청남도",
                                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    widget.regionName,
                                    style: const TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  if ((data['subtext'] ?? '').toString().isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      data['subtext'],
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.white.withOpacity(0.9),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // ===== 본문 =====
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 지역 소개 텍스트 카드
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.auto_stories_rounded, size: 16, color: primary),
                                      const SizedBox(width: 6),
                                      Text(
                                        "지역 소개",
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: primary),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    data['text'] ?? '',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                      height: 1.7,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // ⭐ 방문객 비율 통계 섹션 (텍스트 카드와 사진 그리드 사이)
                            _buildVisitorStatsSection(signguCd),

                            if (galleryUrls.isNotEmpty || spotNames.isNotEmpty) ...[
                              const SizedBox(height: 28),
                              Row(
                                children: [
                                  Icon(Icons.landscape_rounded, size: 18, color: Colors.black87),
                                  const SizedBox(width: 6),
                                  const Text(
                                    "추천 관광지",
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: galleryUrls.length,
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 0.82,
                                ),
                                itemBuilder: (context, index) {
                                  final String url = galleryUrls[index];
                                  final String? name = index < spotNames.length ? spotNames[index] : null;
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(18),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        _remoteImage(url, height: double.infinity, radius: BorderRadius.zero),
                                        const DecoratedBox(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.transparent,
                                                Color(0x99000000),
                                              ],
                                              stops: [0.5, 1.0],
                                            ),
                                          ),
                                        ),
                                        if (name != null)
                                          Positioned(
                                            left: 12,
                                            right: 12,
                                            bottom: 12,
                                            child: Text(
                                              name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // ===== 하단 버튼 영역 (기존 그대로) =====
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

// ⭐ 순위별 막대(포디움) 위젯
class _RankPodium extends StatelessWidget {

  final int rank;
  final String ageName;
  final double value;
  final double height;
  final Color color;

  const _RankPodium({
    required this.rank,
    required this.ageName,
    required this.value,
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [

        Text(
          ageName,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black87),
        ),

        const SizedBox(height: 4),

        Text(
          "${value.toStringAsFixed(1)}%",
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
        ),

        const SizedBox(height: 8),

        Container(
          width: 56,
          height: height,
          decoration: BoxDecoration(
            color: color.withOpacity(rank == 1 ? 1 : 0.85),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            "$rank",
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white),
          ),
        ),

      ],
    );

  }

}