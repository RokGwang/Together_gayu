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

enum _HubTab { lodging, leisure, shopping, tour }

class _SpotPageState extends State<SpotPage> {

  static const Color primary = Color(0xFFFF7A00);

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  late Future<List<String>> _signguCdListFuture;

  Future<List<Map<String, dynamic>>>? _hubFuture;

  _HubTab selectedHubTab = _HubTab.tour;

  @override
  void initState() {
    super.initState();
    _signguCdListFuture = _fetchSignguCdList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _lastMonthYm() {
    final now = DateTime.now();
    final lastMonthDate = DateTime(now.year, now.month - 2, 1);
    final y = lastMonthDate.year.toString();
    final m = lastMonthDate.month.toString().padLeft(2, '0');
    return "$y$m";
  }

  // ⭐ api_people.php 제거 -> information2.php의 signguCd 필드만 사용 (천안처럼 쉼표로 여러 개인 경우 분리)
  Future<List<String>> _fetchSignguCdList() async {

    final url = '${dotenv.env['PHP_URL']}information.php?regionname=${Uri.encodeComponent(widget.regionName)}';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception('데이터 로드 실패');
    }

    final data = jsonDecode(response.body);

    if (data['success'] != true) {
      throw Exception(data['error'] ?? '데이터 로드 실패');
    }

    final String raw = (data['signguCd'] ?? '').toString();

    return raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  }

  Future<List<Map<String, dynamic>>> _fetchHubSpots(List<String> signguCdList) async {
    final baseYm = _lastMonthYm();
    final Set<String> seenNames = {};
    final List<Map<String, dynamic>> all = [];
    for (final cd in signguCdList) {
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
          if (seenNames.contains(name)) continue;
          seenNames.add(name);
          all.add(item);
        }
      } catch (e) {
        // 개별 signguCd 실패는 무시하고 계속 진행
      }
    }
    return all;
  }

  void _ensureHubFuture(List<String> signguCdList) {
    _hubFuture ??= _fetchHubSpots(signguCdList);
  }

  _HubTab? _classifyHub(String mclsNm) {
    if (mclsNm == '숙박') return _HubTab.lodging;
    if (mclsNm == '레저스포츠') return _HubTab.leisure;
    if (mclsNm == '쇼핑') return _HubTab.shopping;
    if (mclsNm.endsWith('관광')) return _HubTab.tour;
    return null;
  }

  List<Map<String, dynamic>> _filterBySearch(List<Map<String, dynamic>> items) {

    final query = _searchQuery.trim().toLowerCase();

    final filtered = items.where((item) {

      final String name = (item['hubTatsNm'] ?? '').toString().toLowerCase();

      return name.contains(query);

    }).toList();

    filtered.sort((a, b) {

      final rankA = int.tryParse((a['hubRank'] ?? '999').toString()) ?? 999;

      final rankB = int.tryParse((b['hubRank'] ?? '999').toString()) ?? 999;

      return rankA.compareTo(rankB);

    });

    return filtered;

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

  // ⭐ spot2.dart -> spot3.dart로 변경
  void _goToSpot3(Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Spot2Page(
          regionName: widget.regionName,
          hubTatsNm: (item['hubTatsNm'] ?? '').toString(),
          hubCtgryLclsNm: (item['hubCtgryLclsNm'] ?? '').toString(),
          hubCtgryMclsNm: (item['hubCtgryMclsNm'] ?? '').toString(),
          mapX: (item['mapX'] ?? '').toString(),
          mapY: (item['mapY'] ?? '').toString(),
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
      body: FutureBuilder<List<String>>(
        future: _signguCdListFuture,
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
          final signguCdList = snapshot.data ?? [];
          _ensureHubFuture(signguCdList);
          return Column(
            children: [
              const SizedBox(height: 12),

              // ⭐ 검색창 (탭과 무관하게 전체 검색)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: "관광지 이름으로 검색",
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 20),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                        icon: Icon(Icons.close_rounded, color: Colors.grey.shade400, size: 18),
                        onPressed: () => setState(() {
                          _searchController.clear();
                          _searchQuery = "";
                        }),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // ⭐ 검색 중엔 탭 버튼 자체를 숨김 (탭 분류가 의미 없어지므로)
              if (_searchQuery.trim().isEmpty)

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _PillTabButton(
                          label: "관광",
                          color: primary,
                          selected: selectedHubTab == _HubTab.tour,
                          onTap: () => setState(() => selectedHubTab = _HubTab.tour),
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
                          label: "숙박",
                          color: primary,
                          selected: selectedHubTab == _HubTab.lodging,
                          onTap: () => setState(() => selectedHubTab = _HubTab.lodging),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 8),
              Expanded(
                child: _buildHubTabContent(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHubTabContent() {
    return FutureBuilder<List<Map<String, dynamic>>>(
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

        // ⭐ 검색어가 있으면 탭 분류 무시하고 전체에서 검색, 없으면 기존 탭 필터링
        final filtered = _searchQuery.trim().isNotEmpty
            ? _filterBySearch(all)
            : _filterByHubTab(all);

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
            return InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _goToSpot3(item),
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
    );
  }
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