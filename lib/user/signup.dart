import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {

  static const Color primary = Color(0xFFFF7A00);

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nicknameController = TextEditingController();

  bool obscurePassword = true;
  bool isLoading = false;

  bool termsAgreed = false;
  bool privacyAgreed = false;
  bool marketingAgreed = false;

  final String serverUrl = "${dotenv.env['PHP_URL']}signup.php";

  bool get allRequiredAgreed => termsAgreed && privacyAgreed;

  bool get allAgreed => termsAgreed && privacyAgreed && marketingAgreed;

  void toggleAll(bool value) {

    setState(() {
      termsAgreed = value;
      privacyAgreed = value;
      marketingAgreed = value;
    });

  }

  Future<void> signup() async {

    if (emailController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty ||
        nicknameController.text.trim().isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("모든 항목을 입력해주세요")),
      );

      return;

    }

    setState(() => isLoading = true);

    try {

      final response = await http.post(
        Uri.parse(serverUrl),
        body: {
          "email": emailController.text.trim(),
          "password": passwordController.text.trim(),
          "name": nicknameController.text.trim(),
          "terms_agreed": termsAgreed ? "1" : "0",
          "privacy_agreed": privacyAgreed ? "1" : "0",
          "marketing_agreed": marketingAgreed ? "1" : "0",
        },
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (data["success"] == true) {

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("회원가입 성공")),
        );

        Navigator.pop(context);

      } else {

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data["message"] ?? "회원가입에 실패했습니다")),
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

  void showTermsDialog(String title, String content) {

    showDialog(
      context: context,
      useRootNavigator: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                child: SingleChildScrollView(
                  child: Text(
                    content,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("확인", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0xFFF7F7F9),

      appBar: AppBar(
        title: const Text(
          '회원가입',
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

        child: SingleChildScrollView(

          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.center,

            children: [

              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_add_alt_1_rounded,
                  size: 38,
                  color: primary,
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                '같이가유',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                '새로운 여행 메이트를 만나보세요',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 32),

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
                  children: [

                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: '이메일',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                        prefixIcon: Icon(Icons.email_outlined, color: Colors.grey.shade400, size: 20),
                        filled: true,
                        fillColor: const Color(0xFFF7F7F9),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: nicknameController,
                      decoration: InputDecoration(
                        hintText: '닉네임',
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

                    const SizedBox(height: 12),

                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        hintText: '비밀번호',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                        prefixIcon: Icon(Icons.lock_outline, color: Colors.grey.shade400, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            color: Colors.grey.shade400,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF7F7F9),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ===== 약관 동의 영역 =====
                    Container(

                      padding: const EdgeInsets.all(14),

                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F9),
                        borderRadius: BorderRadius.circular(14),
                      ),

                      child: Column(
                        children: [

                          InkWell(
                            onTap: () => toggleAll(!allAgreed),
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Icon(
                                    allAgreed ? Icons.check_circle_rounded : Icons.check_circle_outline_rounded,
                                    color: allAgreed ? primary : Colors.grey.shade400,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    '약관 전체 동의',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const Divider(height: 20),

                          _AgreementRow(
                            label: '[필수] 이용약관 동의',
                            value: termsAgreed,
                            color: primary,
                            onChanged: (v) => setState(() => termsAgreed = v),
                            onView: () => showTermsDialog(
                              '이용약관',
                              '같이가유 서비스 이용약관 내용이 여기에 표시됩니다.\n\n실제 서비스 출시 전 정식 약관 문구로 교체해주세요.',
                            ),
                          ),

                          const SizedBox(height: 6),

                          _AgreementRow(
                            label: '[필수] 개인정보 수집·이용 동의',
                            value: privacyAgreed,
                            color: primary,
                            onChanged: (v) => setState(() => privacyAgreed = v),
                            onView: () => showTermsDialog(
                              '개인정보 수집·이용 동의',
                              '수집 항목: 이메일, 닉네임, 위치정보(매칭 시)\n'
                                  '수집 목적: 회원 식별, 서비스 제공, 채팅방 매칭\n'
                                  '보유 기간: 회원 탈퇴 시까지\n\n'
                                  '실제 서비스 출시 전 정식 개인정보처리방침으로 교체해주세요.',
                            ),
                          ),

                          const SizedBox(height: 6),

                          _AgreementRow(
                            label: '[선택] 마케팅 정보 수신 동의',
                            value: marketingAgreed,
                            color: primary,
                            onChanged: (v) => setState(() => marketingAgreed = v),
                            onView: () => showTermsDialog(
                              '마케팅 정보 수신 동의',
                              '이벤트, 혜택 정보를 이메일/알림으로 받아보실 수 있습니다.\n'
                                  '동의하지 않아도 서비스 이용에는 제한이 없습니다.',
                            ),
                          ),

                        ],
                      ),

                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (isLoading || !allRequiredAgreed) ? null : signup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: allRequiredAgreed ? primary : Colors.grey.shade300,
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
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.4,
                          ),
                        )
                            : Text(
                          '회원가입',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: allRequiredAgreed ? Colors.white : Colors.grey.shade500,
                          ),
                        ),
                      ),
                    ),

                  ],
                ),

              ),

              const SizedBox(height: 20),

              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text(
                  '이미 계정이 있으신가요? 로그인',
                  style: TextStyle(
                    color: primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
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

class _AgreementRow extends StatelessWidget {

  final String label;
  final bool value;
  final Color color;
  final ValueChanged<bool> onChanged;
  final VoidCallback onView;

  const _AgreementRow({
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {

    return Row(
      children: [

        Expanded(
          child: InkWell(
            onTap: () => onChanged(!value),
            borderRadius: BorderRadius.circular(10),
            child: Row(
              children: [
                Icon(
                  value ? Icons.check_circle_rounded : Icons.check_circle_outline_rounded,
                  color: value ? color : Colors.grey.shade400,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ),

        TextButton(
          onPressed: onView,
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6)),
          child: Text(
            '보기',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400, decoration: TextDecoration.underline),
          ),
        ),

      ],
    );

  }

}