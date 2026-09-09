import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:lifey/features/subscription/data/purchase_repository.dart';
import 'package:lifey/features/subscription/data/store_purchase_client.dart';
import 'package:lifey/features/subscription/domain/purchase_result.dart';
import 'package:lifey/features/subscription/domain/subscription_product.dart';

/// [InAppPurchase] has a private constructor and can't be subclassed —
/// [StorePurchaseClient] exists so a fake like this one can stand in for it.
class _FakeStorePurchaseClient implements StorePurchaseClient {
  bool available = true;
  ProductDetailsResponse queryResponse = ProductDetailsResponse(
    productDetails: const [],
    notFoundIDs: const [],
  );
  final purchaseController = StreamController<List<PurchaseDetails>>.broadcast();
  final completedPurchases = <PurchaseDetails>[];
  final buyRequests = <PurchaseParam>[];
  bool restoreCalled = false;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) async => queryResponse;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => purchaseController.stream;

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    buyRequests.add(purchaseParam);
    return true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completedPurchases.add(purchase);
  }

  @override
  Future<void> restorePurchases() async {
    restoreCalled = true;
  }

  void emit(PurchaseDetails purchase) => purchaseController.add([purchase]);
}

/// Replies with [statusCode]/[body] for the store-purchase POST, same fake
/// adapter shape used across this codebase's Dio tests.
class _FakeAdapter implements HttpClientAdapter {
  int statusCode = 200;
  Object? body = <String, Object?>{};
  final requestBodies = <Object?>[];
  final requestPaths = <String>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestBodies.add(options.data);
    requestPaths.add(options.path);
    if (statusCode >= 400) {
      throw DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: statusCode),
      );
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

ProductDetails _productDetails(String id, {String price = '\$4.99', double rawPrice = 4.99}) {
  return ProductDetails(
    id: id,
    title: 'Lifey Pro',
    description: 'Lifey Pro subscription',
    price: price,
    rawPrice: rawPrice,
    currencyCode: 'USD',
  );
}

PurchaseDetails _purchase({
  required String productId,
  required PurchaseStatus status,
  bool pendingComplete = true,
}) {
  return PurchaseDetails(
    productID: productId,
    verificationData: PurchaseVerificationData(
      localVerificationData: 'local-$productId',
      serverVerificationData: 'server-token-$productId',
      source: 'test',
    ),
    transactionDate: DateTime.now().millisecondsSinceEpoch.toString(),
    status: status,
  )..pendingCompletePurchase = pendingComplete;
}

void main() {
  late _FakeStorePurchaseClient client;
  late _FakeAdapter adapter;
  late PurchaseRepository repo;

  setUp(() {
    client = _FakeStorePurchaseClient();
    adapter = _FakeAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;
    repo = PurchaseRepository(client, dio);
  });

  tearDown(() => client.purchaseController.close());

  group('queryProducts', () {
    test('maps ProductDetails to SubscriptionProduct, detecting the period by id', () async {
      client.queryResponse = ProductDetailsResponse(
        productDetails: [
          _productDetails(monthlySubscriptionProductId, price: '\$4.99', rawPrice: 4.99),
          _productDetails(yearlySubscriptionProductId, price: '\$39.99', rawPrice: 39.99),
        ],
        notFoundIDs: const [],
      );

      final products = await repo.queryProducts();

      expect(products, hasLength(2));
      final monthly = products.firstWhere((p) => p.id == monthlySubscriptionProductId);
      expect(monthly.period, SubscriptionPeriod.monthly);
      expect(monthly.formattedPrice, '\$4.99');
      final yearly = products.firstWhere((p) => p.id == yearlySubscriptionProductId);
      expect(yearly.period, SubscriptionPeriod.yearly);
    });

    test('returns an empty list rather than fabricating a product when the store has none',
        () async {
      client.queryResponse = ProductDetailsResponse(productDetails: const [], notFoundIDs: const []);

      final products = await repo.queryProducts();

      expect(products, isEmpty);
    });
  });

  group('buy', () {
    test('throws if queryProducts was never called for this id', () async {
      expect(() => repo.buy(monthlySubscriptionProductId), throwsStateError);
    });

    test('calls buyNonConsumable with the exact ProductDetails the store returned', () async {
      final details = _productDetails(monthlySubscriptionProductId);
      client.queryResponse = ProductDetailsResponse(productDetails: [details], notFoundIDs: const []);
      await repo.queryProducts();

      await repo.buy(monthlySubscriptionProductId);

      expect(client.buyRequests, hasLength(1));
      expect(client.buyRequests.single.productDetails, same(details));
    });
  });

  group('restore', () {
    test('calls restorePurchases on the client', () async {
      await repo.restore();
      expect(client.restoreCalled, isTrue);
    });
  });

  group('watchPurchases', () {
    Future<List<PurchaseResult>> collect(void Function() act) async {
      final results = <PurchaseResult>[];
      final sub = repo.watchPurchases().listen(results.add);
      act();
      await pumpEventQueue();
      await sub.cancel();
      return results;
    }

    test('pending status maps straight through, no server call', () async {
      final results = await collect(
        () => client.emit(_purchase(productId: monthlySubscriptionProductId, status: PurchaseStatus.pending)),
      );

      expect(results, [
        isA<PurchaseResult>()
            .having((r) => r.outcome, 'outcome', PurchaseOutcome.pending)
            .having((r) => r.productId, 'productId', monthlySubscriptionProductId),
      ]);
      expect(adapter.requestPaths, isEmpty);
    });

    test('canceled status maps straight through, no server call', () async {
      final results = await collect(
        () => client.emit(_purchase(productId: monthlySubscriptionProductId, status: PurchaseStatus.canceled)),
      );

      expect(results.single.outcome, PurchaseOutcome.canceled);
      expect(adapter.requestPaths, isEmpty);
    });

    test('error status maps straight through, no server call', () async {
      final results = await collect(
        () => client.emit(_purchase(productId: monthlySubscriptionProductId, status: PurchaseStatus.error)),
      );

      expect(results.single.outcome, PurchaseOutcome.failed);
      expect(adapter.requestPaths, isEmpty);
    });

    test('purchased + 200 verification: posts platform/productId/token, completes, success',
        () async {
      adapter.statusCode = 200;
      final purchase = _purchase(productId: yearlySubscriptionProductId, status: PurchaseStatus.purchased);

      final results = await collect(() => client.emit(purchase));

      expect(results.single.outcome, PurchaseOutcome.success);
      expect(adapter.requestPaths, ['/billing/store-purchase']);
      expect(adapter.requestBodies.single, {
        'platform': 'ANDROID',
        'productId': yearlySubscriptionProductId,
        'purchaseToken': 'server-token-$yearlySubscriptionProductId',
      });
      expect(client.completedPurchases, [purchase]);
    });

    test('restored status is verified and completed exactly like purchased', () async {
      adapter.statusCode = 200;
      final purchase = _purchase(productId: monthlySubscriptionProductId, status: PurchaseStatus.restored);

      final results = await collect(() => client.emit(purchase));

      expect(results.single.outcome, PurchaseOutcome.success);
      expect(client.completedPurchases, [purchase]);
    });

    test('a not-yet-pending purchase is not completed a second time', () async {
      adapter.statusCode = 200;
      final purchase = _purchase(
        productId: monthlySubscriptionProductId,
        status: PurchaseStatus.purchased,
        pendingComplete: false,
      );

      await collect(() => client.emit(purchase));

      expect(client.completedPurchases, isEmpty);
    });

    test('409 SUBSCRIPTION_ALREADY_LINKED: terminal rejection, completed anyway (D-P8)', () async {
      adapter.statusCode = 409;
      final purchase = _purchase(productId: monthlySubscriptionProductId, status: PurchaseStatus.purchased);

      final results = await collect(() => client.emit(purchase));

      expect(results.single.outcome, PurchaseOutcome.terminalRejection);
      expect(client.completedPurchases, [purchase]);
    });

    test('422 INVALID_RECEIPT: terminal rejection, completed anyway (D-P8)', () async {
      adapter.statusCode = 422;
      final purchase = _purchase(productId: monthlySubscriptionProductId, status: PurchaseStatus.purchased);

      final results = await collect(() => client.emit(purchase));

      expect(results.single.outcome, PurchaseOutcome.terminalRejection);
      expect(client.completedPurchases, [purchase]);
    });

    test(
        'a server failure between purchase and verification (simulating a crash) leaves the '
        'transaction uncompleted (D-P8)', () async {
      adapter.statusCode = 500;
      final purchase = _purchase(productId: monthlySubscriptionProductId, status: PurchaseStatus.purchased);

      final results = await collect(() => client.emit(purchase));

      expect(results.single.outcome, PurchaseOutcome.verificationFailed);
      // The transaction stays pending — never completed — so the store
      // re-delivers it on the next launch, where this same handling runs
      // again with (hopefully) a live connection.
      expect(client.completedPurchases, isEmpty);
    });

    test('an offline/connection error is handled the same as any other verification failure',
        () async {
      final options = RequestOptions(path: '/billing/store-purchase');
      // A connection error never reaches _FakeAdapter.fetch's statusCode
      // branch, so this exercises DioExceptionType.connectionError directly
      // via a client override rather than the shared adapter.
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = _ThrowingAdapter(
          DioException.connectionError(requestOptions: options, reason: 'offline'),
        );
      final offlineRepo = PurchaseRepository(client, dio);
      final purchase = _purchase(productId: monthlySubscriptionProductId, status: PurchaseStatus.purchased);

      final results = <PurchaseResult>[];
      final sub = offlineRepo.watchPurchases().listen(results.add);
      client.emit(purchase);
      await pumpEventQueue();
      await sub.cancel();

      expect(results.single.outcome, PurchaseOutcome.verificationFailed);
      expect(client.completedPurchases, isEmpty);
    });

    test('multiple purchases in one stream batch each get their own result', () async {
      final results = <PurchaseResult>[];
      final sub = repo.watchPurchases().listen(results.add);

      client.purchaseController.add([
        _purchase(productId: monthlySubscriptionProductId, status: PurchaseStatus.pending),
        _purchase(productId: yearlySubscriptionProductId, status: PurchaseStatus.canceled),
      ]);
      await pumpEventQueue();
      await sub.cancel();

      expect(results, hasLength(2));
      expect(results[0].productId, monthlySubscriptionProductId);
      expect(results[0].outcome, PurchaseOutcome.pending);
      expect(results[1].productId, yearlySubscriptionProductId);
      expect(results[1].outcome, PurchaseOutcome.canceled);
    });
  });
}

class _ThrowingAdapter implements HttpClientAdapter {
  _ThrowingAdapter(this._error);
  final DioException _error;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    throw _error;
  }
}
