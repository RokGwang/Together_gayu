import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart'; // import 필수
import 'user/login.dart';
import 'socket_service.dart';

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
      home: const LoginPage(),
    );
  }
}