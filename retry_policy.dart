import 'dart:async';
import 'dart:math';

class RetryPolicy {
  final int maxAttempts;
  final Duration initialDelay;
  final double backoffMultiplier;
  final Duration maxDelay;
  final Random _random;

  RetryPolicy({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(milliseconds: 100),
    this.backoffMultiplier = 2.0,
    this.maxDelay = const Duration(seconds: 10),
    Random? random,
  }) : _random = random ?? Random();

  Future<T> execute<T>(Future<T> Function() operation) async {
    int attempt = 0;
    Duration delay = initialDelay;

    while (true) {
      attempt++;

      try {
        return await operation();
      } catch (e) {
        if (attempt >= maxAttempts) {
          rethrow;
        }

        if (!_shouldRetry(e)) {
          rethrow;
        }

        final jitter = _random.nextDouble() * 0.3;
        final actualDelay = delay * (1.0 + jitter);
        final cappedDelay =
            actualDelay > maxDelay ? maxDelay : actualDelay;

        await Future.delayed(cappedDelay);

        delay = Duration(
          microseconds: (delay.inMicroseconds * backoffMultiplier).round(),
        );
      }
    }
  }

  bool _shouldRetry(dynamic error) {
    if (error.toString().contains('Network error')) return true;
    if (error.toString().contains('timeout')) return true;

    if (error is StateError) {
      final message = error.toString();
      if (message.contains('statusCode')) {
        final match = RegExp(r'statusCode: (\d+)').firstMatch(message);
        if (match != null) {
          final statusCode = int.parse(match.group(1)!);
          return statusCode >= 500 && statusCode < 600;
        }
      }
    }

    return false;
  }
}