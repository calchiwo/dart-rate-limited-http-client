import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'rate_limiter.dart';
import 'retry_policy.dart';

class HttpClient {
  final String baseUrl;
  final Map<String, String> defaultHeaders;
  final Duration timeout;
  final RateLimiter rateLimiter;
  final RetryPolicy retryPolicy;

  HttpClient({
    required this.baseUrl,
    this.defaultHeaders = const {},
    this.timeout = const Duration(seconds: 30),
    required this.rateLimiter,
    required this.retryPolicy,
  });

  Future<HttpResponse> get(
    String path, {
    Map<String, String>? headers,
  }) async {
    return _execute('GET', path, headers: headers);
  }

  Future<HttpResponse> post(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    return _execute('POST', path, headers: headers, body: body);
  }

  Future<HttpResponse> _execute(
    String method,
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    await rateLimiter.acquire();

    final uri = Uri.parse('$baseUrl$path');
    final mergedHeaders = {...defaultHeaders, ...?headers};

    return retryPolicy.execute(() async {
      return _makeRequest(method, uri, mergedHeaders, body);
    });
  }

  Future<HttpResponse> _makeRequest(
    String method,
    Uri uri,
    Map<String, String> headers,
    Object? body,
  ) async {
    final client = HttpClient();
    try {
      final request = await client.openUrl(method, uri).timeout(timeout);

      headers.forEach((key, value) {
        request.headers.set(key, value);
      });

      if (body != null) {
        final jsonBody = json.encode(body);
        request.headers.set('Content-Type', 'application/json');
        request.write(jsonBody);
      }

      final response = await request.close().timeout(timeout);
      final responseBody = await response.transform(utf8.decoder).join();

      return HttpResponse(
        statusCode: response.statusCode,
        body: responseBody,
        headers: response.headers.value,
      );
    } on SocketException catch (e) {
      throw HttpClientException('Network error: ${e.message}');
    } on TimeoutException {
      throw HttpClientException('Request timeout');
    } finally {
      client.close();
    }
  }
}

class HttpResponse {
  final int statusCode;
  final String body;
  final Map<String, List<String>> headers;

  HttpResponse({
    required this.statusCode,
    required this.body,
    required this.headers,
  });

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
  bool get isClientError => statusCode >= 400 && statusCode < 500;
  bool get isServerError => statusCode >= 500 && statusCode < 600;
}

class HttpClientException implements Exception {
  final String message;
  HttpClientException(this.message);

  @override
  String toString() => message;
}