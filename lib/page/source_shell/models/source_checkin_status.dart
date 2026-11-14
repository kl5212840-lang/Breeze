import 'package:freezed_annotation/freezed_annotation.dart';

part 'source_checkin_status.freezed.dart';

/// Confirmed receipts are scoped to one account and one source day (UTC+8).
/// Null means unknown; it must not be presented as a confirmed refusal.
@freezed
abstract class SourceCheckinStatus with _$SourceCheckinStatus {
  const SourceCheckinStatus._();

  const factory SourceCheckinStatus({
    required String accountId,
    required String date,
    bool? checkedIn,
  }) = _SourceCheckinStatus;

  static SourceCheckinStatus forAccount(String accountId, {DateTime? now}) =>
      SourceCheckinStatus(
        accountId: accountId.trim(),
        date: sourceCheckinDate(now ?? DateTime.now()),
      );

  /// Pass profile extern or a check-in result's data. A null payload also
  /// handles refresh failures without discarding an existing receipt.
  /// The caller supplies the *current* identity, never the request's old one.
  SourceCheckinStatus merge(
    Map<String, dynamic>? payload, {
    required String accountId,
    DateTime? now,
  }) {
    final current = SourceCheckinStatus.forAccount(accountId, now: now);
    final retained =
        current.accountId.isNotEmpty &&
        this.accountId == current.accountId &&
        date == current.date &&
        checkedIn == true;
    final confirmed =
        current.accountId.isNotEmpty &&
        payload?['accountId'] == current.accountId &&
        payload?['checkedInDate'] == current.date &&
        payload?['checkedIn'] == true &&
        payload?['ok'] != false;
    return current.copyWith(checkedIn: retained || confirmed ? true : null);
  }
}

String sourceCheckinDate(DateTime now) {
  final day = now.toUtc().add(const Duration(hours: 8));
  return '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
}
