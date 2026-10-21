import 'package:flutter/material.dart';

class EmergencyTrackingPage extends StatelessWidget {
  const EmergencyTrackingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ติดตามการช่วยเหลือ')),
      body: const Center(child: Text('ยังไม่มีคำร้องที่กำลังดำเนินการ')),
    );
  }
}
