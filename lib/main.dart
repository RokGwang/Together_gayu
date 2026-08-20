import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart'; // import 필수
import 'package:shared_preferences/shared_preferences.dart'; // ⭐ 추가
import 'user/login.dart';
import 'socket_service.dart';
import 'tab_widget/main_shell.dart'; // ⭐ 추가

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // .env 파일 로드
  await dotenv.load(fileName: ".env");
  SocketService.instance.connect();
  // 앱 실행 전 SDK 초기화 필수 (이 부분이 빠지면 오류 발생)
  /*KakaoSdk.init(
    nativeAppKey: dotenv.env['kakao'] ?? '',
  );*/
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
    _checkAutoLogin();
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