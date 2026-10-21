import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_routes.dart';
import '../../shared/widgets/bottom_bar_item.dart';

class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  static const int _homeBranchIndex = 1;
  static const Duration _exitInterval = Duration(seconds: 2);

  DateTime? _lastBackPressedAt;

  void _changePage(int index) {
    _lastBackPressedAt = null;

    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  void _handleBackPressed() {
    final currentIndex = widget.navigationShell.currentIndex;

    // หากไม่ได้อยู่หน้า Home ให้กลับหน้า Home ก่อน
    if (currentIndex != _homeBranchIndex) {
      _lastBackPressedAt = null;

      widget.navigationShell.goBranch(_homeBranchIndex, initialLocation: true);

      return;
    }

    final now = DateTime.now();
    final lastPressed = _lastBackPressedAt;

    final pressedWithinInterval =
        lastPressed != null && now.difference(lastPressed) <= _exitInterval;

    if (pressedWithinInterval) {
      SystemNavigator.pop();
      return;
    }

    _lastBackPressedAt = now;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          duration: _exitInterval,
          content: Text('กดปุ่มกลับอีกครั้งเพื่อออกจากแอป'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.navigationShell.currentIndex;
    final isKeyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, void result) {
        if (didPop) {
          return;
        }

        _handleBackPressed();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: widget.navigationShell,

        floatingActionButton: isKeyboardVisible
            ? null
            : SizedBox(
                width: 68,
                height: 68,
                child: FloatingActionButton(
                  heroTag: 'main-sos-button',
                  onPressed: () {
                    context.pushNamed(AppRouteNames.sos);
                  },
                  child: const Text(
                    'SOS',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                  ),
                ),
              ),

        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

        bottomNavigationBar: BottomAppBar(
          height: 82,
          shape: const CircularNotchedRectangle(),
          notchMargin: 8,
          child: Row(
            children: [
              BottomBarItem(
                icon: Icons.shield_outlined,
                label: 'สำหรับอาสา\nสมัครกู้ภัย',
                isActive: currentIndex == 0,
                onTap: () => _changePage(0),
              ),
              BottomBarItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'หน้าแรก',
                isActive: currentIndex == 1,
                onTap: () => _changePage(1),
              ),
              const SizedBox(width: 68),
              BottomBarItem(
                icon: Icons.article_outlined,
                activeIcon: Icons.article,
                label: 'ข่าวสาร',
                isActive: currentIndex == 2,
                onTap: () => _changePage(2),
              ),
              BottomBarItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'ข้อมูลฉัน',
                isActive: currentIndex == 3,
                onTap: () => _changePage(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
