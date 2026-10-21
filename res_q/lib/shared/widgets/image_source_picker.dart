import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

Future<ImageSource?> showImageSourcePicker(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'เพิ่มรูปภาพ',
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('ถ่ายรูปด้วยกล้อง'),
                subtitle: const Text('เปิดกล้องเพื่อถ่ายรูปใหม่'),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('เลือกจากคลังภาพ'),
                subtitle: const Text('เลือกรูปที่มีอยู่ในอุปกรณ์'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
    },
  );
}
