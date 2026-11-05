import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/delivery_outcome.dart';
import 'local_store.dart';

/// The storage key for the whole queue (a JSON document).
const String outboxStorageKey = 'tawseel.outbox.v1';

enum EntryStatus { pending, rejected }

/// One queued outcome. Immutable; the outbox replaces entries with [copyWith].
final class OutboxEntry {
  const OutboxEntry({
    required this.id,
    required this.outcome,
    this.attempts = 0,
    this.status = EntryStatus.pending,
    this.rejectionReason,
  });

  /// Generated on the phone when the outcome is recorded; sent as the
  /// Idempotency-Key header.
  final String id;
  final DeliveryOutcome outcome;

  /// How many times this entry has been sent, whatever the answer was.
  final int attempts;
  final EntryStatus status;
  final String? rejectionReason;

  OutboxEntry copyWith({
    DeliveryOutcome? outcome,
    int? attempts,
    EntryStatus? status,
    String? rejectionReason,
  }) => OutboxEntry(
    id: id,
    outcome: outcome ?? this.outcome,
    attempts: attempts ?? this.attempts,
    status: status ?? this.status,
    rejectionReason: rejectionReason ?? this.rejectionReason,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'outcome': outcome.toJson(),
    'attempts': attempts,
    'status': status.name,
    'rejectionReason': rejectionReason,
  };

  factory OutboxEntry.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final outcome = json['outcome'];
    final attempts = json['attempts'];
    final status = json['status'];
    final reason = json['rejectionReason'];
    if (id is! String ||
        outcome is! Map ||
        attempts is! int ||
        status is! String ||
        (reason != null && reason is! String)) {
      throw FormatException('bad outbox entry: $json');
    }
    return OutboxEntry(
      id: id,
      outcome: DeliveryOutcome.fromJson(outcome.cast<String, Object?>()),
      attempts: attempts,
      status: EntryStatus.values.byName(status),
      rejectionReason: reason as String?,
    );
  }

  @override
  String toString() =>
      'OutboxEntry($id, ${outcome.parcelId}, attempts: $attempts, ${status.name})';
}

/// What one sync run did.
final class SyncReport {
  const SyncReport({
    required this.sent,
    required this.rejected,
    required this.remaining,
    this.authRequired = false,
    this.retryAfter,
  });

  /// Entries the server accepted in this run (200, 201 or 409).
  final int sent;

  /// Entries the server rejected in this run (400 or 422).
  final int rejected;

  /// Pending entries left after the run.
  final int remaining;

  /// True when the run stopped on a 401.
  final bool authRequired;

  /// Set when the run stopped on a transient failure: wait this long.
  final Duration? retryAfter;

  @override
  String toString() =>
      'SyncReport(sent: $sent, rejected: $rejected, '
      'remaining: $remaining, authRequired: $authRequired, '
      'retryAfter: $retryAfter)';
}

/// 5 s × 2^(n−1), capped at 300 s. [consecutiveFailures] must be at least 1,
/// otherwise throw ArgumentError.
///
/// TODO(W4): implement.
Duration retryDelay(int consecutiveFailures) {
  if (consecutiveFailures < 1) {
    throw ArgumentError.value(
      consecutiveFailures,
      'consecutiveFailures',
      'must be at least 1',
    );
  }
  if (consecutiveFailures >= 7) {
    return const Duration(seconds: 300);
  }
  var seconds = 5;
  for (var i = 1; i < consecutiveFailures; i++) {
    seconds *= 2;
  }
  return Duration(seconds: seconds);
}

/// An offline-first queue of delivery outcomes. See the README for the rules.
///
/// Keep the constructor and the public method signatures exactly.
class Outbox {
  Outbox({
    required this._store,
    required this._client,
    required this._baseUrl,
    required this._newId,
  });

  final List<OutboxEntry> _entries = [];

  Future<SyncReport>? _syncFuture;
  Future<void>? _loadFuture;
  Future<void> _ensureLoaded() {
    return _loadFuture ??= _load();
  }

  Future<void> _load() async {
    final saved = await _store.read(outboxStorageKey);
    if (saved == null) return;
    final decoded = jsonDecode(saved) as List;

    _entries.addAll(
      decoded.map(
        (e) => OutboxEntry.fromJson((e as Map).cast<String, Object?>()),
      ),
    );
  }

  Future<void> _persist() {
    final json = jsonEncode(_entries.map((entry) => entry.toJson()).toList());

    final write = _writeTail
        .catchError((Object _) {})
        .then((_) => _store.write(outboxStorageKey, json));

    _writeTail = write;
    return write;
  }

  Future<void> _writeTail = Future<void>.value();
  // ignore: unused_field
  final LocalStore _store;
  // ignore: unused_field
  final http.Client _client;
  // ignore: unused_field
  final Uri _baseUrl;
  // ignore: unused_field
  final String Function() _newId;

  /// TODO(W4): validate, queue (or correct), and persist before completing.
  Future<OutboxEntry> record(DeliveryOutcome outcome) async {
    if (outcome.parcelId.isEmpty || !outcome.recordedAt.isUtc) {
      throw ArgumentError('Invalid delivery outcome');
    }
    if (outcome.status == OutcomeStatus.delivered) {
      if (outcome.codCollectedPiasters < 0 || outcome.reason != null) {
        throw ArgumentError('Invalid delivery outcome for delivered status');
      }
    } else if (outcome.status == OutcomeStatus.failed) {
      if (outcome.reason == null || outcome.codCollectedPiasters != 0) {
        throw ArgumentError('Invalid delivery outcome for failed status');
      }
    }
    await _ensureLoaded();

    final existingIndex = _entries.indexWhere(
      (entry) =>
          entry.status == EntryStatus.pending &&
          entry.attempts == 0 &&
          entry.outcome.parcelId == outcome.parcelId,
    );
    late final OutboxEntry entry;

    if (existingIndex != -1) {
      final existingEntry = _entries[existingIndex];
      entry = OutboxEntry(
        id: existingEntry.id,
        outcome: outcome,
        attempts: existingEntry.attempts,
        status: existingEntry.status,
        rejectionReason: existingEntry.rejectionReason,
      );
      _entries[existingIndex] = entry;
    } else {
      entry = OutboxEntry(id: _newId(), outcome: outcome);
      _entries.add(entry);
    }
    await _persist();
    return entry;
  }

  /// Pending entries, in send order.
  Future<List<OutboxEntry>> pending() async {
    await _ensureLoaded();
    return _entries
        .where((entry) => entry.status == EntryStatus.pending)
        .toList();
  }

  Future<List<OutboxEntry>> rejected() async {
    await _ensureLoaded();
    return _entries
        .where((entry) => entry.status == EntryStatus.rejected)
        .toList();
  }

  Future<int> pendingCount() async {
    await _ensureLoaded();
    return _entries
        .where((entry) => entry.status == EntryStatus.pending)
        .length;
  }

  /// TODO(W4): send pending entries oldest first; single-flight.

  /// Send pending entries oldest first; simultaneous calls share one Future.
  Future<SyncReport> sync() {
    return _syncFuture ??= _runSync().whenComplete(() {
      _syncFuture = null;
    });
  }

  Future<SyncReport> _runSync() async {
    await _ensureLoaded();

    var sent = 0;
    var rejectedCount = 0;
    var authRequired = false;
    Duration? retryAfter;

    while (true) {
      final index = _entries.indexWhere(
        (entry) => entry.status == EntryStatus.pending,
      );

      if (index == -1) break;

      final entry = _entries[index];

      // Count every attempt, including unsuccessful requests.
      final attemptedEntry = entry.copyWith(attempts: entry.attempts + 1);

      _entries[index] = attemptedEntry;
      await _persist();

      try {
        final response = await _client.post(
          _baseUrl.resolve('/v1/outcomes'),
          headers: {
            'Content-Type': 'application/json',
            'Idempotency-Key': attemptedEntry.id,
          },
          body: jsonEncode({
            'id': attemptedEntry.id,
            ...attemptedEntry.outcome.toJson(),
          }),
        );

        final statusCode = response.statusCode;

        if (statusCode == 200 || statusCode == 201 || statusCode == 409) {
          _entries.removeWhere((item) => item.id == attemptedEntry.id);
          sent++;
          await _persist();
          continue;
        }

        if (statusCode == 400 || statusCode == 422) {
          var reason = 'HTTP $statusCode';

          try {
            final decoded = jsonDecode(response.body);
            if (decoded is Map && decoded['message'] is String) {
              reason = decoded['message'] as String;
            }
          } on FormatException {
            // Keep the HTTP status as the rejection reason.
          }

          final currentIndex = _entries.indexWhere(
            (item) => item.id == attemptedEntry.id,
          );

          if (currentIndex != -1) {
            _entries[currentIndex] = attemptedEntry.copyWith(
              status: EntryStatus.rejected,
              rejectionReason: reason,
            );
          }

          rejectedCount++;
          await _persist();
          continue;
        }

        if (statusCode == 401) {
          authRequired = true;
          break;
        }

        retryAfter = retryDelay(attemptedEntry.attempts);
        break;
      } on http.ClientException {
        retryAfter = retryDelay(attemptedEntry.attempts);
        break;
      }
    }

    return SyncReport(
      sent: sent,
      rejected: rejectedCount,
      remaining: _entries
          .where((entry) => entry.status == EntryStatus.pending)
          .length,
      authRequired: authRequired,
      retryAfter: retryAfter,
    );
  }
}
