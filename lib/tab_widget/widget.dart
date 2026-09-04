import 'package:flutter/material.dart';
import 'tab_controller.dart';

class BottomWidget extends StatelessWidget {
  final int userId;

  const BottomWidget({
    super.key,
    required this.userId,
  });

  static const Color primary = Color(0xFFFF7A00);

  @override
  Widget build(BuildContext context) {

    return ValueListenableBuilder<int>(
      valueListenable: AppTabController.currentIndex,
      builder: (context, currentIndex, _) {

        return Container(

          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),

          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),

          child: SafeArea(

            top: false,

            child: Padding(

              padding: const EdgeInsets.only(bottom: 10, top: 6),

              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [

                  _NavItem(
                    icon: Icons.explore_outlined,
                    activeIcon: Icons.explore_rounded,
                    label: "홈",
                    selected: currentIndex == 0,
                    onTap: () => AppTabController.switchTo(0),
                  ),

                  _NavItem(
                    icon: Icons.chat_bubble_outline_rounded,
                    activeIcon: Icons.chat_bubble_rounded,
                    label: "채팅",
                    selected: currentIndex == 1,
                    onTap: () => AppTabController.switchTo(1),
                  ),

                  _NavItem(
                    icon: Icons.person_outline_rounded,
                    activeIcon: Icons.person_rounded,
                    label: "내 정보",
                    selected: currentIndex == 2,
                    onTap: () => AppTabController.switchTo(2),
                  ),

                ],
              ),

            ),

          ),

        );

      },
    );

  }

}

class _NavItem extends StatelessWidget {

  final IconData icon;

  final IconData activeIcon;

  final String label;

  final bool selected;

  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const Color primary = Color(0xFFFF7A00);

  @override
  Widget build(BuildContext context) {

    return GestureDetector(

      onTap: onTap,

      behavior: HitTestBehavior.opaque,

      child: AnimatedContainer(

        duration: const Duration(milliseconds: 220),

        curve: Curves.easeOut,

        padding: EdgeInsets.symmetric(
          horizontal: selected ? 18 : 12,
          vertical: 9,
        ),

        decoration: BoxDecoration(
          color: selected ? primary.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),

        child: Row(

          mainAxisSize: MainAxisSize.min,

          children: [

            Icon(
              selected ? activeIcon : icon,
              size: 24,
              color: selected ? primary : Colors.grey.shade400,
            ),

            AnimatedSize(

              duration: const Duration(milliseconds: 220),

              curve: Curves.easeOut,

              child: selected
                  ? Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
                  : const SizedBox(width: 0),

            ),

          ],

        ),

      ),

    );

  }

}