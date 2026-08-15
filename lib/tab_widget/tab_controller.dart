import 'package:flutter/foundation.dart';

/*
IndexedStack 구조에서 어느 화면에서든 탭을 전환할 수 있도록
전역으로 현재 탭 인덱스를 관리합니다.

0 = 홈
1 = 채팅
2 = 유저
*/

import 'package:flutter/foundation.dart';

class AppTabController {

  static final ValueNotifier<int> currentIndex = ValueNotifier<int>(0);

  static void switchTo(int index) {

    print("switchTo 호출됨: 현재값=${currentIndex.value}, 요청값=$index, hashCode=${currentIndex.hashCode}");

    currentIndex.value = index;

  }
  static final ValueNotifier<int> chatRefreshTrigger = ValueNotifier<int>(0);

  static void refreshChatTab() {

    chatRefreshTrigger.value++;

  }

  static void reset() {

    currentIndex.value = 0;

  }

}