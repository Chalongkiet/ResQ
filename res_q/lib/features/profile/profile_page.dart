import 'package:flutter/material.dart';

import '../../core/theme/theme_scope.dart';
import '../../data/models/emergency_info_model.dart';
import '../../data/services/emergency_info_service.dart';
import '../../data/services/exceptions/emergency_info_exception.dart';
import '../emergency_info/controllers/emergency_info_form_controller.dart';
import '../emergency_info/widgets/emergency_info_form.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();

  final _formController = EmergencyInfoFormController();

  final _service = EmergencyInfoService();

  EmergencyInfo? _info;

  bool _isLoading = true;
  bool _isSaving = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _formController.dispose();
    super.dispose();
  }

  // ==================================================
  // Load
  // ==================================================

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final info = await _service.get();

      if (!mounted) {
        return;
      }

      if (info == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'ไม่พบข้อมูลฉุกเฉิน';
        });

        return;
      }

      _info = info;

      _formController.load(info);

      setState(() {
        _isLoading = false;
      });
    } on EmergencyInfoException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });
    } catch (error) {
      debugPrint('Load emergency info error: $error');

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'ไม่สามารถโหลดข้อมูลฉุกเฉินได้';
      });
    }
  }

  // ==================================================
  // Save
  // ==================================================

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }

    if (!await _formController.validateAndFocusFirstError(context)) {
      return;
    }

    if (!mounted) {
      return;
    }

    final currentInfo = _info;

    if (currentInfo == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final updated = await _service.update(
        fullName: _formController.fullName.text,
        phoneNumber: _formController.phoneNumber.text,
        bloodGroup: currentInfo.bloodGroup,
        medicalCondition: _formController.medicalCondition.text,
        allergy: _formController.allergy.text,
        regularMedication: _formController.regularMedication.text,
        emergencyContactName: _formController.emergencyContactName.text,
        emergencyContactPhone: _formController.emergencyContactPhone.text,
      );

      if (!mounted) {
        return;
      }

      _info = updated;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('แก้ไขข้อมูลฉุกเฉินเรียบร้อยแล้ว')),
      );
    } on EmergencyInfoException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      debugPrint('Update emergency info error: $error');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'ไม่สามารถแก้ไขข้อมูลได้ '
            'กรุณาลองใหม่อีกครั้ง',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ==================================================
  // Build
  // ==================================================

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeScope.of(context);

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ข้อมูลฉัน'),
        actions: [
          Tooltip(
            message: isDarkMode ? 'เปลี่ยนเป็นโหมดสว่าง' : 'เปลี่ยนเป็นโหมดมืด',
            child: GestureDetector(
              onLongPress: () {
                themeController.setThemeMode(ThemeMode.system);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('เปลี่ยนเป็นโหมดตามการตั้งค่าเครื่องแล้ว'),
                  ),
                );
              },
              child: IconButton(
                onPressed: () {
                  themeController.setThemeMode(
                    isDarkMode ? ThemeMode.light : ThemeMode.dark,
                  );
                },
                icon: Icon(
                  isDarkMode
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _ErrorView(message: _errorMessage!, onRetry: _load);
    }

    return EmergencyInfoForm(
      formKey: _formKey,
      controller: _formController,
      isSaving: _isSaving,
      submitLabel: 'บันทึกการแก้ไข',
      bloodGroupEditable: false,
      onBloodGroupChanged: (_) {},
      onSave: _save,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
      footer: _info == null ? null : _ConsentStatusCard(info: _info!),
    );
  }
}

// ====================================================
// Consent
// ====================================================

class _ConsentStatusCard extends StatelessWidget {
  const _ConsentStatusCard({required this.info});

  final EmergencyInfo info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.45,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_user_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ยินยอมการใช้ข้อมูลแล้ว',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Consent version '
                  '${info.consentVersion}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ====================================================
// Error
// ====================================================

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('ลองใหม่'),
            ),
          ],
        ),
      ),
    );
  }
}
