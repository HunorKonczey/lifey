import 'package:dio/dio.dart';

/// Calls [onGateRejection] whenever a response comes back 402 or 403 — the
/// generic signal that a billing gate was hit
/// (`docs/landing_page/67-mobile-free-pro-plan.md` D-P3) — without this
/// class knowing anything about entitlements itself. `dio_client.dart` wires
/// the callback to `gateRejectionProvider` (`session_events.dart`), which
/// `core/entitlements`' `EntitlementRefresher` listens to.
class GateRejectionInterceptor extends Interceptor {
  GateRejectionInterceptor({required void Function() onGateRejection})
      : _onGateRejection = onGateRejection;

  final void Function() _onGateRejection;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final statusCode = err.response?.statusCode;
    if (statusCode == 402 || statusCode == 403) _onGateRejection();
    handler.next(err);
  }
}
