import 'dart:async';

class RateLimiter {
  final int requestsPerSecond;
  final List<DateTime> _requestTimestamps = [];
  final _queue = <Completer<void>>[];

  RateLimiter({required this.requestsPerSecond});

  Future<void> acquire() async {
    final now = DateTime.now();
    _cleanupOldTimestamps(now);

    if (_requestTimestamps.length < requestsPerSecond) {
      _requestTimestamps.add(now);
      return;
    }

    final completer = Completer<void>();
    _queue.add(completer);

    final oldestTimestamp = _requestTimestamps.first;
    final nextAvailableTime = oldestTimestamp.add(const Duration(seconds: 1));
    final delay = nextAvailableTime.difference(now);

    if (delay.isNegative) {
      _requestTimestamps.removeAt(0);
      _requestTimestamps.add(now);
      completer.complete();
    } else {
      Timer(delay, () {
        _requestTimestamps.removeAt(0);
        _requestTimestamps.add(DateTime.now());
        completer.complete();
        _processQueue();
      });
    }

    return completer.future;
  }

  void _cleanupOldTimestamps(DateTime now) {
    final cutoff = now.subtract(const Duration(seconds: 1));
    _requestTimestamps.removeWhere((timestamp) => timestamp.isBefore(cutoff));
  }

  void _processQueue() {
    if (_queue.isEmpty) return;

    final now = DateTime.now();
    _cleanupOldTimestamps(now);

    while (_queue.isNotEmpty && _requestTimestamps.length < requestsPerSecond) {
      final completer = _queue.removeAt(0);
      _requestTimestamps.add(now);
      completer.complete();
    }
  }
}