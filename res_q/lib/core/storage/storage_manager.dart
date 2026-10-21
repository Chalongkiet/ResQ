class StorageManager {
  const StorageManager();

  Future<void> saveBeforeAppClosed() async {
    // TODO: บันทึกข้อมูลสำคัญก่อนแอปปิด
    // เช่น draft emergency request, offline queue, mission state
  }
}
