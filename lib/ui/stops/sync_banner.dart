import 'package:flutter/material.dart';

/// Shows how many outcomes are waiting to sync.
///
/// Works, but has problems (see the README, Part B).
class SyncBanner extends StatelessWidget {
  const SyncBanner({super.key, required this.pendingCount});

  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final label = switch (pendingCount) {
      0 => 'All outcomes synced',
      1 => '1 outcome waiting to sync',
      _ => '$pendingCount outcomes waiting to sync',
    };

    return Semantics(
      container: true,
      liveRegion: true,
      label: label,
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          color: pendingCount == 0
              ? Colors.green.shade100
              : Colors.orange.shade100,
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
          child: Text(label),
        ),
      ),
    );
  }
}
