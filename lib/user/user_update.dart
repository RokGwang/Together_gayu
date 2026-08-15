import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class UserUpdatePage extends StatefulWidget {

  final int userId;

  const UserUpdatePage({
    super.key,
    required this.userId,
  });

  @override
  State<UserUpdatePage> createState() => _UserUpdatePageState();
}

class _UserUpdatePageState extends State<UserUpdatePage> {

  static const Color primary = Color(0xFFFF7A00);

  final TextEditingController nameController = TextEditingController();

  bool isLoading = true;
  bool isSaving = false;

  @override
  void initState() {

    super.initState();

    loadName();

  }

  @override
  void dispose() {

    nameController.dispose();

    super.dispose();

  }

  Future<void> loadName() async {

    try {

      final response = await http.get(
        Uri.parse(
          "${dotenv.env['PHP_URL']}user_update.php"
              "?user_id=${widget.userId}",
        ),
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (data["success"] == true) {

        setState(() {
          nameController.text = data["name"] ?? "";
          isLoading = false;
        });

      } else {

        setState(() {
          isLoading = false;
        });

      }

    } catch (e) {

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

    }

  }

  Future<void> saveName() async {

    final newName = nameController.text.trim();

    if (newName.isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("닉네임을 입력해주세요")),
      );

      return;

    }

    setState(() => isSaving = true);

    try {

      final response = await http.post(
        Uri.parse("${dotenv.env['PHP_URL']}user_update.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": widget.userId,
          "name": newName,
        }),
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (data["success"] == true) {

        // ⭐ 변경 완료 신호(true)를 들고 이전 화면(user.dart)으로 복귀
        Navigator.pop(context, true);

      } else {

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data["message"] ?? "수정에 실패했습니다")),
        );

      }

    } catch (e) {

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("에러 발생: $e")),
      );

    } finally {

      if (!mounted) return;

      setState(() => isSaving = false);

    }

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0xFFF7F7F9),

      appBar: AppBar(
        title: const Text(
          '회원정보 수정',
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

      body: isLoading

          ? Center(child: CircularProgressIndicator(color: primary))

          : SafeArea(

        child: Padding(

          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.stretch,

            children: [

              Container(

                padding: const EdgeInsets.all(20),

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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    const Text(
                      '닉네임',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 10),

                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        hintText: '닉네임을 입력하세요',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                        prefixIcon: Icon(Icons.person_outline, color: Colors.grey.shade400, size: 20),
                        filled: true,
                        fillColor: const Color(0xFFF7F7F9),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                  ],
                ),

              ),

              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: isSaving ? null : saveName,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: isSaving
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
                )
                    : const Text(
                  '저장하기',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),

            ],

          ),

        ),

      ),

    );
  }
}