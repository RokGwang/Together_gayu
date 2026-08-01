import 'package:flutter/material.dart';
import 'photo.dart'; // PhotoPage가 정의된 파일 import

class InformationPage extends StatelessWidget {
  final String regionName;

  const InformationPage({
    super.key,
    required this.regionName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$regionName 정보'),
      ),
      body: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1. 지도 모양 버튼
            _buildIconButton(
              icon: Icons.map_rounded,
              label: '지도 보기',
              onPressed: () {
                // 지도 관련 동작 추가
                debugPrint('지도 버튼 클릭됨');
              },
            ),

            const SizedBox(width: 40),

            // 2. 갤러리 모양 버튼
            _buildIconButton(
              icon: Icons.photo_library_rounded,
              label: '갤러리',
              onPressed: () {
                // PhotoPage로 이동
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PhotoPage(regionName: regionName),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // 버튼을 생성하는 공통 위젯
  Widget _buildIconButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: 40, color: const Color(0xFFFF7A00)),
          padding: const EdgeInsets.all(16),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFFF7A00).withOpacity(0.1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}