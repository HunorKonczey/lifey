import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/barcode_lookup_repository.dart';
import '../domain/barcode_lookup_result.dart';

/// Outcome of a barcode lookup, surfaced to the UI.
sealed class BarcodeLookupState {
  const BarcodeLookupState();
}

class BarcodeLookupIdle extends BarcodeLookupState {
  const BarcodeLookupIdle();
}

class BarcodeLookupLoading extends BarcodeLookupState {
  const BarcodeLookupLoading();
}

class BarcodeLookupFound extends BarcodeLookupState {
  const BarcodeLookupFound(this.result);
  final BarcodeLookupResult result;
}

class BarcodeLookupNotFound extends BarcodeLookupState {
  const BarcodeLookupNotFound();
}

/// The lookup couldn't reach the backend at all (no connectivity, timeout).
class BarcodeLookupOffline extends BarcodeLookupState {
  const BarcodeLookupOffline();
}

/// Drives a single `GET /foods/barcode/{barcode}` call and exposes its
/// outcome. Online-only: no drift read, no outbox entry.
class BarcodeLookupController extends Notifier<BarcodeLookupState> {
  BarcodeLookupRepository get _repo => ref.read(barcodeLookupRepositoryProvider);

  @override
  BarcodeLookupState build() => const BarcodeLookupIdle();

  Future<void> lookup(String barcode) async {
    state = const BarcodeLookupLoading();
    try {
      final result = await _repo.lookupByBarcode(barcode);
      state = BarcodeLookupFound(result);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        state = const BarcodeLookupNotFound();
      } else if (_isConnectivityFailure(e)) {
        state = const BarcodeLookupOffline();
      } else {
        rethrow;
      }
    }
  }

  void reset() => state = const BarcodeLookupIdle();

  bool _isConnectivityFailure(DioException e) {
    return e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout;
  }
}

final barcodeLookupControllerProvider =
    NotifierProvider.autoDispose<BarcodeLookupController, BarcodeLookupState>(
        BarcodeLookupController.new);
