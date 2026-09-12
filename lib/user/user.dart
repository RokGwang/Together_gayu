import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../tab_widget/widget.dart';
import 'user_withdraw.dart';
import 'user_update.dart';
import 'user_changePW.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'login.dart';
import '../tab_widget/tab_controller.dart';

class UserPage extends StatefulWidget {
  final int userId;
  const UserPage({super.key, required this.userId});
  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  static const Color primary = Color(0xFFFF7A00);
  bool loading = true;
  String name = "";
  bool pushEnabled = true;

  @override
  void initState() {
    super.initState();
    loadUser();
    _loadPushSetting();
  }

  Future<void> loadUser() async {
    setState(() => loading = true);
    try {
      final response = await http.get(
        Uri.parse("${dotenv.env['PHP_URL']}user.php?user_id=${widget.userId}"),
      );
      final data = jsonDecode(response.body);
      if (!mounted) return;
      if (data["success"]) {
        setState(() {
          name = data["user"]["name"];
          loading = false;
        });
      } else {
        setState(() => loading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  Future<void> _loadPushSetting() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      pushEnabled = prefs.getBool('push_notifications_enabled') ?? true;
    });
  }

  Future<void> _togglePush(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('push_notifications_enabled', value);
    setState(() => pushEnabled = value);
  }

  Future<void> goToUpdatePage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserUpdatePage(userId: widget.userId)),
    );
    if (result == true) {
      loadUser();
    }
  }

  void _openInquiryDialog() {
    showDialog(
      context: context,
      useRootNavigator: false,
      builder: (_) => _InquiryDialogContent(
        primary: primary,
        userId: widget.userId,
      ),
    );
  }

  void _showPolicyDialog(String title, String content) {
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
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87)),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
                child: SingleChildScrollView(
                  child: Text(content, style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.6)),
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

  Future<void> showLogoutDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(color: primary.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.logout_rounded, color: primary, size: 28),
              ),
              const SizedBox(height: 16),
              const Text("로그아웃 하시겠습니까?", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.black87)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text("취소", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text("로그아웃", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');

    AppTabController.reset();

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade400)),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String label,
    String? trailingText,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey.shade600),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
            ),
            if (trailing != null)
              trailing
            else if (trailingText != null)
              Text(trailingText, style: TextStyle(fontSize: 12, color: Colors.grey.shade400))
            else
              Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey.shade300),
          ],
        ),
      ),
    );
  }

  Widget _menuCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: List.generate(children.length * 2 - 1, (i) {
          if (i.isEven) return children[i ~/ 2];
          return Divider(height: 1, color: Colors.grey.shade100);
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("내 정보", style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87, fontSize: 18)),
        centerTitle: false,
        backgroundColor: const Color(0xFFF7F7F9),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: loading
          ? Center(child: CircularProgressIndicator(color: primary))
          : SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // ===== 프로필 카드 (ID 표시 없음) =====
              Container(
                padding: const EdgeInsets.symmetric(vertical: 28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 96, height: 96,
                      decoration: BoxDecoration(color: primary.withOpacity(0.12), shape: BoxShape.circle),
                      child: Icon(Icons.person_rounded, color: primary, size: 48),
                    ),
                    const SizedBox(height: 18),
                    Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.black87)),
                  ],
                ),
              ),

              // ===== 계정 =====
              _sectionLabel("계정"),
              _menuCard([
                _menuTile(icon: Icons.edit_rounded, label: "회원정보 수정", onTap: goToUpdatePage),
                _menuTile(
                  icon: Icons.lock_outline_rounded,
                  label: "비밀번호 변경",
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChangePasswordPage(userId: widget.userId))),
                ),
              ]),

              // ===== 약관 및 정책 =====
              _sectionLabel("약관 및 정책"),
              _menuCard([
                _menuTile(
                  icon: Icons.description_outlined,
                  label: "이용약관",
                  onTap: () => _showPolicyDialog(
                    "이용약관",
                    "제1조(목적)\n이 약관은 같이가유(이하 \"회사\")가 제공하는 서비스의 이용조건 및 절차, 회사와 이용자의 권리·의무 및 책임사항을 규정함을 목적으로 합니다.\n\n"
                        "제2조(회원의 의무)\n회원은 관계 법령과 이 약관을 준수하여야 하며, 타인의 정보를 도용하거나 서비스를 부정한 목적으로 이용해서는 안 됩니다.\n\n"
                        "제3조(면책조항)\n회사는 회원 간 정산·거래의 당사자가 아니며, 회원 간 발생한 분쟁에 대해 직접적인 책임을 지지 않습니다.",
                  ),
                ),
                _menuTile(
                  icon: Icons.privacy_tip_outlined,
                  label: "개인정보처리방침",
                  onTap: () => _showPolicyDialog(
                    "개인정보처리방침",
                    "1. 수집 항목: 이메일(또는 카카오 식별값), 닉네임, 계좌번호(선택), 위치정보(매칭 이용 시)\n\n"
                        "2. 수집 목적: 회원 식별, 채팅·정산·매칭 서비스 제공\n\n"
                        "3. 보유 기간: 회원 탈퇴 시까지 보관 후 즉시 파기\n\n"
                        "4. 위치정보: 실시간 매칭 이용 시에만 일시적으로 수집하며, 매칭 종료 즉시 파기합니다.",
                  ),
                ),
                _menuTile(icon: Icons.mail_outline_rounded, label: "문의하기", onTap: _openInquiryDialog),
                _menuTile(icon: Icons.info_outline_rounded, label: "앱 버전", trailingText: "1.0.0", onTap: null),
              ]),

              _sectionLabel("놀거리"),
              _menuCard([
                _menuTile(
                  icon: Icons.notifications_none_rounded,
                  label: "또각이",
                  trailing: Switch(
                    value: pushEnabled,
                    activeColor: primary,
                    onChanged: _togglePush,
                  ),
                ),
              ]),

              const SizedBox(height: 28),

              Center(
                child: TextButton(
                  onPressed: showLogoutDialog,
                  child: Text(
                    '로그아웃',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w600, decoration: TextDecoration.underline),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => WithdrawPage(userId: widget.userId)));
                  },
                  child: Text(
                    '회원 탈퇴',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 13, fontWeight: FontWeight.w600, decoration: TextDecoration.underline),
                  ),
                ),
              ),

            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomWidget(userId: widget.userId),
    );
  }
}
enum _InquiryStep { input, confirm, submitted }

class _InquiryDialogContent extends StatefulWidget {

  final Color primary;
  final int userId;

  const _InquiryDialogContent({
    required this.primary,
    required this.userId,
  });

  @override
  State<_InquiryDialogContent> createState() => _InquiryDialogContentState();

}

class _InquiryDialogContentState extends State<_InquiryDialogContent> {

  _InquiryStep step = _InquiryStep.input;

  final TextEditingController contentController = TextEditingController();

  bool isSubmitting = false;

  @override
  void dispose() {
    contentController.dispose();
    super.dispose();
  }

  bool get canProceed => contentController.text.trim().isNotEmpty;

  Future<void> _submitInquiry() async {

    setState(() => isSubmitting = true);

    try {

      final response = await http.post(
        Uri.parse("${dotenv.env['PHP_URL']}user_report.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": widget.userId,
          "content": contentController.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (data["success"] == true) {

        setState(() {
          step = _InquiryStep.submitted;
          isSubmitting = false;
        });

      } else {

        setState(() => isSubmitting = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data["message"] ?? "문의 접수에 실패했습니다")),
        );

      }

    } catch (e) {

      if (!mounted) return;

      setState(() => isSubmitting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("에러 발생: $e")),
      );

    }

  }

  @override
  Widget build(BuildContext context) {

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: _buildStepView(),
        ),
      ),
    );

  }

  Widget _buildStepView() {

    switch (step) {
      case _InquiryStep.input:
        return _buildInputStep();
      case _InquiryStep.confirm:
        return _buildConfirmStep();
      case _InquiryStep.submitted:
        return _buildSubmittedView();
    }

  }

  Widget _buildInputStep() {

    return Column(
      key: const ValueKey('input'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        Row(
          children: [

            const Expanded(
              child: Text(
                "문의하기",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.black87),
              ),
            ),

            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.close_rounded, color: Colors.grey.shade400),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),

          ],
        ),

        const SizedBox(height: 4),

        Text(
          "궁금한 점이나 불편한 점을 남겨주세요",
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
        ),

        const SizedBox(height: 16),

        TextField(
          controller: contentController,
          maxLines: 6,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: "문의 내용을 입력해주세요",
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            filled: true,
            fillColor: const Color(0xFFF7F7F9),
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),

        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: canProceed ? () => setState(() => step = _InquiryStep.confirm) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canProceed ? widget.primary : Colors.grey.shade300,
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text("제출", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ),

      ],
    );

  }

  Widget _buildConfirmStep() {

    return Column(
      key: const ValueKey('confirm'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [

        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: widget.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.mail_outline_rounded, color: widget.primary, size: 26),
        ),

        const SizedBox(height: 16),

        const Text(
          "정말 제출하시겠습니까?",
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.black87),
        ),

        const SizedBox(height: 8),

        Text(
          "제출 후에는 내용을 수정할 수 없어요",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
        ),

        const SizedBox(height: 24),

        Row(
          children: [

            Expanded(
              child: OutlinedButton(
                onPressed: isSubmitting ? null : () => setState(() => step = _InquiryStep.input),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text("아니요", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: ElevatedButton(
                onPressed: isSubmitting ? null : _submitInquiry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: isSubmitting
                    ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : const Text("예", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),

          ],
        ),

      ],
    );

  }

  Widget _buildSubmittedView() {

    return Column(
      key: const ValueKey('submitted'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [

        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
        ),

        const SizedBox(height: 16),

        const Text(
          "문의가 접수되었습니다! 감사합니다.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87),
        ),

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text("확인", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ),

      ],
    );

  }

}