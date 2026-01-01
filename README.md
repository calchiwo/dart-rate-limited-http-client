# Rate-Limited HTTP Client

A minimal, production-ready HTTP client for Dart with built-in rate limiting and retry logic.

## Features

- **Rate Limiting**: Token bucket algorithm prevents overwhelming downstream services
- **Automatic Retries**: Exponential backoff with jitter for transient failures
- **Configurable**: Tune timeout, rate limits, and retry behavior per client
- **Framework-Free**: Pure Dart, no dependencies beyond `dart:io`

## Usage
```dart
import 'client.dart';
import 'rate_limiter.dart';
import 'retry_policy.dart';

void main() async {
  final client = HttpClient(
    baseUrl: 'https://api.example.com',
    defaultHeaders: {'Authorization': 'Bearer token'},
    timeout: Duration(seconds: 10),
    rateLimiter: RateLimiter(requestsPerSecond: 5),
    retryPolicy: RetryPolicy(maxAttempts: 3),
  );

  final response = await client.get('/users/123');
  
  if (response.isSuccess) {
    print(response.body);
  }
}
```

## API

### HttpClient
```dart
HttpClient({
  required String baseUrl,
  Map<String, String> defaultHeaders,
  Duration timeout,
  required RateLimiter rateLimiter,
  required RetryPolicy retryPolicy,
})
```

**Methods:**
- `Future<HttpResponse> get(String path, {Map<String, String>? headers})`
- `Future<HttpResponse> post(String path, {Map<String, String>? headers, Object? body})`

### RateLimiter
```dart
RateLimiter({required int requestsPerSecond})
```

Blocks requests exceeding the configured rate. Uses a sliding window token bucket.

### RetryPolicy
```dart
RetryPolicy({
  int maxAttempts = 3,
  Duration initialDelay = Duration(milliseconds: 100),
  double backoffMultiplier = 2.0,
  Duration maxDelay = Duration(seconds: 10),
})
```

Retries on:
- Network errors (socket, timeout)
- 5xx server errors

Does not retry on:
- 4xx client errors
- Successful responses

## Design Decisions

**Three files, three responsibilities**: Each file has a single, well-defined purpose. No inheritance hierarchies or abstract factories.

**Deterministic rate limiting**: The token bucket refills on a fixed schedule, not on arbitrary request patterns.

**Jittered backoff**: Adds randomness to retry delays to prevent thundering herd problems.

**No global state**: Every component is explicitly instantiated and injected.

**Fail fast on 4xx**: Client errors indicate bugs or invalid requests that won't succeed on retry.

## Testing

The client handles real-world failure modes:
- Network timeouts and socket errors
- Rate limit bursts and sustained load
- Transient server failures with eventual success
- Permanent failures that should not be retried

## License

[MIT LICENSE](LICENSE)

## Authour

Caleb Wodi (https://github.com/calchiwo)
