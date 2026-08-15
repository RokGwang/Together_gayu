import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OnboardingPopup {

  static const Color primary = Color(0xFFFF7A00);

  /*
  한 번만 보여주는 안내 팝업.
  popupKey는 페이지별 고유 문자열이어야 함 (예: "mainview", "room", "start", "end2", "gps").
  이미 본 유저에게는 서버 조회 후 아무것도 표시하지 않음.
  */

  static Future<void> showOnce({
    required BuildContext context,
    required int userId,
    required String popupKey,
    required String title,
    required String message,
    IconData icon = Icons.tips_and_updates_rounded,
  }) async {

    bool alreadySeen = true;

    try {

      final response = await http.get(
        Uri.parse(
          "${dotenv.env['PHP_URL']}up.php"
              "?user_id=$userId&popup_key=$popupKey",
        ),
      );

      final data = jsonDecode(response.body);

      if (data["success"] == true) {
        alreadySeen = data["seen"] == true;
      }

    } catch (e) {

      // 네트워크 오류 시엔 굳이 팝업을 강제로 띄우지 않고 조용히 넘어감
      return;

    }

    if (alreadySeen) return;

    if (!context.mounted) return;

    await showDialog(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
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
                child: Icon(icon, color: primary, size: 28),
              ),

              const SizedBox(height: 16),

              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "확인했어요",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

            ],
          ),
        ),
      ),
    );

    // 확인 누른 후 -> 서버에 "봤음" 기록
    try {

      await http.post(
        Uri.parse("${dotenv.env['PHP_URL']}up.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": userId,
          "popup_key": popupKey,
        }),
      );

    } catch (e) {
      // 기록 실패해도 이번 세션에는 이미 확인시켰으니 크리티컬하지 않음
    }

  }

}