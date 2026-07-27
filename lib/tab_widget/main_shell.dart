import 'package:flutter/material.dart';
import 'tab_controller.dart';
import '../mainview.dart';
import '../chat/mychat.dart';
import '../user/user.dart';

class MainShell extends StatefulWidget {

  final int userId;

  const MainShell({
    super.key,
    required this.userId,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {

  int _currentIndex = 0;

  final GlobalKey<NavigatorState> _homeNavKey =
  GlobalKey<NavigatorState>(debugLabel: 'home_nav');

  final GlobalKey<NavigatorState> _chatNavKey =
  GlobalKey<NavigatorState>(debugLabel: 'chat_nav');

  final GlobalKey<NavigatorState> _userNavKey =
  GlobalKey<NavigatorState>(debugLabel: 'user_nav');

  @override
  void initState() {

    super.initState();

    AppTabController.currentIndex.addListener(_onTabChanged);

  }

  @override
  void dispose() {

    AppTabController.currentIndex.removeListener(_onTabChanged);

    super.dispose();

  }

  void _onTabChanged() {

    if (!mounted) return;

    setState(() {
      _currentIndex = AppTabController.currentIndex.value;
    });

  }

  Future<bool> _onWillPop() async {

    final keys = [_homeNavKey, _chatNavKey, _userNavKey];

    final currentNavigator = keys[_currentIndex].currentState;

    final isFirstRouteInCurrentTab = !(await currentNavigator!.maybePop());

    if (isFirstRouteInCurrentTab && _currentIndex != 0) {

      AppTabController.switchTo(0);

      return false;

    }

    return isFirstRouteInCurrentTab;

  }

  @override
  Widget build(BuildContext context) {

    return WillPopScope(

      onWillPop: _onWillPop,

      child: IndexedStack(

        index: _currentIndex,

        children: [

          Navigator(
            key: _homeNavKey,
            onGenerateRoute: (settings) => MaterialPageRoute(
              builder: (_) => IntroPage(userId: widget.userId),
            ),
          ),

          Navigator(
            key: _chatNavKey,
            onGenerateRoute: (settings) => MaterialPageRoute(
              builder: (_) => MyChatPage(userId: widget.userId),
            ),
          ),

          Navigator(
            key: _userNavKey,
            onGenerateRoute: (settings) => MaterialPageRoute(
              builder: (_) => UserPage(userId: widget.userId),
            ),
          ),

        ],

      ),

    );

  }

}