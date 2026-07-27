import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../chat/chat.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GPSPage extends StatefulWidget {

  final int userId;

  final String type;

  final String roomTable;

  final String endPlace;

  const GPSPage({
    super.key,
    required this.userId,
    required this.type,
    required this.roomTable,
    required this.endPlace,
  });

  @override
  State<GPSPage> createState() => _GPSPageState();
}

enum _MatchStage { checkingPermission, permissionDenied, searching, matched, error }

class _GPSPageState extends State<GPSPage> with SingleTickerProviderStateMixin {

  static const Color primary = Color(0xFFFF7A00);

  _MatchStage stage = _MatchStage.checkingPermission;

  int? matchingId;

  double? myLat;
  double? myLng;

  bool myApproved = false;
  bool partnerApproved = false;

  Timer? pollTimer;
  Timer? timeoutTimer;

  int remainingSeconds = 30;

  late final AnimationController pulseController;

  @override
  void initState() {

    super.initState();

    pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _init();

  }

  @override
  void dispose() {

    pollTimer?.cancel();
    timeoutTimer?.cancel();
    pulseController.dispose();

    // 페이지를 벗어날 때 매칭 중이었다면 서버에도 취소 처리
    if (matchingId != null && stage != _MatchStage.error) {
      _cancelMatchingSilently();
    }

    super.dispose();
  }

  Future<void> _cancelMatchingSilently() async {

    try {

      await http.post(
        Uri.parse("${dotenv.env['PHP_URL']}gps_cancel.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "matching_id": matchingId,
          "user_id": widget.userId,
        }),
      );

    } catch (e) {
      // 페이지 나가는 중이라 실패해도 무시
    }

  }

  // =========================
  Future<void> _init() async {

    await checkLocationPermission();

  }

  Future<void> checkLocationPermission() async {

    var status = await Permission.location.status;

    if (!status.isGranted) {

      status = await Permission.location.request();

    }

    if (!mounted) return;

    if (!status.isGranted) {

      setState(() {
        stage = _MatchStage.permissionDenied;
      });

      return;

    }

    await _getLocationAndStart();

  }

  Future<void> _getLocationAndStart() async {

    try {

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {

        if (!mounted) return;

        setState(() {
          stage = _MatchStage.permissionDenied;
        });

        return;

      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      myLat = position.latitude;
      myLng = position.longitude;

      await startMatching();

    } catch (e) {

      if (!mounted) return;

      setState(() {
        stage = _MatchStage.error;
      });

    }

  }

  // =========================
  Future<void> startMatching() async {

    if (!mounted) return;

    setState(() {
      stage = _MatchStage.searching;
    });

    try {

      final response = await http.post(
        Uri.parse("${dotenv.env['PHP_URL']}gps_start.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": widget.userId,
          "region": widget.roomTable,
          "type": widget.type,
          "end": widget.endPlace,
          "lat": myLat,
          "lng": myLng,
        }),
      );

      final data = jsonDecode(response.body);

      if (data["success"] == true) {

        matchingId = data["matching_id"];

        pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
          checkMatching();
        });

      } else {

        if (!mounted) return;

        setState(() {
          stage = _MatchStage.error;
        });

      }

    } catch (e) {

      if (!mounted) return;

      setState(() {
        stage = _MatchStage.error;
      });

    }

  }

  // =========================
  Future<void> checkMatching() async {

    if (matchingId == null) return;

    try {

      final response = await http.post(
        Uri.parse("${dotenv.env['PHP_URL']}gps_check.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "matching_id": matchingId,
          "user_id": widget.userId,
        }),
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (data["success"] != true) return;

      final status = data["status"];

      if (status == "searching") {

        final bool partnerCancelled = data["partner_cancelled"] == true;

        // ⭐ 매칭 상태였다가 searching으로 돌아온 경우만 처리 (거절/취소로 인한 전환)
        if (stage == _MatchStage.matched) {

          timeoutTimer?.cancel();
          pollTimer?.cancel();

          if (partnerCancelled) {

            // ⭐ 상대방이 거절한 경우 - 확인 팝업을 띄운 뒤에만 재검색
            setState(() {
              myApproved = false;
              partnerApproved = false;
            });

            await _showRestartNoticeDialog(
              title: "상대방이 거절했습니다",
              message: "다시 매칭을 시작할게요",
            );

            if (!mounted) return;

          }

          setState(() {
            stage = _MatchStage.searching;
          });

          // 서버 쪽 상태는 이미 searching이므로 새로 gps_start를 호출하지 않고 폴링만 재개
          pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
            checkMatching();
          });

        }
        // 그 외(원래도 searching 상태였던 경우)는 별도 처리 없이 대기 계속

      } else if (status == "matched") {

        final bool newMyApproved = data["my_approved"] == 1;
        final bool newPartnerApproved = data["partner_approved"] == 1;

        if (stage != _MatchStage.matched) {

          // 방금 매칭됨 -> 30초 타임아웃 시작
          setState(() {
            stage = _MatchStage.matched;
            myApproved = newMyApproved;
            partnerApproved = newPartnerApproved;
            remainingSeconds = 30;
          });

          startTimeoutTimer();

        } else {

          setState(() {
            myApproved = newMyApproved;
            partnerApproved = newPartnerApproved;
          });

        }

      } else if (status == "completed") {

        pollTimer?.cancel();
        timeoutTimer?.cancel();

        final roomId = data["room_id"];

        matchingId = null; // dispose에서 재취소 방지

        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => ChatPage(
              roomId: roomId,
              userId: widget.userId,
            ),
          ),
          ModalRoute.withName('room'),
        );

      } else if (status == "cancelled") {

        pollTimer?.cancel();
        timeoutTimer?.cancel();

        if (!mounted) return;

        setState(() {
          stage = _MatchStage.error;
        });

      }

    } catch (e) {

      // 폴링 중 일시적 에러는 무시하고 다음 주기에 재시도

    }

  }

  // =========================
  void startTimeoutTimer() {

    timeoutTimer?.cancel();

    remainingSeconds = 30;

    timeoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {

      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        remainingSeconds--;
      });

      if (remainingSeconds <= 0) {

        timer.cancel();

        handleTimeout();

      }

    });

  }

  Future<void> handleTimeout() async {

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("응답 시간이 초과되어 다시 탐색합니다")),
    );

    await cancelAndRestart();

  }

  Future<void> cancelAndRestart() async {

    timeoutTimer?.cancel();

    if (matchingId != null) {

      try {

        await http.post(
          Uri.parse("${dotenv.env['PHP_URL']}gps_cancel.php"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "matching_id": matchingId,
            "user_id": widget.userId,
          }),
        );

      } catch (e) {
        // 무시하고 재탐색 진행
      }

    }

    pollTimer?.cancel();

    if (!mounted) return;

    setState(() {
      myApproved = false;
      partnerApproved = false;
    });

    await startMatching();

  }

  // ⭐ "거절" 버튼 전용: 확인 팝업을 띄운 뒤에만 재검색 시작
  Future<void> declineMatching() async {

    timeoutTimer?.cancel();
    pollTimer?.cancel();

    if (matchingId != null) {

      try {

        await http.post(
          Uri.parse("${dotenv.env['PHP_URL']}gps_cancel.php"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "matching_id": matchingId,
            "user_id": widget.userId,
          }),
        );

      } catch (e) {
        // 무시
      }

    }

    matchingId = null;

    if (!mounted) return;

    await _showRestartNoticeDialog(
      title: "매칭이 거절되었습니다",
      message: "다시 매칭을 시작할게요",
    );

    if (!mounted) return;

    setState(() {
      myApproved = false;
      partnerApproved = false;
    });

    await startMatching();

  }

  // ⭐ 거절 관련 공통 안내 팝업
  Future<void> _showRestartNoticeDialog({
    required String title,
    required String message,
  }) async {

    await showDialog(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cancel_rounded,
                  color: Colors.redAccent,
                  size: 28,
                ),
              ),

              const SizedBox(height: 16),

              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "확인",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

            ],
          ),
        ),
      ),
    );

  }

  // =========================
  Future<void> approveMatching() async {

    if (matchingId == null) return;

    setState(() {
      myApproved = true;
    });

    try {

      final response = await http.post(
        Uri.parse("${dotenv.env['PHP_URL']}gps_approve.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "matching_id": matchingId,
          "user_id": widget.userId,
        }),
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (data["success"] == true && data["matched"] == true) {

        timeoutTimer?.cancel();
        pollTimer?.cancel();

        final roomId = data["room_id"];

        matchingId = null;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => ChatPage(
              roomId: roomId,
              userId: widget.userId,
            ),
          ),
          ModalRoute.withName('room'),
        );

      }
      // matched == false 인 경우 -> 계속 폴링하면서 상대 응답 대기

    } catch (e) {

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("승인 처리 중 오류가 발생했습니다")),
      );

    }

  }

  Future<void> cancelMatching() async {

    pollTimer?.cancel();
    timeoutTimer?.cancel();

    if (matchingId != null) {

      try {

        await http.post(
          Uri.parse("${dotenv.env['PHP_URL']}gps_cancel.php"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "matching_id": matchingId,
            "user_id": widget.userId,
          }),
        );

      } catch (e) {
        // 무시
      }

    }

    matchingId = null;

    if (!mounted) return;

    Navigator.pop(context);

  }

  // =========================
  @override
  Widget build(BuildContext context) {

    return WillPopScope(

      onWillPop: () async {
        await cancelMatching();
        return false;
      },

      child: Scaffold(

        backgroundColor: const Color(0xFFF7F7F9),

        appBar: AppBar(
          title: const Text(
            '실시간 매칭',
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
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: cancelMatching,
          ),
        ),

        body: SafeArea(
          child: _buildBody(),
        ),

      ),

    );

  }

  Widget _buildBody() {

    switch (stage) {

      case _MatchStage.checkingPermission:

        return Center(
          child: CircularProgressIndicator(color: primary),
        );

      case _MatchStage.permissionDenied:

        return _buildPermissionDenied();

      case _MatchStage.searching:

        return _buildSearching();

      case _MatchStage.matched:

        return _buildMatched();

      case _MatchStage.error:

        return _buildError();

    }

  }

  Widget _buildPermissionDenied() {

    return Center(

      child: Padding(

        padding: const EdgeInsets.all(32),

        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            Icon(Icons.location_off_rounded, size: 64, color: Colors.grey.shade300),

            const SizedBox(height: 16),

            const Text(
              '위치 권한이 필요합니다',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              '주변 사람과의 매칭을 위해\n위치 접근을 허용해주세요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {

                  setState(() {
                    stage = _MatchStage.checkingPermission;
                  });

                  final status = await Permission.location.request();

                  if (status.isGranted) {

                    await _getLocationAndStart();

                  } else if (status.isPermanentlyDenied) {

                    await openAppSettings();

                    if (!mounted) return;

                    setState(() {
                      stage = _MatchStage.permissionDenied;
                    });

                  } else {

                    if (!mounted) return;

                    setState(() {
                      stage = _MatchStage.permissionDenied;
                    });

                  }

                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  '권한 허용하기',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

          ],
        ),

      ),

    );

  }

  Widget _buildSearching() {

    return Column(

      children: [

        Expanded(

          child: Center(

            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                SizedBox(
                  width: 160,
                  height: 160,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [

                      AnimatedBuilder(
                        animation: pulseController,
                        builder: (context, child) {

                          final scale = 1.0 + (pulseController.value * 0.5);
                          final opacity = (1.0 - pulseController.value).clamp(0.0, 1.0);

                          return Opacity(
                            opacity: opacity,
                            child: Transform.scale(
                              scale: scale,
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: primary.withOpacity(0.15),
                                ),
                              ),
                            ),
                          );

                        },
                      ),

                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primary.withOpacity(0.12),
                        ),
                        child: Icon(
                          Icons.near_me_rounded,
                          color: primary,
                          size: 36,
                        ),
                      ),

                    ],
                  ),
                ),

                const SizedBox(height: 28),

                const Text(
                  '주변에서 찾는 중이에요',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  '1km 이내에서 "${widget.endPlace}"로\n같이 이동할 사람을 찾고 있어요',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),

              ],
            ),

          ),

        ),

        Padding(

          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),

          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: cancelMatching,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                '취소',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

        ),

      ],

    );

  }

  Widget _buildMatched() {

    return Column(

      children: [

        Expanded(

          child: Center(

            child: Padding(

              padding: const EdgeInsets.all(28),

              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.groups_rounded,
                      color: primary,
                      size: 44,
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    '매칭 상대를 찾았어요!',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    '"${widget.endPlace}"로 함께 이동할까요?',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 24),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$remainingSeconds초 안에 응답해주세요',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [

                      _StatusChip(label: "나", approved: myApproved),

                      const SizedBox(width: 16),

                      Icon(Icons.sync_alt_rounded, color: Colors.grey.shade400),

                      const SizedBox(width: 16),

                      _StatusChip(label: "상대방", approved: partnerApproved),

                    ],
                  ),

                ],
              ),

            ),

          ),

        ),

        Padding(

          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),

          child: Row(
            children: [

              Expanded(
                child: OutlinedButton(
                  onPressed: declineMatching,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    '거절',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: ElevatedButton(
                  onPressed: myApproved ? null : approveMatching,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: myApproved ? Colors.grey.shade300 : primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    myApproved ? '승인 완료' : '참여하기',
                    style: TextStyle(
                      color: myApproved ? Colors.grey.shade500 : Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

            ],
          ),

        ),

      ],

    );

  }

  Widget _buildError() {

    return Center(

      child: Padding(

        padding: const EdgeInsets.all(32),

        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            Icon(Icons.error_outline_rounded, size: 64, color: Colors.grey.shade300),

            const SizedBox(height: 16),

            const Text(
              '문제가 발생했습니다',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              '잠시 후 다시 시도해주세요',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {

                  setState(() {
                    stage = _MatchStage.checkingPermission;
                  });

                  checkLocationPermission();

                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  '다시 시도',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

          ],
        ),

      ),

    );

  }

}

class _StatusChip extends StatelessWidget {

  final String label;

  final bool approved;

  const _StatusChip({
    required this.label,
    required this.approved,
  });

  @override
  Widget build(BuildContext context) {

    return Column(
      children: [

        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: approved
                ? Colors.green.withOpacity(0.12)
                : Colors.grey.shade100,
          ),
          child: Icon(
            approved ? Icons.check_circle_rounded : Icons.hourglass_empty_rounded,
            color: approved ? Colors.green : Colors.grey.shade400,
            size: 24,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),

      ],
    );

  }

}