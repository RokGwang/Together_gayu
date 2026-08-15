import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'login.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../tab_widget/tab_controller.dart';

class WithdrawPage extends StatefulWidget {

  final int userId;

  const WithdrawPage({
    super.key,
    required this.userId,
  });

  @override
  State<WithdrawPage> createState() => _WithdrawPageState();
}

class _WithdrawPageState extends State<WithdrawPage> {

  static const Color primary = Color(0xFFFF7A00);

  bool checked = false;
  bool isLoading = false;

  final String serverUrl = "${dotenv.env['PHP_URL']}withdraw_user.php";

  Future<void> withdraw() async {

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
                  color: Colors.redAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.redAccent,
                  size: 28,
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                "정말 탈퇴하시겠습니까?",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                "탈퇴 시 계정 정보는 복구할 수 없습니다",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
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
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        "탈퇴",
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

    setState(() => isLoading = true);

    try {

      final response = await http.post(
        Uri.parse(serverUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"user_id": widget.userId}),
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (data["success"] == true) {

        AppTabController.reset(); // ⭐ 탭 상태 초기화 (import 필요: '../tab_widget/tab_controller.dart')

        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil( // ⭐ rootNavigator: true 추가
          MaterialPageRoute(builder: (_) => const LoginPage()),
              (route) => false,
        );

      } else {

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data["message"] ?? "탈퇴 처리에 실패했습니다")),
        );

      }

    } catch (e) {

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("에러 발생: $e")),
      );

    } finally {

      if (!mounted) return;

      setState(() => isLoading = false);

    }

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0xFFF7F7F9),

      appBar: AppBar(
        title: const Text(
          '회원 탈퇴',
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

      body: SafeArea(

        child: Padding(

          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_remove_alt_1_rounded,
                  color: Colors.redAccent,
                  size: 30,
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                '정말 떠나시나요?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                '회원 탈퇴 시 아래 내용이 함께 처리됩니다',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 20),

              Container(

                width: double.infinity,

                padding: const EdgeInsets.all(18),

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

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [

                    _WithdrawInfoRow(text: "이메일, 닉네임 등 개인정보가 삭제됩니다"),
                    SizedBox(height: 12),
                    _WithdrawInfoRow(text: "방장으로 있는 채팅방은 모두 삭제됩니다"),
                    SizedBox(height: 12),
                    _WithdrawInfoRow(text: "참여중인 채팅방에서는 자동으로 나가집니다"),
                    SizedBox(height: 12),
                    _WithdrawInfoRow(text: "삭제된 계정 정보는 복구할 수 없습니다"),

                  ],
                ),

              ),

              const SizedBox(height: 20),

              InkWell(

                onTap: () {
                  setState(() => checked = !checked);
                },

                borderRadius: BorderRadius.circular(10),

                child: Row(
                  children: [

                    Icon(
                      checked ? Icons.check_circle_rounded : Icons.check_circle_outline_rounded,
                      color: checked ? primary : Colors.grey.shade400,
                      size: 22,
                    ),

                    const SizedBox(width: 8),

                    const Expanded(
                      child: Text(
                        '위 내용을 모두 확인했으며 이에 동의합니다',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                      ),
                    ),

                  ],
                ),

              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (!checked || isLoading) ? null : withdraw,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (!checked || isLoading) ? Colors.grey.shade300 : Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
                  )
                      : Text(
                    '회원 탈퇴',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: (!checked) ? Colors.grey.shade500 : Colors.white,
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
}

class _WithdrawInfoRow extends StatelessWidget {

  final String text;

  const _WithdrawInfoRow({required this.text});

  @override
  Widget build(BuildContext context) {

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        Icon(Icons.circle, size: 5, color: Colors.grey.shade400),

        const SizedBox(width: 8),

        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
          ),
        ),

      ],
    );

  }

}