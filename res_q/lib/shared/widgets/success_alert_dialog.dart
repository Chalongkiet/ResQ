import 'package:flutter/material.dart';

class SuccessAlertDialog extends StatelessWidget {
  const SuccessAlertDialog({
    super.key,
    required this.title,
    required this.message,
    required this.onConfirm,
    this.buttonLabel = 'ตกลง',
    this.icon = Icons.check_circle_rounded,
    this.iconColor = const Color(0xFF16A34A),
    this.messageColor = const Color(0xFF374151),
  });

  final String title;
  final String message;
  final VoidCallback onConfirm;
  final String buttonLabel;
  final IconData icon;
  final Color iconColor;
  final Color messageColor;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      icon: Icon(icon, size: 60, color: iconColor),
      title: Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF111827),
          fontWeight: FontWeight.w800,
        ),
      ),
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: messageColor, height: 1.45),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        SizedBox(
          width: 120,
          child: FilledButton(onPressed: onConfirm, child: Text(buttonLabel)),
        ),
      ],
    );
  }
}
