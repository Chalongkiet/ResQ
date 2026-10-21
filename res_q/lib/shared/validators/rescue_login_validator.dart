class RescueLoginValidator {
  static String? validateUsername(String? value) {
    final username = value?.trim() ?? '';

    if (username.isEmpty) {
      return 'กรุณากรอกชื่อผู้ใช้';
    }

    if (username.length < 6 || username.length > 16) {
      return 'ชื่อผู้ใช้ต้องมี 6-16 ตัวอักษร';
    }

    if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(username)) {
      return 'ชื่อผู้ใช้ใช้ได้เฉพาะภาษาอังกฤษและตัวเลข';
    }

    return null;
  }

  static String? validatePassword(String? value) {
    final password = value ?? '';

    if (password.isEmpty) {
      return 'กรุณากรอกรหัสผ่าน';
    }

    if (password.length < 8 || password.length > 16) {
      return 'รหัสผ่านต้องมี 8-16 ตัวอักษร';
    }

    if (!RegExp(r'^[A-Za-z0-9!#_.]+$').hasMatch(password)) {
      return 'รหัสผ่านมีอักขระที่ไม่รองรับ';
    }

    return null;
  }
}
