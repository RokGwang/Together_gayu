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

  bool? isEmailAvailable; // null=확인 안 함, true=사용 가능, false=중복
  bool isCheckingEmail = false;
  String? lastCheckedEmail; // 마지막으로 확인한 이메일 (재입력 시 재확인 유도)

  final String serverUrl = "${dotenv.env['PHP_URL']}user_signup.php";

  bool get allRequiredAgreed => termsAgreed && privacyAgreed;

  bool get allAgreed => termsAgreed && privacyAgreed && marketingAgreed;

  void toggleAll(bool value) {

    setState(() {
      termsAgreed = value;
      privacyAgreed = value;
      marketingAgreed = value;
    });

  }
  Future<void> checkEmailDuplicate() async {

    final email = emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("이메일을 입력해주세요")),
      );
      return;
    }

    // 간단한 형식 검증
    final emailRegex = RegExp(r'^[\w\.\-]+@[\w\-]+\.[\w\-\.]+$');

    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("올바른 이메일 형식이 아닙니다")),
      );
      return;
    }

    setState(() => isCheckingEmail = true);

    try {

      final url = '${dotenv.env['PHP_URL']}check_duplicate.php?email=${Uri.encodeComponent(email)}';

      final response = await http.get(Uri.parse(url));

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (data["success"] == true) {

        setState(() {
          isEmailAvailable = data["available"] == true;
          lastCheckedEmail = email;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data["message"] ?? "")),
        );

      } else {

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data["message"] ?? "중복 확인에 실패했습니다")),
        );

      }

    } catch (e) {

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("에러 발생: $e")),
      );

    } finally {

      if (!mounted) return;

      setState(() => isCheckingEmail = false);

    }

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

    // ⭐ 이메일 중복확인을 안 했거나, 확인 후 이메일을 다시 수정한 경우 재확인 요구
    final currentEmail = emailController.text.trim();

    if (isEmailAvailable != true || lastCheckedEmail != currentEmail) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("이메일 중복확인을 해주세요")),
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
                      onChanged: (_) {
                        // ⭐ 이메일을 다시 수정하면 중복확인 결과를 초기화
                        if (isEmailAvailable != null) {
                          setState(() => isEmailAvailable = null);
                        }
                      },
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: isEmailAvailable == null
                              ? const SizedBox.shrink()
                              : Row(
                            children: [
                              Icon(
                                isEmailAvailable! ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                size: 14,
                                color: isEmailAvailable! ? Colors.green : Colors.redAccent,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isEmailAvailable! ? "사용 가능한 이메일이에요" : "이미 사용 중인 이메일이에요",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isEmailAvailable! ? Colors.green : Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 32,
                          child: OutlinedButton(
                            onPressed: isCheckingEmail ? null : checkEmailDuplicate,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              side: BorderSide(color: primary.withOpacity(0.4)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: isCheckingEmail
                                ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: primary),
                            )
                                : Text(
                              "중복확인",
                              style: TextStyle(fontSize: 12, color: primary, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
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
                              '제1조(목적)\n'
                                  '이 약관은 같이가유(이하 "회사")가 제공하는 교통비·식비 정산 채팅 서비스(이하 "서비스")의 이용과 관련하여 '
                                  '회사와 이용자의 권리, 의무 및 책임사항을 규정함을 목적으로 합니다.\n\n'
                                  '제2조(용어의 정의)\n'
                                  '① "회원"이란 이 약관에 동의하고 서비스에 가입한 자를 말합니다.\n'
                                  '② "채팅방"이란 회원 간 목적지가 같은 이동·식사 비용을 함께 정산하기 위해 개설하는 대화 공간을 말합니다.\n\n'
                                  '제3조(서비스의 제공 및 변경)\n'
                                  '회사는 관광지 이동·식사 정보 제공, 채팅, 정산 요청 등의 기능을 제공하며, 운영상 필요에 따라 서비스의 전부 또는 '
                                  '일부를 변경하거나 중단할 수 있습니다.\n\n'
                                  '제4조(회원의 의무)\n'
                                  '회원은 관계 법령, 이 약관의 규정, 이용안내 및 서비스와 관련하여 공지한 사항을 준수하여야 하며, 타인의 정보를 '
                                  '도용하거나 서비스를 부정한 목적으로 이용해서는 안 됩니다.\n\n'
                                  '제5조(계약해지 및 이용제한)\n'
                                  '회원은 언제든지 회원 탈퇴를 요청할 수 있으며, 회사는 회원이 약관을 위반한 경우 서비스 이용을 제한하거나 '
                                  '이용계약을 해지할 수 있습니다.\n\n'
                                  '제6조(면책조항)\n'
                                  '회사는 회원 간 발생한 금전 거래(정산·송금)의 당사자가 아니며, 회원 간 정산 과정에서 발생한 분쟁에 대해 '
                                  '직접적인 책임을 지지 않습니다. 회원은 정산 정보를 스스로 확인하고 신중히 거래해야 합니다.\n\n'
                                  '부칙\n'
                                  '이 약관은 2026년 1월 1일부터 적용됩니다.',
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
                              '회사는 서비스 제공을 위해 아래와 같이 개인정보를 수집·이용합니다.\n\n'
                                  '1. 수집 항목\n'
                                  '- 필수: 이메일(또는 카카오 계정 식별값), 비밀번호, 닉네임\n'
                                  '- 선택: 계좌번호(정산 기능 이용 시), 위치정보(실시간 매칭 이용 시)\n'
                                  '- 자동 수집: 서비스 이용 기록, 기기정보, 접속 로그\n\n'
                                  '2. 수집 목적\n'
                                  '- 회원 식별 및 본인 확인\n'
                                  '- 채팅방 생성·참여, 실시간 매칭, 정산 요청 등 서비스 제공\n'
                                  '- 부정 이용 방지 및 고객 문의 대응\n\n'
                                  '3. 보유 및 이용 기간\n'
                                  '회원 탈퇴 시까지 보관하며, 탈퇴 즉시 파기합니다. 다만 관계 법령에 따라 보존이 필요한 정보는 해당 기간 동안 '
                                  '별도 보관 후 파기합니다.\n\n'
                                  '4. 동의 거부 권리\n'
                                  '이용자는 개인정보 수집·이용에 대한 동의를 거부할 권리가 있으며, 필수 항목에 동의하지 않을 경우 회원가입이 '
                                  '제한될 수 있습니다.\n\n'
                                  '5. 위치정보 관련 별도 안내\n'
                                  '실시간 매칭 기능 이용 시에만 위치정보를 일시적으로 수집하며, 매칭 완료 또는 취소 즉시 파기합니다.',
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
                              '회사는 이벤트, 혜택, 서비스 업데이트 소식을 이메일 또는 앱 내 알림으로 안내할 수 있습니다.\n\n'
                                  '이 동의는 선택 사항이며, 동의하지 않아도 서비스 이용에 제한이 없습니다. 동의 후에도 언제든지 회원정보 '
                                  '수정 화면 또는 수신 거부 절차를 통해 동의를 철회할 수 있습니다.',
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