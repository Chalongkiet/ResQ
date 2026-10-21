import 'package:flutter/material.dart';

import '../../models/rescue_member.dart';
import '../../models/rescue_vehicle.dart';

// ==================================================
// Vehicle Picker
// ==================================================

Future<RescueVehicle?> showJoinVehiclePicker({
  required BuildContext context,
  required List<RescueVehicle> vehicles,
  required Set<String> selectedVehicleIds,
}) {
  return showDialog<RescueVehicle>(
    context: context,
    builder: (pickerContext) {
      return AlertDialog(
        title: const Text('เลือกยานพาหนะ'),
        content: SizedBox(
          width: 420,
          child: vehicles.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'ไม่พบข้อมูลยานพาหนะ',
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: vehicles.length,
                  separatorBuilder: (context, index) {
                    return const Divider(height: 1);
                  },
                  itemBuilder: (context, index) {
                    final vehicle = vehicles[index];

                    final alreadySelected = selectedVehicleIds.contains(
                      vehicle.vehicleId,
                    );

                    return ListTile(
                      enabled: !alreadySelected,
                      leading: const Icon(Icons.local_shipping_outlined),
                      title: Text(
                        vehicle.vehicleType.trim().isEmpty
                            ? 'ไม่ระบุประเภทยานพาหนะ'
                            : vehicle.vehicleType,
                      ),
                      subtitle: Text(
                        vehicle.vehiclePlate.trim().isEmpty
                            ? 'ไม่มีข้อมูลป้ายทะเบียน'
                            : vehicle.vehiclePlate,
                      ),
                      trailing: alreadySelected
                          ? const Icon(Icons.check_circle_rounded)
                          : const Icon(Icons.add_circle_outline_rounded),
                      onTap: alreadySelected
                          ? null
                          : () {
                              Navigator.of(pickerContext).pop(vehicle);
                            },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(pickerContext).pop();
            },
            child: const Text('ปิด'),
          ),
        ],
      );
    },
  );
}

// ==================================================
// Member Picker
// ==================================================

Future<RescueMember?> showJoinMemberPicker({
  required BuildContext context,
  required List<RescueMember> members,
  required Set<String> selectedMemberIds,
}) {
  return showDialog<RescueMember>(
    context: context,
    builder: (pickerContext) {
      return AlertDialog(
        title: const Text('เลือกสมาชิก'),
        content: SizedBox(
          width: 420,
          child: members.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'ไม่พบข้อมูลสมาชิกกู้ภัย',
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: members.length,
                  separatorBuilder: (context, index) {
                    return const Divider(height: 1);
                  },
                  itemBuilder: (context, index) {
                    final member = members[index];

                    final alreadySelected = selectedMemberIds.contains(
                      member.memberId,
                    );

                    final details = <String>[
                      if (member.position.trim().isNotEmpty) member.position,

                      if (member.phoneNumber.trim().isNotEmpty)
                        member.phoneNumber,
                    ];

                    return ListTile(
                      enabled: !alreadySelected,
                      leading: CircleAvatar(child: Text('${index + 1}')),
                      title: Text(
                        member.fullName.trim().isEmpty
                            ? 'ไม่ระบุชื่อ'
                            : member.fullName,
                      ),
                      subtitle: details.isEmpty
                          ? null
                          : Text(details.join(' • ')),
                      trailing: alreadySelected
                          ? const Icon(Icons.check_circle_rounded)
                          : const Icon(Icons.add_circle_outline_rounded),
                      onTap: alreadySelected
                          ? null
                          : () {
                              Navigator.of(pickerContext).pop(member);
                            },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(pickerContext).pop();
            },
            child: const Text('ปิด'),
          ),
        ],
      );
    },
  );
}
