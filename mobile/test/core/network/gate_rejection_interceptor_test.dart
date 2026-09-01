import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/network/gate_rejection_interceptor.dart';

/// Overrides [next] instead of calling through to the real
/// [ErrorInterceptorHandler.next] — which completes an internal [Completer]
/// that nothing in this test ever listens to, so calling it for real would
/// surface as an unhandled async error.
class _TrackingHandler extends ErrorInterceptorHandler {
  bool nextCalled = false;

  @override
  void next(DioException error) {
    nextCalled = true;
  }
}

void main() {
  late int callCount;
  late GateRejectionInterceptor interceptor;

  setUp(() {
    callCount = 0;
    interceptor = GateRejectionInterceptor(onGateRejection: () => callCount++);
  });

  DioException errorWithStatus(int? statusCode) {
    final options = RequestOptions(path: '/whatever');
    return DioException(
      requestOptions: options,
      response:
          statusCode == null ? null : Response(requestOptions: options, statusCode: statusCode),
    );
  }

  test('calls onGateRejection for a 402', () {
    interceptor.onError(errorWithStatus(402), _TrackingHandler());
    expect(callCount, 1);
  });

  test('calls onGateRejection for a 403', () {
    interceptor.onError(errorWithStatus(403), _TrackingHandler());
    expect(callCount, 1);
  });

  test('does not call onGateRejection for a 401', () {
    interceptor.onError(errorWithStatus(401), _TrackingHandler());
    expect(callCount, 0);
  });

  test('does not call onGateRejection for a 500', () {
    interceptor.onError(errorWithStatus(500), _TrackingHandler());
    expect(callCount, 0);
  });

  test('does not call onGateRejection when there is no response at all (e.g. offline)', () {
    interceptor.onError(errorWithStatus(null), _TrackingHandler());
    expect(callCount, 0);
  });

  test('always forwards the error to the next interceptor, never swallows it', () {
    final handler = _TrackingHandler();
    interceptor.onError(errorWithStatus(402), handler);
    expect(handler.nextCalled, isTrue);
  });
}
