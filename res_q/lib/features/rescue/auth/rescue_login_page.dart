import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_scope.dart';
import '../../../core/routing/app_routes.dart';
import '../../../data/models/rescue_account_model.dart';
import '../../../data/services/rescue_account_service.dart';
import '../../../data/services/rescue_login_result.dart';
import '../../../shared/validators/rescue_login_validator.dart';
import '../../../shared/widgets/success_alert_dialog.dart';

class RescueLoginPage extends StatefulWidget {
  const RescueLoginPage({super.key});

  @override
  State<RescueLoginPage> createState() => _RescueLoginPageState();
}

class _RescueLoginPageState extends State<RescueLoginPage> {
  final _formKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  final _accountService = RescueAccountService();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  // ==================================================
  // Login
  // ==================================================

  Future<void> _login() async {
    if (_isLoading) {
      return;
    }

    FocusScope.of(context).unfocus();

    // ================================================
    // 1. Validate
    // ================================================

    final isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // ==============================================
      // 2. ตรวจ Username / Password จาก Firestore
      // ==============================================

      final result = await _accountService.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) {
        return;
      }

      // ==============================================
      // 3. Login ไม่สำเร็จ
      // ==============================================

      if (!result.isSuccess) {
        _showLoginError(result);
        return;
      }

      // ==============================================
      // 4. Account
      // ==============================================

      final account = result.account;

      if (account == null) {
        _showMessage('ไม่พบข้อมูลบัญชีทีมกู้ภัย', isError: true);

        return;
      }

      // ==============================================
      // 5. Popup Login Success
      //
      // แสดงก่อนสร้าง Session
      // เพื่อไม่ให้ Router redirect ออกไปก่อน
      // ==============================================

      await _showLoginSuccessDialog(account);

      if (!mounted) {
        return;
      }

      // ==============================================
      // 6. Create + Save Session
      // ==============================================

      final authController = AuthScope.of(context);

      await authController.signInRescue(account);

      if (!mounted) {
        return;
      }

      // ==============================================
      // Debug
      // ==============================================

      debugPrint('==============================');

      debugPrint('RESCUE LOGIN SUCCESS');

      debugPrint('ACCOUNT ID: ${account.id}');

      debugPrint('USERNAME: ${account.username}');

      debugPrint('TEAM: ${account.rescueTeamName}');

      debugPrint(
        'AUTHENTICATED: '
        '${authController.isAuthenticated}',
      );

      debugPrint(
        'IS RESCUE TEAM: '
        '${authController.isRescueTeam}',
      );

      debugPrint('==============================');

      // ==============================================
      // 7. ไป Rescue Home โดยตรง
      // ==============================================

      context.go(AppRoutePaths.rescueHome);
    } catch (error, stackTrace) {
      debugPrint('Rescue login error: $error');

      debugPrint('$stackTrace');

      if (!mounted) {
        return;
      }

      _showMessage(
        'ไม่สามารถเข้าสู่ระบบได้ กรุณาลองใหม่อีกครั้ง',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ==================================================
  // Login Success Popup
  // ==================================================

  Future<void> _showLoginSuccessDialog(RescueAccount account) async {
    final teamName = account.rescueTeamName?.trim();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: SuccessAlertDialog(
            title: 'เข้าสู่ระบบสำเร็จ',
            message: teamName != null && teamName.isNotEmpty
                ? 'ยินดีต้อนรับ $teamName'
                : 'ยินดีต้อนรับเข้าสู่ระบบทีมกู้ภัย',
            onConfirm: () => Navigator.of(dialogContext).pop(),
          ),
        );
      },
    );
  }

  // ==================================================
  // Login Error
  // ==================================================

  void _showLoginError(RescueLoginResult result) {
    switch (result.status) {
      case RescueLoginStatus.accountNotFound:
        _showMessage('ไม่พบบัญชีผู้ใช้งาน', isError: true);
        break;

      case RescueLoginStatus.wrongPassword:
        _showMessage('ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง', isError: true);
        break;

      case RescueLoginStatus.notApproved:
        _showMessage('บัญชีของคุณยังไม่ได้รับการอนุมัติ', isError: true);
        break;

      case RescueLoginStatus.inactive:
        _showMessage('บัญชีนี้ถูกระงับการใช้งาน', isError: true);
        break;

      case RescueLoginStatus.success:
        break;
    }
  }

  // ==================================================
  // SnackBar
  // ==================================================

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }

    final theme = Theme.of(context);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError
              ? theme.colorScheme.error
              : const Color(0xFF16A34A),
          content: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
  }

  // ==================================================
  // Build
  // ==================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,

          // กดพื้นที่ว่างเพื่อปิด Keyboard
          onTap: () {
            FocusScope.of(context).unfocus();
          },

          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ==================================
                      // Header
                      // ==================================
                      _buildHeader(theme),

                      const SizedBox(height: 40),

                      // ==================================
                      // Username Label
                      // ==================================
                      Text(
                        'ชื่อผู้ใช้',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // ==================================
                      // Username
                      // ==================================
                      TextFormField(
                        controller: _usernameController,
                        enabled: !_isLoading,
                        keyboardType: TextInputType.visiblePassword,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.username],
                        maxLength: 16,

                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[A-Za-z0-9]'),
                          ),
                          LengthLimitingTextInputFormatter(16),
                        ],

                        style: const TextStyle(color: Color(0xFF111827)),

                        decoration: _inputDecoration(
                          hintText: 'กรอกชื่อผู้ใช้',
                          icon: Icons.person_outline,
                        ),

                        validator: RescueLoginValidator.validateUsername,
                      ),

                      const SizedBox(height: 20),

                      // ==================================
                      // Password Label
                      // ==================================
                      Text(
                        'รหัสผ่าน',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // ==================================
                      // Password
                      // ==================================
                      TextFormField(
                        controller: _passwordController,
                        enabled: !_isLoading,
                        obscureText: _obscurePassword,
                        keyboardType: TextInputType.visiblePassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        maxLength: 16,

                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[A-Za-z0-9!#_.]'),
                          ),
                          LengthLimitingTextInputFormatter(16),
                        ],

                        style: const TextStyle(color: Color(0xFF111827)),

                        decoration:
                            _inputDecoration(
                              hintText: 'กรอกรหัสผ่าน',
                              icon: Icons.lock_outline,
                            ).copyWith(
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? 'แสดงรหัสผ่าน'
                                    : 'ซ่อนรหัสผ่าน',
                                onPressed: _isLoading
                                    ? null
                                    : () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),

                        validator: RescueLoginValidator.validatePassword,

                        onFieldSubmitted: (_) {
                          if (!_isLoading) {
                            _login();
                          }
                        },
                      ),

                      const SizedBox(height: 28),

                      // ==================================
                      // Login Button
                      // ==================================
                      SizedBox(
                        height: 54,
                        child: FilledButton(
                          onPressed: _isLoading ? null : _login,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.login_rounded),
                                    SizedBox(width: 10),
                                    Text(
                                      'เข้าสู่ระบบ',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ==================================
                      // Info
                      // ==================================
                      _buildInformationCard(theme),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==================================================
  // Header
  // ==================================================

  Widget _buildHeader(ThemeData theme) {
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.health_and_safety_outlined,
            size: 46,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),

        const SizedBox(height: 20),

        Text(
          'เข้าสู่ระบบทีมกู้ภัย',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'สำหรับหน่วยงานและเจ้าหน้าที่ทีมกู้ภัย',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  // ==================================================
  // Information Card
  // ==================================================

  Widget _buildInformationCard(ThemeData theme) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 22, color: theme.colorScheme.primary),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              'บัญชีทีมกู้ภัยต้องได้รับการอนุมัติและอยู่ในสถานะใช้งาน '
              'จึงจะสามารถเข้าสู่ระบบได้',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================================================
  // Input Decoration
  // ==================================================

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData icon,
  }) {
    const borderColor = Color(0xFFD1D5DB);

    const focusColor = Color(0xFF6B7280);

    return InputDecoration(
      hintText: hintText,

      filled: true,
      fillColor: Colors.white,

      counterText: '',

      prefixIcon: Icon(icon, color: const Color(0xFF6B7280)),

      hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),

      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: borderColor),
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: borderColor),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: focusColor, width: 1.5),
      ),

      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red),
      ),

      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),

      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
    );
  }
}
