/// Formats a byte count for download and device storage UI in decimal units.
/// A partial inventory rounds down so its stated lower bound stays true.
String downloadByteAmount(int bytes, {bool lowerBound = false}) {
  if (bytes < 1000) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var index = 0;
  var divisor = 1000;
  while (index < units.length - 1 && bytes >= divisor * 1000) {
    divisor *= 1000;
    index++;
  }
  int tenths() =>
      bytes ~/ (divisor ~/ 10) +
      (!lowerBound && bytes % (divisor ~/ 10) >= divisor ~/ 20 ? 1 : 0);
  var amount = tenths();
  if (amount == 10000 && index < units.length - 1) {
    divisor *= 1000;
    index++;
    amount = tenths();
  }
  return '${amount ~/ 10}.${amount % 10} ${units[index]}';
}
