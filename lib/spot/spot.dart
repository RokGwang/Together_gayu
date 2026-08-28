import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'spot2.dart';

class SpotPage extends StatefulWidget {

  final String regionName;

  const SpotPage({super.key, required this.regionName});

  @override
  State<SpotPage> createState() => _SpotPageState();
}

enum _TopTab { crowd, hub }
enum _CrowdTab { crowded, normal, comfortable }
enum _HubTab { lodging, leisure, shopping, tour }

class _SpotPageState extends State<SpotPage> {

  static const Color primary = Color(0xFFFF7A00);

  late Future<_SpotResult> _spotFuture;

  Future<List<Map<String, dynamic>>>? _hubFuture;

  _TopTab selectedTopTab = _TopTab.crowd;

  _CrowdTab selectedCrowdTab = _CrowdTab.crowded;

  _HubTab selectedHubTab = _HubTab.lodging;

  @override
  void initState() {
    super.initState();
    _spotFuture = _fetchSpots();
  }

  String _lastMonthYm() {
    final now = DateTime.now();
    final lastMonthDate = DateTime(now.year, now.month - 1, 1);
    final y = lastMonthDate.year.toString();
    final m = lastMonthDate.month.toString().padLeft(2, '0');
    return "$y$m";
  }

  Future<_SpotResult> _fetchSpots() async {

    final url = '${dotenv.env['PHP_URL']}api_people.php?regionname=${Uri.encodeComponent(widget.regionName)}';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception('데이터 로드 실패');
    }

    final data = jsonDecode(response.body);

    if (data['error'] != null) {
      throw Exception(data['error']);
    }

    final String signguCd = _extractSignguCd(data);

    final itemsContainer = data['response']?['body']?['items'];

    if (itemsContainer == null || itemsContainer is String) {
      return _SpotResult(spots: [], signguCd: signguCd);
    }

    final items = itemsContainer['item'];

    if (items == null) {
      return _SpotResult(spots: [], signguCd: signguCd);
    }

    final List<dynamic> list = (items is List) ? items : [items];

    final spots = list.map((item) {

      return {
        "name": (item['tAtsNm'] ?? '').toString(),
        "rate": (item['cnctrRate'] ?? '').toString(),
        "signguCd": (item['signguCd'] ?? '').toString(), // ⭐ 항목별 signguCd 보존
      };

    }).toList();

    spots.sort((a, b) {

      final rateA = double.tryParse(a["rate"] ?? '') ?? 0;
      final rateB = double.tryParse(b["rate"] ?? '') ?? 0;

      return rateB.compareTo(rateA);

    });

    return _SpotResult(
      spots: List<Map<String, String>>.from(spots),
      signguCd: signguCd,
    );

  }

  String _extractSignguCd(Map<String, dynamic> data) {

    final itemsContainer = data['response']?['body']?['items'];

    if (itemsContainer == null || itemsContainer is String) return '';

    final items = itemsContainer['item'];

    if (items == null) return '';

    final List<dynamic> list = (items is List) ? items : [items];

    if (list.isEmpty) return '';

    return (list.first['signguCd'] ?? '').toString();

  }

  Color _rateColor(double rate) {
    if (rate >= 70) return Colors.redAccent;
    if (rate >= 40) return const Color(0xFFFFA000);
    return Colors.green;
  }

  String _rateLabel(double rate) {
    if (rate >= 70) return "혼잡";
    if (rate >= 40) return "보통";
    return "쾌적";
  }

  List<Map<String, String>> _filterByCrowdTab(List<Map<String, String>> spots) {

    return spots.where((spot) {

      final double rate = double.tryParse(spot["rate"] ?? '') ?? 0;

      final String label = _rateLabel(rate);

      switch (selectedCrowdTab) {
        case _CrowdTab.crowded:
          return label == "혼잡";
        case _CrowdTab.normal:
          return label == "보통";
        case _CrowdTab.comfortable:
          return label == "쾌적";
      }

    }).toList();

  }

  // ⭐ 기초 중심(hub) 데이터 조회 - 크라우드 데이터의 signguCd 전부 사용, 이름 중복 제외
  Future<List<Map<String, dynamic>>> _fetchHubSpots(_SpotResult crowdResult) async {

    final Set<String> excludeNames = crowdResult.spots.map((s) => s['name'] ?? '').toSet();

    final Set<String> signguCds = crowdResult.spots
        .map((s) => s['signguCd'] ?? '')
        .where((e) => e.isNotEmpty)
        .toSet();

    if (signguCds.isEmpty && crowdResult.signguCd.isNotEmpty) {
      signguCds.add(crowdResult.signguCd);
    }

    final baseYm = _lastMonthYm();

    final Set<String> seenNames = {};

    final List<Map<String, dynamic>> all = [];

    for (final cd in signguCds) {

      try {

        final url = '${dotenv.env['PHP_URL']}api_zoongsim.php'
            '?areaCd=44'
            '&signguCd=${Uri.encodeComponent(cd)}'
            '&baseYm=$baseYm'
            '&numOfRows=1000';

        final response = await http.get(Uri.parse(url));

        if (response.statusCode != 200) continue;

        final data = jsonDecode(response.body);

        if (data['success'] != true) continue;

        final itemsContainer = data['data']?['response']?['body']?['items'];

        if (itemsContainer == null || itemsContainer is String) continue;

        final rawItems = itemsContainer['item'];

        if (rawItems == null) continue;

        final List<dynamic> items = (rawItems is List) ? rawItems : [rawItems];

        for (final raw in items) {

          final item = Map<String, dynamic>.from(raw);

          final String name = (item['hubTatsNm'] ?? '').toString();

          if (name.isEmpty) continue;

          if (excludeNames.contains(name)) continue; // 혼잡도 탭과 중복 제외

          if (seenNames.contains(name)) continue; // signguCd 여러 개 순회 시 중복 제외

          seenNames.add(name);

          all.add(item);

        }

      } catch (e) {
        // 개별 signguCd 실패는 무시하고 계속 진행
      }

    }

    return all;

  }

  void _ensureHubFuture(_SpotResult crowdResult) {
    _hubFuture ??= _fetchHubSpots(crowdResult);
  }

  // ⭐ hubCtgryMclsNm -> 4개 탭 분류
  _HubTab? _classifyHub(String mclsNm) {

    if (mclsNm == '숙박') return _HubTab.lodging;

    if (mclsNm == '레저스포츠') return _HubTab.leisure;

    if (mclsNm == '쇼핑') return _HubTab.shopping;

    if (mclsNm.endsWith('관광')) return _HubTab.tour;

    return null; // 4개 분류에 해당 안 되면 표시 안 함

  }

  List<Map<String, dynamic>> _filterByHubTab(List<Map<String, dynamic>> items) {

    final filtered = items.where((item) {

      final String mclsNm = (item['hubCtgryMclsNm'] ?? '').toString();

      return _classifyHub(mclsNm) == selectedHubTab;

    }).toList();

    filtered.sort((a, b) {

      final rankA = int.tryParse((a['hubRank'] ?? '999').toString()) ?? 999;
      final rankB = int.tryParse((b['hubRank'] ?? '999').toString()) ?? 999;

      return rankA.compareTo(rankB);

    });

    return filtered;

  }

  void _goToSpot2(String name, String? signguCd, String fallbackSignguCd) {

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Spot2Page(
          regionName: widget.regionName,
          signguCd: (signguCd != null && signguCd.isNotEmpty) ? signguCd : fallbackSignguCd,
          name: name,
        ),
      ),
    );

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0xFFF7F7F9),

      appBar: AppBar(
        title: Text(
          '${widget.regionName} 관광지 목록',
          style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87, fontSize: 18),
        ),
        centerTitle: false,
        backgroundColor: const Color(0xFFF7F7F9),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),

      body: FutureBuilder<_SpotResult>(
        future: _spotFuture,
        builder: (context, snapshot) {

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: primary));
          }

          if (snapshot.hasError) {

            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline_rounded, size: 56, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text("정보를 불러올 수 없습니다", style: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontWeight: FontWeight.w500)),
                ],
              ),
            );

          }

          final result = snapshot.data!;

          if (selectedTopTab == _TopTab.hub) {
            _ensureHubFuture(result);
          }

          return Column(
            children: [

              // ===== 상위 탭: 혼잡도 기반 / 기초 중심 =====
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: _PillTabButton(
                        label: "혼잡도 기반 스팟",
                        color: Color(0xFFFFA000),
                        selected: selectedTopTab == _TopTab.crowd,
                        onTap: () => setState(() => selectedTopTab = _TopTab.crowd),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _PillTabButton(
                        label: "카테고리 스팟",
                        color: Color(0xFFFFA000),
                        selected: selectedTopTab == _TopTab.hub,
                        onTap: () => setState(() => selectedTopTab = _TopTab.hub),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              Expanded(
                child: selectedTopTab == _TopTab.crowd
                    ? _buildCrowdTabContent(result)
                    : _buildHubTabContent(result),
              ),

            ],
          );

        },
      ),

    );
  }

  Widget _buildCrowdTabContent(_SpotResult result) {

    final filteredSpots = _filterByCrowdTab(result.spots);

    return Column(
      children: [

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: _PillTabButton(
                  label: "혼잡",
                  color: Colors.redAccent,
                  selected: selectedCrowdTab == _CrowdTab.crowded,
                  onTap: () => setState(() => selectedCrowdTab = _CrowdTab.crowded),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PillTabButton(
                  label: "보통",
                  color: const Color(0xFFFFA000),
                  selected: selectedCrowdTab == _CrowdTab.normal,
                  onTap: () => setState(() => selectedCrowdTab = _CrowdTab.normal),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PillTabButton(
                  label: "쾌적",
                  color: Colors.green,
                  selected: selectedCrowdTab == _CrowdTab.comfortable,
                  onTap: () => setState(() => selectedCrowdTab = _CrowdTab.comfortable),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        Expanded(

          child: filteredSpots.isEmpty
              ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.travel_explore_rounded, size: 56, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text("해당하는 관광지가 없습니다", style: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          )
              : ListView.separated(

            padding: const EdgeInsets.all(16),

            itemCount: filteredSpots.length,

            separatorBuilder: (_, __) => const SizedBox(height: 10),

            itemBuilder: (context, index) {

              final spot = filteredSpots[index];

              final String name = spot["name"] ?? "이름 없음";

              final double rate = double.tryParse(spot["rate"] ?? '') ?? 0;

              final Color color = _rateColor(rate);

              return InkWell(

                borderRadius: BorderRadius.circular(18),

                onTap: () => _goToSpot2(name, spot["signguCd"], result.signguCd),

                child: Container(

                  padding: const EdgeInsets.all(16),

                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
                  ),

                  child: Row(
                    children: [

                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
                        child: Icon(Icons.place_rounded, color: color, size: 22),
                      ),

                      const SizedBox(width: 14),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87)),

                            const SizedBox(height: 4),

                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                                  child: Text(_rateLabel(rate), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                                ),
                                const SizedBox(width: 6),
                                Text("혼잡도 ${rate.toStringAsFixed(1)}%", style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                              ],
                            ),

                          ],
                        ),
                      ),

                      Text("${rate.toStringAsFixed(0)}%", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),

                      const SizedBox(width: 6),

                      Icon(Icons.chevron_right_rounded, color: Colors.grey.shade300),

                    ],
                  ),

                ),

              );

            },

          ),

        ),

      ],
    );

  }

  Widget _buildHubTabContent(_SpotResult crowdResult) {

    return Column(
      children: [

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: _PillTabButton(
                  label: "숙박",
                  color: primary,
                  selected: selectedHubTab == _HubTab.lodging,
                  onTap: () => setState(() => selectedHubTab = _HubTab.lodging),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _PillTabButton(
                  label: "레저스포츠",
                  color: primary,
                  selected: selectedHubTab == _HubTab.leisure,
                  onTap: () => setState(() => selectedHubTab = _HubTab.leisure),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _PillTabButton(
                  label: "쇼핑",
                  color: primary,
                  selected: selectedHubTab == _HubTab.shopping,
                  onTap: () => setState(() => selectedHubTab = _HubTab.shopping),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _PillTabButton(
                  label: "관광",
                  color: primary,
                  selected: selectedHubTab == _HubTab.tour,
                  onTap: () => setState(() => selectedHubTab = _HubTab.tour),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        Expanded(

          child: FutureBuilder<List<Map<String, dynamic>>>(

            future: _hubFuture,

            builder: (context, snapshot) {

              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: primary));
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text("정보를 불러올 수 없습니다", style: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontWeight: FontWeight.w500)),
                );
              }

              final all = snapshot.data ?? [];

              final filtered = _filterByHubTab(all);

              if (filtered.isEmpty) {

                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.travel_explore_rounded, size: 56, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text("해당하는 장소가 없습니다", style: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontWeight: FontWeight.w500)),
                    ],
                  ),
                );

              }

              return ListView.separated(

                padding: const EdgeInsets.all(16),

                itemCount: filtered.length,

                separatorBuilder: (_, __) => const SizedBox(height: 10),

                itemBuilder: (context, index) {

                  final item = filtered[index];

                  final String name = (item['hubTatsNm'] ?? '').toString();

                  final String itemSignguCd = (item['signguCd'] ?? '').toString();

                  return InkWell(

                    borderRadius: BorderRadius.circular(18),

                    onTap: () => _goToSpot2(name, itemSignguCd, crowdResult.signguCd),

                    child: Container(

                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),

                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
                      ),

                      child: Row(
                        children: [
                          Expanded(
                            child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87)),
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
    );

  }

}

class _SpotResult {
  final List<Map<String, String>> spots;
  final String signguCd;
  _SpotResult({required this.spots, required this.signguCd});
}

class _PillTabButton extends StatelessWidget {

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _PillTabButton({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? color : Colors.grey.shade200, width: 1.4),
          boxShadow: selected ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : [],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? Colors.white : Colors.grey.shade500),
          ),
        ),
      ),
    );
  }

}