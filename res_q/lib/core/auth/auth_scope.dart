import 'package:flutter/material.dart';

import 'auth_session_controller.dart';

class AuthScope extends InheritedNotifier<AuthSessionController> {
  const AuthScope({
    super.key,
    required AuthSessionController controller,
    required super.child,
  }) : super(notifier: controller);

  static AuthSessionController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AuthScope>();

    assert(scope != null, 'AuthScope not found in widget tree');

    return scope!.notifier!;
  }
}
