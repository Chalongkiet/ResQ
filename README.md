# ResQ — Emergency Reporting and Rescue Coordination

ResQ คือแอปพลิเคชันมือถือสำหรับรับแจ้งเหตุฉุกเฉิน ติดตามการช่วยเหลือ และประสานงานระหว่างประชาชนกับทีมกู้ภัยแบบเรียลไทม์ พัฒนาด้วย Flutter และเชื่อมต่อบริการ Cloud สำหรับข้อมูลภารกิจ ตำแหน่ง และรูปภาพประกอบ

> This README is available in [Thai](#ภาษาไทย) and [English](#english).

---

## ภาษาไทย

### ภาพรวม

ResQ ช่วยลดความซ้ำซ้อนของข้อมูลเหตุฉุกเฉินและทำให้การติดตามภารกิจชัดเจนขึ้น โดยแอปแบ่งการใช้งานหลักเป็นสองฝั่ง:

- **ประชาชน/ผู้ประสบภัย:** ดูพื้นที่ภัยพิบัติและข่าวสาร ส่งคำร้องพร้อมตำแหน่งและรูปภาพ ติดตามทีมกู้ภัยแบบสด และยืนยันความปลอดภัย
- **ทีมกู้ภัย:** เข้าร่วมเหตุการณ์ ดูคำร้องใกล้เคียง รับและจัดคิวหลายภารกิจ นำทาง อัปเดตสถานะ ยกเลิกหรือจบภารกิจ และดูประวัติการช่วยเหลือ

### คุณสมบัติสำคัญ

- แสดงเหตุการณ์ภัยพิบัติและขอบเขตความเสี่ยงบนแผนที่
- ส่งคำร้องฉุกเฉินพร้อม GPS จำนวนผู้ประสบภัย สถานการณ์ และรูปภาพ
- ติดตามตำแหน่งทีมกู้ภัยและเส้นทางที่เหลือแบบเรียลไทม์
- จัดการลำดับสถานะภารกิจและคิวคำร้องหลายรายการ
- ตรวจสอบระยะก่อนยืนยันว่าทีมกู้ภัยถึงพื้นที่ผู้ประสบภัย
- ยืนยันความปลอดภัยและเก็บประวัติภารกิจที่เสร็จสิ้น
- รองรับสถานะเครือข่ายและคืนค่าหน้าล่าสุดเมื่อเปิดแอปอีกครั้ง

### เทคโนโลยีหลัก

| ส่วน | เทคโนโลยี |
| --- | --- |
| Mobile application | Flutter และ Dart |
| Authentication และข้อมูล | Firebase Authentication และ Cloud Firestore |
| แผนที่ | flutter_map และ OpenStreetMap |
| ตำแหน่ง | Geolocator |
| การนำทางภายในแอป | GoRouter |
| จัดเก็บรูปภาพ | Cloudinary |
| สถานะเครือข่ายและข้อมูลในเครื่อง | connectivity_plus และ shared_preferences |

### สิ่งที่ต้องติดตั้ง

- Flutter SDK พร้อม Dart
- Android Studio, Android SDK และ Android Emulator หรือโทรศัพท์ Android จริง
- Git
- Visual Studio Code หรือ IDE ที่รองรับ Flutter
- Node.js และ Firebase CLI เฉพาะกรณีที่ต้องตั้งค่าหรือจัดการ Firebase

### การเตรียมโปรเจกต์

1. Clone repository และเข้าโฟลเดอร์แอป

   ```bash
   git clone https://github.com/Chalongkiet/ResQ.git
   cd ResQ/res_q
   ```

2. สร้างไฟล์สภาพแวดล้อมจากไฟล์ตัวอย่าง

   ```powershell
   Copy-Item .env.example .env
   ```

3. กรอกค่าของ Firebase Project ที่คุณได้รับอนุญาตลงใน `.env` ห้ามใช้ค่าจริงในไฟล์ที่ Commit

4. ดาวน์โหลด `google-services.json` จาก Firebase Console ของโปรเจกต์สำหรับพัฒนา แล้ววางไว้ที่:

   ```text
   android/app/google-services.json
   ```

5. ติดตั้งแพ็กเกจ

   ```bash
   flutter pub get
   ```

6. ตรวจสอบสภาพแวดล้อมและอุปกรณ์

   ```bash
   flutter doctor -v
   flutter devices
   ```

7. เปิดแอป

   ```bash
   flutter run
   ```

### การตรวจสอบคุณภาพ

```bash
flutter analyze
flutter test
```

สร้าง APK สำหรับทดสอบ:

```bash
flutter build apk --debug
```

### ความปลอดภัยของข้อมูล

Repository นี้ไม่เก็บไฟล์ `.env`, ไฟล์ตั้งค่า Firebase ของโปรเจกต์จริง, Database export, Backup หรือข้อมูลผู้ใช้งานจริง ผู้พัฒนาต้องใช้เฉพาะข้อมูลทดสอบและเก็บ Credential ไว้นอก Source Control

---

## English

### Overview

ResQ is a mobile emergency-reporting and rescue-coordination application. It helps reduce fragmented incident information and provides a clear, real-time connection between citizens and rescue teams.

The application supports two primary user groups:

- **Citizens and victims:** View disaster areas and public information, submit emergency requests with location and images, track rescue teams, and confirm safety.
- **Rescue teams:** Join disaster operations, view nearby requests, accept and queue multiple missions, navigate, update progress, cancel or complete missions, and review rescue history.

### Key Features

- Disaster events and risk boundaries displayed on an interactive map
- Emergency requests with GPS location, affected-person count, situation details, and images
- Real-time rescue-team location and remaining-route tracking
- Ordered mission-status updates and multi-request mission queues
- Proximity validation before a rescue team can confirm arrival
- Safety confirmation and completed-mission history
- Connectivity awareness and restoration of the most recent page after restarting the app

### Technology Stack

| Area | Technology |
| --- | --- |
| Mobile application | Flutter and Dart |
| Authentication and data | Firebase Authentication and Cloud Firestore |
| Maps | flutter_map and OpenStreetMap |
| Location | Geolocator |
| Navigation | GoRouter |
| Image storage | Cloudinary |
| Connectivity and local state | connectivity_plus and shared_preferences |

### Prerequisites

- Flutter SDK with Dart
- Android Studio, Android SDK, and either an Android Emulator or a physical Android device
- Git
- Visual Studio Code or another Flutter-compatible IDE
- Node.js and Firebase CLI only when Firebase configuration or administration is required

### Project Setup

1. Clone the repository and open the Flutter application directory.

   ```bash
   git clone https://github.com/Chalongkiet/ResQ.git
   cd ResQ/res_q
   ```

2. Create a local environment file from the provided template.

   ```powershell
   Copy-Item .env.example .env
   ```

3. Add authorized development Firebase values to `.env`. Never commit real credentials.

4. Download `google-services.json` from the Firebase Console for your development project and place it at:

   ```text
   android/app/google-services.json
   ```

5. Install dependencies.

   ```bash
   flutter pub get
   ```

6. Verify the development environment and connected devices.

   ```bash
   flutter doctor -v
   flutter devices
   ```

7. Run the application.

   ```bash
   flutter run
   ```

### Quality Checks

```bash
flutter analyze
flutter test
```

Build a debug APK:

```bash
flutter build apk --debug
```

### Data Security

This repository does not include `.env` files, production Firebase configuration, database exports, backups, or real user data. Contributors must use test data only and keep all credentials outside source control.

---

## Project Structure

```text
lib/
├── core/       # App-wide configuration, routing, location, theme, and utilities
├── data/       # Models and data-access services
├── features/   # Citizen, emergency, rescue, profile, news, and tracking flows
└── shared/     # Reusable controllers, validators, and widgets

test/           # Automated tests mirroring production features
android/        # Android platform configuration
ios/            # iOS platform configuration
```

## Disclaimer

ResQ is an academic emergency-response project. It should be reviewed, secured, and tested with the responsible authorities before any real-world emergency deployment.
