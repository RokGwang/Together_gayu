import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart'; // import 필수
import 'package:shared_preferences/shared_preferences.dart'; // ⭐ 추가
import 'user/login.dart';
import 'socket_service.dart';
import 'tab_widget/main_shell.dart'; // ⭐ 추가
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // .env 파일 로드
  await dotenv.load(fileName: ".env");
  SocketService.instance.connect();
  // 앱 실행 전 SDK 초기화 필수 (이 부분이 빠지면 오류 발생)
  KakaoSdk.init(
    nativeAppKey: dotenv.env['kakao'] ?? '',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '같이가유',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        scaffoldBackgroundColor: const Color(0xFFF7F7F9),
      ),
      home: const AuthGate(), // ⭐ LoginPage -> AuthGate로 변경
    );
  }
}

// ⭐ 신규: 저장된 로그인 정보 확인 후 자동 로그인 여부를 분기하는 게이트
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {

  @override
  void initState() {
    super.initState();
    _checkVersionThenProceed();
  }

  // ⭐ 추가: 버전 체크를 가장 먼저 수행. 낮으면 여기서 완전히 멈춤
  Future<void> _checkVersionThenProceed() async {

    try {

      final packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = packageInfo.version; // 예: "1.0.0"

      final response = await http.get(
        Uri.parse("${dotenv.env['PHP_URL']}version_check.php"),
      ).timeout(const Duration(seconds: 5));

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (data["success"] == true) {

        final String minVersion = (data["min_version"] ?? "0.0.0").toString();
        final String storeUrl = (data["store_url"] ?? "").toString();

        if (_isVersionLower(currentVersion, minVersion)) {

          _showForceUpdateDialog(storeUrl);

          return; // ⭐ 여기서 완전히 멈춤 (점검 체크로도 넘어가지 않음)

        }

      }

    } catch (e) {
      // ⭐ 버전 체크 자체가 실패하면(네트워크 오류 등) 일단 정상 진행
    }

    if (!mounted) return;

    _checkInspectionThenProceed();

  }

  // ⭐ 추가: 간단한 버전 문자열 비교 (예: "1.0.1" vs "1.0.0")
  bool _isVersionLower(String current, String minRequired) {

    List<int> parse(String v) {
      return v.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    }

    final cur = parse(current);
    final min = parse(minRequired);

    final int maxLength = cur.length > min.length ? cur.length : min.length;

    for (int i = 0; i < maxLength; i++) {

      final int c = i < cur.length ? cur[i] : 0;
      final int m = i < min.length ? min[i] : 0;

      if (c < m) return true;
      if (c > m) return false;

    }

    return false; // 완전히 같으면 낮은 게 아님

  }

  // ⭐ 추가: 강제 업데이트 팝업 (닫을 수 없음)
  void _showForceUpdateDialog(String storeUrl) {

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
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
                    color: const Color(0xFFFF7A00).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.system_update_rounded,
                    color: Color(0xFFFF7A00),
                    size: 28,
                  ),
                ),

                const SizedBox(height: 16),

                const Text(
                  "업데이트가 필요해요",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  "원활한 서비스를 위해 최신 버전으로\n업데이트가 필요합니다",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7A00),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () async {

                      if (storeUrl.isNotEmpty) {

                        final uri = Uri.tryParse(storeUrl);

                        if (uri != null) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }

                      }

                    },
                    child: const Text(
                      "업데이트하기",
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
      ),
    );

  }

  // ⭐ 점검 체크 (기존 로직 유지)
  Future<void> _checkInspectionThenProceed() async {

    try {

      final response = await http.get(
        Uri.parse("${dotenv.env['PHP_URL']}inspection.php"),
      ).timeout(const Duration(seconds: 5));

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (data["success"] == true && data["isInspecting"] == true) {

        _showInspectionDialog(
          start: data["start"] ?? "",
          deadline: data["deadline"] ?? "",
          text: data["text"] ?? "",
        );

        return;

      }

    } catch (e) {
      // 무시하고 정상 진행
    }

    if (!mounted) return;

    _checkAutoLogin();

  }

  void _showInspectionDialog({
    required String start,
    required String deadline,
    required String text,
  }) {

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
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
                    color: const Color(0xFFFF7A00).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.build_rounded,
                    color: Color(0xFFFF7A00),
                    size: 28,
                  ),
                ),

                const SizedBox(height: 16),

                const Text(
                  "서비스 점검중입니다",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 12),

                if (start.isNotEmpty || deadline.isNotEmpty)
                  Text(
                    "$start ~ $deadline",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFF7A00),
                    ),
                  ),

                const SizedBox(height: 8),

                if (text.isNotEmpty)
                  Text(
                    text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      height: 1.4,
                    ),
                  ),

              ],
            ),
          ),
        ),
      ),
    );

  }

  Future<void> _checkAutoLogin() async {

    final prefs = await SharedPreferences.getInstance();

    final int? savedUserId = prefs.getInt('user_id');

    if (!mounted) return;

    if (savedUserId != null) {

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => MainShell(userId: savedUserId)),
      );

    } else {

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );

    }

  }

  @override
  Widget build(BuildContext context) {

    return const Scaffold(
      backgroundColor: Color(0xFFF7F7F9),
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFFFF7A00)),
      ),
    );

  }

}