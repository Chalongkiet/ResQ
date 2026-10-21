import '../../data/models/rescue_account_model.dart';

class RescueSession {
  const RescueSession({
    required this.accountId,
    required this.username,
    this.rescueTeamId,
    this.rescueTeamName,
  });

  final String accountId;
  final String username;

  final String? rescueTeamId;
  final String? rescueTeamName;

  factory RescueSession.fromAccount(RescueAccount account) {
    return RescueSession(
      accountId: account.id,
      username: account.username,
      rescueTeamId: account.rescueTeamId,
      rescueTeamName: account.rescueTeamName,
    );
  }
}
