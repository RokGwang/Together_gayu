import 'package:flutter/material.dart';
import 'tab_controller.dart';

class BottomWidget extends StatelessWidget {

  final int userId;

  const BottomWidget({
    super.key,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {

    return ValueListenableBuilder<int>(

      valueListenable: AppTabController.currentIndex,

      builder: (context, currentIndex, _) {

        return Container(

          height: 75,

          decoration: const BoxDecoration(

            color: Colors.white,

            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
              ),
            ],

          ),

          child: Row(

            mainAxisAlignment: MainAxisAlignment.spaceEvenly,

            children: [

              IconButton(
                onPressed: () => AppTabController.switchTo(0),
                icon: Icon(
                  Icons.circle,
                  size: 34,
                  color: currentIndex == 0
                      ? Colors.orange
                      : Colors.orange.withOpacity(0.35),
                ),
              ),

              IconButton(
                onPressed: () => AppTabController.switchTo(1),
                icon: Icon(
                  Icons.chat_bubble,
                  size: 34,
                  color: currentIndex == 1
                      ? Colors.orange
                      : Colors.orange.withOpacity(0.35),
                ),
              ),

              IconButton(
                onPressed: () => AppTabController.switchTo(2),
                icon: Icon(
                  Icons.person,
                  size: 34,
                  color: currentIndex == 2
                      ? Colors.orange
                      : Colors.orange.withOpacity(0.35),
                ),
              ),

            ],

          ),

        );

      },

    );

  }

}