import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../spot/information.dart';

// ⭐ 충청남도 15개 지역 키워드 (rdnmadr/lnmadr 속 지역 판별용)
const List<String> chungnamRegionKeywords = [
  "천안", "아산", "당진", "서산", "태안", "예산", "홍성", "청양",
  "공주", "보령", "부여", "서천", "논산", "계룡", "금산",
];

String? matchChungnamRegion(Map<String, dynamic> item) {

  final String lnmadr = (item['lnmadr'] ?? '').toString();
  final String rdnmadr = (item['rdnmadr'] ?? '').toString();

  for (final keyword in chungnamRegionKeywords) {

    if (lnmadr.contains(keyword) || rdnmadr.contains(keyword)) {
      return keyword;
    }

  }

  return null;

}

class FestivalCalendarDialog extends StatefulWidget {

  final BuildContext pageContext;

  final Color primary;

  const FestivalCalendarDialog({
    super.key,
    required this.pageContext,
    required this.primary,
  });

  @override
  State<FestivalCalendarDialog> createState() => _FestivalCalendarDialogState();

}

class _FestivalCalendarDialogState extends State<FestivalCalendarDialog> {

  late Future<List<Map<String, dynamic>>> _future;

  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  // ⭐ 선택된 날짜 (기본값: 오늘)
  DateTime _selectedDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  @override
  void initState() {
    super.initState();
    _future = _fetchFestivals();
  }

  Future<List<Map<String, dynamic>>> _fetchFestivals() async {

    // ⭐ content.dart와 동일하게 content_festival.php 재사용
    final url = '${dotenv.env['PHP_URL']}content_festival.php';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) throw Exception('데이터 로드 실패');

    final data = jsonDecode(response.body);

    if (data['success'] != true) throw Exception('데이터 로드 실패');

    dynamic rawItems;

    try {
      rawItems = data['raw_response']['body']['items']['item'];
    } catch (e) {
      rawItems = null;
    }

    List items = [];

    if (rawItems is List) {
      items = rawItems;
    } else if (rawItems is Map) {
      items = [rawItems];
    }

    const String keyword = "충청남도";

    final matchedList = items.where((item) {

      if (item is Map) {

        return item.values.any((value) {

          if (value != null) {
            return value.toString().contains(keyword);
          }

          return false;

        });

      }

      return false;

    }).toList();

    return matchedList.map((e) => Map<String, dynamic>.from(e as Map)).toList();

  }

  bool _isFestivalOnDay(Map<String, dynamic> item, DateTime day) {

    final start = DateTime.tryParse((item['fstvlStartDate'] ?? '').toString());
    final end = DateTime.tryParse((item['fstvlEndDate'] ?? '').toString());

    if (start == null || end == null) return false;

    final dayOnly = DateTime(day.year, day.month, day.day);
    final startOnly = DateTime(start.year, start.month, start.day);
    final endOnly = DateTime(end.year, end.month, end.day);

    return !dayOnly.isBefore(startOnly) && !dayOnly.isAfter(endOnly);

  }

  void _changeMonth(int diff) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + diff, 1);
    });
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
  }

  void _goToInformation(String regionName) {

    Navigator.pop(context); // 달력 다이얼로그 닫기

    Navigator.push(
      widget.pageContext,
      MaterialPageRoute(builder: (context) => InformationPage(regionName: regionName)),
    );

  }

  @override
  Widget build(BuildContext context) {

    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: Container(
        // ⭐ 기존보다 약 20% 커진 높이
        height: screenHeight * 0.86,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: FutureBuilder<List<Map<String, dynamic>>>(

          future: _future,

          builder: (context, snapshot) {

            if (snapshot.connectionState == ConnectionState.waiting) {

              return const Center(child: CircularProgressIndicator());

            }

            if (snapshot.hasError) {

              return Center(
                child: Text("정보를 불러올 수 없습니다", style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
              );

            }

            final festivals = snapshot.data ?? [];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

                // ===== 상단 70% : 달력 영역 =====
                Expanded(
                  flex: 7,
                  child: _buildCalendarBody(festivals),
                ),

                const Divider(height: 24),

                // ===== 하단 30% : 선택 날짜 축제 목록 =====
                Expanded(
                  flex: 3,
                  child: _buildSelectedDayFestivals(festivals),
                ),

              ],
            );

          },

        ),
      ),
    );

  }

  Widget _buildCalendarBody(List<Map<String, dynamic>> festivals) {

    final int daysInMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;

    final int leadingBlanks = _visibleMonth.weekday % 7; // 일요일 시작 기준

    final int totalCells = leadingBlanks + daysInMonth;

    final int rows = (totalCells / 7).ceil();

    final today = DateTime.now();

    const weekdayLabels = ['일', '월', '화', '수', '목', '금', '토'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [

            const SizedBox(width: 40), // 좌측 여백 균형용

            Row(
              children: [
                IconButton(
                  onPressed: () => _changeMonth(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                  color: Colors.grey.shade600,
                ),
                Text(
                  "${_visibleMonth.year}년 ${_visibleMonth.month}월",
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.black87),
                ),
                IconButton(
                  onPressed: () => _changeMonth(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                  color: Colors.grey.shade600,
                ),
              ],
            ),

            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.close_rounded, color: Colors.grey.shade400),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),

          ],
        ),

        const SizedBox(height: 8),

        Row(
          children: List.generate(7, (index) {

            final isSunday = index == 0;
            final isSaturday = index == 6;

            return Expanded(
              child: Center(
                child: Text(
                  weekdayLabels[index],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSunday ? Colors.redAccent : (isSaturday ? Colors.blueAccent : Colors.grey.shade500),
                  ),
                ),
              ),
            );

          }),
        ),

        const SizedBox(height: 4),

        Expanded(

          child: GridView.builder(

            physics: const NeverScrollableScrollPhysics(),

            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
              mainAxisSpacing: 2,
            ),

            itemCount: rows * 7,

            itemBuilder: (context, index) {

              final int dayNumber = index - leadingBlanks + 1;

              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const SizedBox.shrink();
              }

              final date = DateTime(_visibleMonth.year, _visibleMonth.month, dayNumber);

              final dayFestivals = festivals.where((f) => _isFestivalOnDay(f, date)).toList();

              final bool hasFestival = dayFestivals.isNotEmpty;

              final bool isToday = date.year == today.year && date.month == today.month && date.day == today.day;

              // ⭐ 선택된 날짜인지 판별 (누른 날짜에 색칠)
              final bool isSelected = date.year == _selectedDate.year
                  && date.month == _selectedDate.month
                  && date.day == _selectedDate.day;

              final int weekdayIndex = index % 7;

              return GestureDetector(

                onTap: () => _selectDate(date),

                child: Container(

                  margin: const EdgeInsets.all(2),

                  decoration: BoxDecoration(
                    // ⭐ 선택된 날짜만 색칠, 오늘은 선택 해제 시 색칠 없음
                    color: isSelected ? widget.primary.withOpacity(0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: isSelected
                        ? Border.all(color: widget.primary, width: 1.4)
                        : null,
                  ),

                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [

                      Text(
                        "$dayNumber",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: (isSelected || isToday) ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected
                              ? widget.primary
                              : (weekdayIndex == 0
                              ? Colors.redAccent
                              : (weekdayIndex == 6 ? Colors.blueAccent : Colors.black87)),
                        ),
                      ),

                      const SizedBox(height: 3),

                      if (hasFestival)

                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isSelected ? widget.primary : widget.primary.withOpacity(0.7),
                            shape: BoxShape.circle,
                          ),
                        )
                      else
                        const SizedBox(height: 5),

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

  Widget _buildSelectedDayFestivals(List<Map<String, dynamic>> festivals) {

    final dayFestivals = festivals.where((f) => _isFestivalOnDay(f, _selectedDate)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [

        Row(
          children: [

            Icon(Icons.event_rounded, size: 15, color: widget.primary),

            const SizedBox(width: 6),

            Text(
              "${_selectedDate.month}월 ${_selectedDate.day}일",
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black87),
            ),

            const SizedBox(width: 6),

            Text(
              dayFestivals.isEmpty ? "" : "· ${dayFestivals.length}건",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
            ),

          ],
        ),

        const SizedBox(height: 10),

        Expanded(

          child: dayFestivals.isEmpty

              ? Center(
            child: Text(
              "이 날은 진행 중인 축제가 없어요",
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400, fontWeight: FontWeight.w500),
            ),
          )

              : ListView.separated(

            itemCount: dayFestivals.length,

            separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),

            itemBuilder: (context, index) {

              final item = dayFestivals[index];

              final String name = (item['fstvlNm'] ?? '').toString();

              final String? region = matchChungnamRegion(item);

              return InkWell(

                onTap: region != null ? () => _goToInformation(region) : null,

                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [

                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: widget.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.celebration_rounded, size: 15, color: widget.primary),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Text(
                          name.isEmpty ? "이름 없음" : name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87),
                        ),
                      ),

                      const SizedBox(width: 8),

                      if (region != null)

                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: widget.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            region,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: widget.primary),
                          ),
                        ),

                      if (region != null) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey.shade300),
                      ],

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

}