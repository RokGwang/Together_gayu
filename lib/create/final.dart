import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../chat/chat.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FinalPage extends StatefulWidget {

  final int userId;
  final String type;
  final String startPlace;
  final String endPlace;
  final String roomTable;

  const FinalPage({
    super.key,
    required this.userId,
    required this.type,
    required this.startPlace,
    required this.endPlace,
    required this.roomTable,
  });

  @override
  State<FinalPage> createState() => _FinalPageState();
}

class _FinalPageState extends State<FinalPage> {

  static const Color primary = Color(0xFFFF7A00);

  int selectedHour = 12;
  int selectedMinute = 0;
  int peopleCount = 2;

  bool isLoading = false;

  // ===== 추가 =====
  bool isScheduleMode = true; // true = 시간예약, false = 시간조율

  DateTime selectedDate = DateTime.now();

  final List<int> hours = List.generate(24, (i) => i);
  final List<int> minutes = List.generate(12, (i) => i * 5);
  late final FixedExtentScrollController hourController =
  FixedExtentScrollController(initialItem: hours.indexOf(12));

  late final FixedExtentScrollController minuteController =
  FixedExtentScrollController(initialItem: minutes.indexOf(0));

  final String serverUrl =
      "${dotenv.env['PHP_URL']}final.php";

  // =========================
  Future<void> createRoom() async {

    setState(() => isLoading = true);

    try {

      String? formattedTime;

      if (isScheduleMode) {

        final dt = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          selectedHour,
          selectedMinute,
        );

        formattedTime =
        "${dt.year}-"
            "${dt.month.toString().padLeft(2, '0')}-"
            "${dt.day.toString().padLeft(2, '0')} "
            "${dt.hour.toString().padLeft(2, '0')}:"
            "${dt.minute.toString().padLeft(2, '0')}:00";
      }

      final response = await http.post(

        Uri.parse(serverUrl),

        headers: {"Content-Type": "application/json"},

        body: jsonEncode({

          "table": widget.roomTable,
          "type": widget.type,
          "time": formattedTime, // null 가능
          "start": widget.startPlace,
          "end": widget.endPlace,
          "user_id": widget.userId,
          "people": peopleCount,

        }),
      );

      final data = jsonDecode(response.body);

      if (data["success"] == true) {

        if (!mounted) return;

        Navigator.pushAndRemoveUntil(

          context,

          MaterialPageRoute(

            builder: (_) => ChatPage(
              roomId: data["room_id"],
              userId: widget.userId,
            ),
          ),

          ModalRoute.withName('room'),
        );

      } else {

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data["message"])),
        );
      }

    } catch (e) {

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("에러: $e")),
      );

    } finally {

      if (!mounted) return;

      setState(() => isLoading = false);
    }
  }

  // =========================
  void pickDate() async {

    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primary,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  // =========================
  @override
  Widget build(BuildContext context) {

    final isDisabled = !isScheduleMode;

    return Scaffold(

      backgroundColor: const Color(0xFFF7F7F9),

      appBar: AppBar(
        title: const Text(
          '최종 설정',
          style: TextStyle(
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

      body: SingleChildScrollView(

        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            // =======================
            // 출발/도착 요약 카드
            // =======================
            Container(

              width: double.infinity,

              padding: const EdgeInsets.all(16),

              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),

              child: Row(
                children: [

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '출발지',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.startPlace,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: Colors.grey.shade400,
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '목적지',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.endPlace,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: primary,
                          ),
                        ),
                      ],
                    ),
                  ),

                ],
              ),

            ),

            const SizedBox(height: 24),

            // =======================
            // 1. 시간 예약 / 조율
            // =======================
            const Text(
              '시간 설정',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 10),

            Row(

              children: [

                Expanded(
                  child: _SelectChip(
                    label: '시간 예약',
                    selected: isScheduleMode,
                    color: primary,
                    onTap: () {
                      setState(() {
                        isScheduleMode = true;
                      });
                    },
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: _SelectChip(
                    label: '시간 조율',
                    selected: !isScheduleMode,
                    color: primary,
                    onTap: () {
                      setState(() {
                        isScheduleMode = false;
                      });
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // =======================
            // 2. 날짜 선택 버튼
            // =======================
            GestureDetector(

              onTap: isDisabled ? null : pickDate,

              child: Opacity(

                opacity: isDisabled ? 0.4 : 1.0,

                child: Container(

                  width: double.infinity,

                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),

                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),

                  child: Row(
                    children: [

                      Icon(
                        Icons.calendar_today_rounded,
                        size: 18,
                        color: primary,
                      ),

                      const SizedBox(width: 10),

                      Text(
                        "${selectedDate.year}년 ${selectedDate.month}월 ${selectedDate.day}일",
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),

                      const Spacer(),

                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.grey.shade400,
                      ),

                    ],
                  ),

                ),

              ),

            ),

            const SizedBox(height: 16),

            // =======================
            // 3. 시간 선택
            // =======================
            Opacity(

              opacity: isDisabled ? 0.35 : 1.0,

              child: IgnorePointer(

                ignoring: isDisabled,

                child: Container(

                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),

                  padding: const EdgeInsets.symmetric(vertical: 8),

                  child: SizedBox(

                    height: 170,

                    child: Row(

                      children: [

                        Expanded(
                          child: CupertinoPicker(
                            scrollController: hourController,
                            itemExtent: 44,
                            onSelectedItemChanged: (i) {
                              selectedHour = hours[i];
                            },
                            children: hours
                                .map((e) => Center(
                              child: Text(
                                "$e 시",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ))
                                .toList(),
                          ),
                        ),

                        Expanded(
                          child: CupertinoPicker(
                            scrollController: minuteController,
                            itemExtent: 44,
                            onSelectedItemChanged: (i) {
                              selectedMinute = minutes[i];
                            },
                            children: minutes
                                .map((e) => Center(
                              child: Text(
                                "$e 분",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ))
                                .toList(),
                          ),
                        ),

                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // =======================
            // 인원
            // =======================
            const Text(
              '인원 설정',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 10),

            Container(

              width: double.infinity,

              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),

              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),

              child: Row(

                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [

                  Text(
                    '최대 인원 (2~5명)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),

                  Row(

                    children: [

                      _CounterButton(
                        icon: Icons.remove_rounded,
                        enabled: peopleCount > 2,
                        color: primary,
                        onTap: () {
                          if (peopleCount > 2) {
                            setState(() => peopleCount--);
                          }
                        },
                      ),

                      SizedBox(
                        width: 44,
                        child: Text(
                          "$peopleCount명",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),
                      ),

                      _CounterButton(
                        icon: Icons.add_rounded,
                        enabled: peopleCount < 5,
                        color: primary,
                        onTap: () {
                          if (peopleCount < 5) {
                            setState(() => peopleCount++);
                          }
                        },
                      ),

                    ],
                  ),

                ],
              ),

            ),

          ],
        ),
      ),

      floatingActionButton: Container(

        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: primary.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),

        child: FloatingActionButton.extended(

          onPressed: isLoading ? null : createRoom,

          backgroundColor: primary,

          elevation: 0,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),

          label: Text(
            isLoading ? "생성중..." : "생성",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),

          icon: const Icon(
            Icons.check_rounded,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _SelectChip extends StatelessWidget {

  final String label;

  final bool selected;

  final Color color;

  final VoidCallback onTap;

  const _SelectChip({

    required this.label,

    required this.selected,

    required this.color,

    required this.onTap,

  });

  @override
  Widget build(BuildContext context) {

    return GestureDetector(

      onTap: onTap,

      child: Container(

        padding: const EdgeInsets.symmetric(vertical: 14),

        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 1.6,
          ),
          boxShadow: selected
              ? []
              : [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),

        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selected ? color : Colors.grey.shade600,
            ),
          ),
        ),

      ),

    );

  }

}

class _CounterButton extends StatelessWidget {

  final IconData icon;

  final bool enabled;

  final Color color;

  final VoidCallback onTap;

  const _CounterButton({

    required this.icon,

    required this.enabled,

    required this.color,

    required this.onTap,

  });

  @override
  Widget build(BuildContext context) {

    return GestureDetector(

      onTap: enabled ? onTap : null,

      child: Container(

        width: 32,

        height: 32,

        decoration: BoxDecoration(
          color: enabled ? color.withOpacity(0.12) : Colors.grey.shade100,
          shape: BoxShape.circle,
        ),

        child: Icon(

          icon,

          size: 18,

          color: enabled ? color : Colors.grey.shade400,

        ),

      ),

    );

  }

}