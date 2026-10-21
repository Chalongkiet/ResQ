import 'package:flutter/material.dart';

class EmergencyInfoValidationPopup extends StatelessWidget {
  const EmergencyInfoValidationPopup({super.key, required this.message});

  static const popupKey = ValueKey<String>('emergency-info-validation-popup');

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Positioned.fill(
      child: IgnorePointer(
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Material(
                  key: popupKey,
                  color: theme.colorScheme.errorContainer,
                  elevation: 16,
                  shadowColor: Colors.black45,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            message,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
