/// Sync status for cloud synchronization
enum SyncStatus {
  idle,
  syncing,
  synced,
  error,
  offline;

  String get displayName {
    switch (this) {
      case SyncStatus.idle:
        return 'Not syncing';
      case SyncStatus.syncing:
        return 'Syncing...';
      case SyncStatus.synced:
        return 'Synced';
      case SyncStatus.error:
        return 'Sync error';
      case SyncStatus.offline:
        return 'Offline';
    }
  }
}

/// Spend view mode for household
enum SpendViewMode {
  myShare,
  householdTotal;

  String get displayName {
    switch (this) {
      case SpendViewMode.myShare:
        return 'My Share';
      case SpendViewMode.householdTotal:
        return 'Household';
    }
  }
}
