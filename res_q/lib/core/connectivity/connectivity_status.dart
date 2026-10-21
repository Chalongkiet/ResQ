enum AppConnectivityStatus {
  online,
  offline;

  bool get isOnline => this == AppConnectivityStatus.online;

  bool get isOffline => this == AppConnectivityStatus.offline;
}
