import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../tab_widget/widget.dart';
import 'withdraw.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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

                  ],
                ),

              ),

              const Spacer(),

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