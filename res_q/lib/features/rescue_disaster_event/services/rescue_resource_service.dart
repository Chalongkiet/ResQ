import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/rescue_member.dart';
import '../models/rescue_vehicle.dart';

class RescueResourceService {
  RescueResourceService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // ==================================================
  // Members
  // ==================================================

  Future<List<RescueMember>> getMembers({required String rescueTeamId}) async {
    final teamId = rescueTeamId.trim();

    if (teamId.isEmpty) {
      debugPrint('[RESOURCE] getMembers: teamId empty');

      return [];
    }

    debugPrint('[RESOURCE] loading members...');

    debugPrint(
      '[RESOURCE] path='
      'RescueOrganization/'
      '$teamId/'
      'RescueTeamMember',
    );

    try {
      final snapshot = await _firestore
          .collection('RescueOrganization')
          .doc(teamId)
          .collection('RescueTeamMember')
          .get()
          .timeout(const Duration(seconds: 10));

      debugPrint(
        '[RESOURCE] members loaded='
        '${snapshot.docs.length}',
      );

      final members = snapshot.docs.map(RescueMember.fromFirestore).toList();

      members.sort((a, b) => a.fullName.compareTo(b.fullName));

      return members;
    } catch (error, stackTrace) {
      debugPrint('[RESOURCE] getMembers ERROR');

      debugPrint('[RESOURCE] $error');

      debugPrint('[RESOURCE] $stackTrace');

      rethrow;
    }
  }

  // ==================================================
  // Vehicles
  // ==================================================

  Future<List<RescueVehicle>> getVehicles({
    required String rescueTeamId,
  }) async {
    final teamId = rescueTeamId.trim();

    if (teamId.isEmpty) {
      debugPrint('[RESOURCE] getVehicles: teamId empty');

      return [];
    }

    debugPrint('[RESOURCE] loading vehicles...');

    debugPrint(
      '[RESOURCE] path='
      'RescueOrganization/'
      '$teamId/'
      'Vehicles',
    );

    try {
      final snapshot = await _firestore
          .collection('RescueOrganization')
          .doc(teamId)
          .collection('Vehicles')
          .get()
          .timeout(const Duration(seconds: 10));

      debugPrint(
        '[RESOURCE] vehicles loaded='
        '${snapshot.docs.length}',
      );

      final vehicles = snapshot.docs.map(RescueVehicle.fromFirestore).toList();

      vehicles.sort((a, b) => a.vehiclePlate.compareTo(b.vehiclePlate));

      return vehicles;
    } catch (error, stackTrace) {
      debugPrint('[RESOURCE] getVehicles ERROR');

      debugPrint('[RESOURCE] $error');

      debugPrint('[RESOURCE] $stackTrace');

      rethrow;
    }
  }

  // ==================================================
  // Load Resources
  // ==================================================

  Future<RescueResources> getResources({required String rescueTeamId}) async {
    final teamId = rescueTeamId.trim();

    debugPrint('================================');

    debugPrint('[RESOURCE] GET RESOURCES START');

    debugPrint('[RESOURCE] rescueTeamId=$teamId');

    if (teamId.isEmpty) {
      throw StateError('rescueTeamId is empty');
    }

    try {
      // Members + Vehicles โหลดพร้อมกัน
      final results = await Future.wait<Object>([
        getMembers(rescueTeamId: teamId),
        getVehicles(rescueTeamId: teamId),
      ]).timeout(const Duration(seconds: 12));

      final members = results[0] as List<RescueMember>;

      final vehicles = results[1] as List<RescueVehicle>;

      debugPrint('[RESOURCE] GET RESOURCES SUCCESS');

      debugPrint('[RESOURCE] members=${members.length}');

      debugPrint('[RESOURCE] vehicles=${vehicles.length}');

      debugPrint('================================');

      return RescueResources(members: members, vehicles: vehicles);
    } catch (error, stackTrace) {
      debugPrint('[RESOURCE] GET RESOURCES ERROR');

      debugPrint('[RESOURCE] $error');

      debugPrint('[RESOURCE] $stackTrace');

      debugPrint('================================');

      rethrow;
    }
  }
}

// ==================================================
// Resource Result
// ==================================================

class RescueResources {
  const RescueResources({required this.members, required this.vehicles});

  final List<RescueMember> members;

  final List<RescueVehicle> vehicles;
}
