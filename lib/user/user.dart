import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../tab_widget/widget.dart';
import 'withdraw.dart';
import 'user_update.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../main.dart';
import 'login.dart';
import '../tab_widget/tab_controller.dart';

class UserPage extends StatefulWidget {

  final int userId;

  const UserPage({
    super.key,
    required this.userId,
  });

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {

  static const Color primary = Color(0xFFFF7A00);

  bool loading = true;

  String name = "";

  int id = 0;

  @override
  void initState() {

    super.initState();

    loadUser();

  }

  Future<void> loadUser() async {

    setState(() {
      loading = true;
    });

    try {

      final response = await http.get(
        Uri.parse(
          "${dotenv.env['PHP_URL']}user.php"
              "?user_id=${widget.userId}",
        ),
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (data["success"]) {

        setState(() {

          name = data["user"]["name"];

          id = int.parse(data["user"]["id"].toString());

          loading = false;

        });

      } else {

        setState(() {
          loading = false;
        });

      }

    } catch (e) {

      if (!mounted) return;

      setState(() {
        loading = false;
      });

    }

  }

  Future<void> goToUpdatePage() async {

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserUpdatePage(userId: widget.userId),
      ),
    );

    // ⭐ user_update.dart에서 저장 성공(true) 신호를 받으면 새로고침
    if (result == true) {

      loadUser();

    }

  }

  Future<void> showLogoutDialog() async {

    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
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
                  color: primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.logout_rounded,
                  color: primary,
                  size: 28,
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                "로그아웃 하시겠습니까?",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 24),

              Row(
                children: [

                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text(
                        "취소",
                        style: TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        "로그아웃",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),

                ],
              ),

            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    AppTabController.reset(); // ⭐ 탭 상태 초기화

    if (!mounted) return;

    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil( // ⭐ rootNavigator: true 추가
      MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
    );

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0xFFF7F7F9),

      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          "내 정보",
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
      ),

      body: loading

          ? Center(
        child: CircularProgressIndicator(color: primary),
      )

          : SafeArea(

        child: Padding(

          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.stretch,

            children: [

              Container(

                padding: const EdgeInsets.symmetric(vertical: 28),

                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),

                child: Column(
                  children: [

                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: primary.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person_rounded,
                        color: primary,
                        size: 48,
                      ),
                    ),

                    const SizedBox(height: 18),

                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      "ID $id",
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ⭐ 회원정보 수정 버튼
                    TextButton.icon(
                      onPressed: goToUpdatePage,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        backgroundColor: primary.withOpacity(0.08),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      icon: Icon(Icons.edit_rounded, size: 16, color: primary),
                      label: Text(
                        '회원정보 수정',
                        style: TextStyle(color: primary, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),

                  ],
                ),

              ),

              const Spacer(),

              // ⭐ 로그아웃 버튼
              Center(
                child: TextButton(
                  onPressed: showLogoutDialog,
                  child: Text(
                    '로그아웃',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 4),

              Center(
                child: TextButton(
                  onPressed: () {

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WithdrawPage(userId: widget.userId),
                      ),
                    );

                  },
                  child: Text(
                    '회원 탈퇴',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),

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