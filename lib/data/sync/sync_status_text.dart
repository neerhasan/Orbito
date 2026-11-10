/// The words shown on the sync status line.
class SyncStatusText {
  const SyncStatusText(this.label, {this.detail});

  /// Short state: Synced, Syncing, Offline or Connecting.
  final String label;

  /// Optional second line with more information.
  final String? detail;
}

/// Turns the raw sync state into plain words for the screen.
///
/// Kept free of PowerSync types so it is easy to test.
SyncStatusText describeSyncStatus({
  required bool connected,
  required bool connecting,
  required bool transferring,
  required bool hasSyncedBefore,
  required int pendingUploads,
  DateTime? lastSyncedAt,
  String? error,
}) {
  final waiting = switch (pendingUploads) {
    0 => null,
    1 => '1 change waiting to upload',
    _ => '$pendingUploads changes waiting to upload',
  };

  if (!connected) {
    if (connecting && !hasSyncedBefore && error == null) {
      return SyncStatusText('Connecting…', detail: waiting);
    }
    final parts = [
      'Changes are saved on this device and will sync later.',
      ?waiting,
      if (error != null) 'Reason: $error',
    ];
    return SyncStatusText('Offline', detail: parts.join(' '));
  }

  if (transferring || pendingUploads > 0) {
    return SyncStatusText('Syncing…', detail: waiting);
  }

  return SyncStatusText(
    'Synced',
    detail: lastSyncedAt == null
        ? null
        : 'Last synced at ${_clock(lastSyncedAt.toLocal())}',
  );
}

String _clock(DateTime time) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
}
