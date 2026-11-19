// How timers and the stopwatch write a length of time. Digits are the
// same in English and Hebrew.

String _two(int n) => n.toString().padLeft(2, '0');

/// "4:59", "1:02:03", rounded up to the second (a timer shows 5:00 right
/// after it starts). Negative (a timer that rang a while ago): "-0:12".
String countdownText(Duration d) {
  if (d.isNegative) return '-${_clock((-d).inSeconds)}';
  return _clock((d.inMilliseconds + 999) ~/ 1000);
}

String _clock(int total) {
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  return h > 0 ? '$h:${_two(m)}:${_two(s)}' : '$m:${_two(s)}';
}

/// "1:23.45", "1:02:03.45": the stopwatch, to the hundredth.
String stopwatchText(Duration d) {
  final ms = d.isNegative ? 0 : d.inMilliseconds;
  final hundredths = (ms % 1000) ~/ 10;
  return '${_clock(ms ~/ 1000)}.${_two(hundredths)}';
}
