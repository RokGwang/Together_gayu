import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ChangePasswordPage extends StatefulWidget {

  final int userId;

  const ChangePasswordPage({super.key, required this.userId});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {

  static const Color primary = Color(0xFFFF7A00);

  final TextEditingController currentController = TextEditingController();
  final TextEditingController newController = TextEditingController();
  final TextEditingController confirmController = TextEditingController();

  bool obscureCurrent = true;
  bool obscureNew = true;
  bool obscureConfirm = true;
  bool isSaving = false;

  @override
  void dispose() {
    currentController.dispose();
    newController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  Future<void> changePassword() async {

    final current = currentController.text.trim();
    final newPw = newController.text.trim();
    final confirm = confirmController.text.trim();

    if (current.isEmpty || newPw.isEmpty || confirm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("모든 항목을 입력해주세요")),
      );
      return;
    }

    if (newPw.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("새 비밀번호는 6자 이상이어야 합니다")),
      );
      return;
    }

    if (newPw != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("새 비밀번호가 일치하지 않습니다")),
      );
      return;
    }

    setState(() => isSaving = true);

    try {

      final response = await http.post(
        Uri.parse("${dotenv.env['PHP_URL']}user_changePW.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": widget.userId,
          "current_password": current,
          "new_password": newPw,
        }),
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (data["success"] == true) {

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("비밀번호가 변경되었습니다")),
        );

        Navigator.pop(context);

      } else {

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data["message"] ?? "변경에 실패했습니다")),
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

  Widget _passwordField({
    required String label,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggle,
  }) {

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87)),

        const SizedBox(height: 8),

        TextField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(
            hintText: label,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: Icon(Icons.lock_outline, color: Colors.grey.shade400, size: 20),
            suffixIcon: IconButton(
              icon: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.grey.shade400, size: 20),
              onPressed: onToggle,
            ),
            filled: true,
            fillColor: const Color(0xFFF7F7F9),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),

      ],
    );

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      appBar: AppBar(
        title: const Text('비밀번호 변경', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87, fontSize: 18)),
        backgroundColor: const Color(0xFFF7F7F9),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SafeArea(
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
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 6))],
                ),

                child: Column(
                  children: [

                    _passwordField(
                      label: '현재 비밀번호',
                      controller: currentController,
                      obscure: obscureCurrent,
                      onToggle: () => setState(() => obscureCurrent = !obscureCurrent),
                    ),

                    const SizedBox(height: 16),

                    _passwordField(
                      label: '새 비밀번호',
                      controller: newController,
                      obscure: obscureNew,
                      onToggle: () => setState(() => obscureNew = !obscureNew),
                    ),

                    const SizedBox(height: 16),

                    _passwordField(
                      label: '새 비밀번호 확인',
                      controller: confirmController,
                      obscure: obscureConfirm,
                      onToggle: () => setState(() => obscureConfirm = !obscureConfirm),
                    ),

                  ],
                ),

              ),

              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: isSaving ? null : changePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4))
                    : const Text('변경하기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
              ),

            ],
          ),
        ),
      ),
    );

  }

}