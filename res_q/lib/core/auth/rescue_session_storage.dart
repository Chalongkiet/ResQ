import 'package:shared_preferences/shared_preferences.dart';

import 'rescue_session.dart';

class RescueSessionStorage {
  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  static const String _keyLoggedIn = 'rescue_logged_in';

  static const String _keyAccountId = 'rescue_account_id';

  static const String _keyUsername = 'rescue_username';

  static const String _keyTeamId = 'rescue_team_id';

  static const String _keyTeamName = 'rescue_team_name';

  // ==================================================
  // Save
  // ==================================================

  Future<void> save(RescueSession session) async {
    await _prefs.setBool(_keyLoggedIn, true);

    await _prefs.setString(_keyAccountId, session.accountId);

    await _prefs.setString(_keyUsername, session.username);

    if (session.rescueTeamId != null) {
      await _prefs.setString(_keyTeamId, session.rescueTeamId!);
    } else {
      await _prefs.remove(_keyTeamId);
    }

    if (session.rescueTeamName != null) {
      await _prefs.setString(_keyTeamName, session.rescueTeamName!);
    } else {
      await _prefs.remove(_keyTeamName);
    }
  }

  // ==================================================
  // Load
  // ==================================================

  Future<RescueSession?> load() async {
    final loggedIn = await _prefs.getBool(_keyLoggedIn) ?? false;

    if (!loggedIn) {
      return null;
    }

    final accountId = await _prefs.getString(_keyAccountId);

    final username = await _prefs.getString(_keyUsername);

    if (accountId == null ||
        accountId.isEmpty ||
        username == null ||
        username.isEmpty) {
      await clear();

      return null;
    }

    return RescueSession(
      accountId: accountId,
      username: username,
      rescueTeamId: await _prefs.getString(_keyTeamId),
      rescueTeamName: await _prefs.getString(_keyTeamName),
    );
  }

  // ==================================================
  // Clear
  // ==================================================

  Future<void> clear() async {
    await _prefs.remove(_keyLoggedIn);

    await _prefs.remove(_keyAccountId);

    await _prefs.remove(_keyUsername);

    await _prefs.remove(_keyTeamId);

    await _prefs.remove(_keyTeamName);
  }
}
