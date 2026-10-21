import '../models/rescue_account_model.dart';

enum RescueLoginStatus {
  success,
  accountNotFound,
  wrongPassword,
  notApproved,
  inactive,
}

class RescueLoginResult {
  const RescueLoginResult({required this.status, this.account});

  final RescueLoginStatus status;
  final RescueAccount? account;

  bool get isSuccess => status == RescueLoginStatus.success;

  String get message {
    switch (status) {
      case RescueLoginStatus.success:
        return 'เข้าสู่ระบบสำเร็จ';

      case RescueLoginStatus.accountNotFound:
        return 'ไม่พบบัญชีผู้ใช้งาน';

      case RescueLoginStatus.wrongPassword:
        return 'ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง';

      case RescueLoginStatus.notApproved:
        return 'บัญชีของคุณยังไม่ได้รับการอนุมัติ';

      case RescueLoginStatus.inactive:
        return 'บัญชีนี้ถูกระงับการใช้งาน';
    }
  }
}
