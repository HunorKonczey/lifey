import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/local_db/database_provider.dart';
import 'package:lifey/core/network/dio_client.dart';
import 'package:lifey/features/subscription/application/subscription_controller.dart';
import 'package:lifey/features/subscription/data/purchase_repository.dart';
import 'package:lifey/features/subscription/data/store_purchase_client.dart';
import 'package:lifey/features/subscription/domain/purchase_result.dart';
import 'package:lifey/features/subscription/domain/subscription_product.dart';

class _FakeStorePurchaseClient implements StorePurchaseClient {
  ProductDetailsResponse queryResponse =
      ProductDetailsResponse(productDetails: const [], notFoundIDs: const []);
  final purchaseController = StreamController<List<PurchaseDetails>>.broadcast();
  final buyRequests = <String>[];
  bool restoreCalled = false;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) async => queryResponse;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => purchaseController.stream;

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    buyRequests.add(purchaseParam.productDetails.id);
    return true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {}

  @override
  Future<void> restorePurchases() async {
    restoreCalled = true;
  }

  void emit(PurchaseDetails purchase) => purchaseController.add([purchase]);
}

class _FakeAdapter implements HttpClientAdapter {
  int statusCode = 200;
  final entitlementRequests = <String>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == '/me/entitlements') entitlementRequests.add(options.path);
    if (statusCode >= 400) {
      throw DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: statusCode),
      );
    }
    final body = options.path == '/me/entitlements'
        ? {
            'tier': 'PRO',
            'source': 'APP_STORE',
            'adsEnabled': false,
            'historyDays': null,
            'aiCreditsRemaining': null,
            'trainer': null,
            'expiresAt': null,
            'checkedAt': DateTime.now().toUtc().toIso8601String(),
            'graceUntil': DateTime.now().toUtc().add(const Duration(days: 7)).toIso8601String(),
            'degraded': false,
          }
        : <String, Object?>{};
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

PurchaseDetails _purchase({
  required String productId,
  required PurchaseStatus status,
}) {
  return PurchaseDetails(
    productID: productId,
    verificationData: PurchaseVerificationData(
      localVerificationData: 'local',
      serverVerificationData: 'token-$productId',
      source: 'test',
    ),
    transactionDate: DateTime.now().millisecondsSinceEpoch.toString(),
    status: status,
  )..pendingCompletePurchase = true;
}

void main() {
  // EntitlementRefresher (watched transitively via entitlementRefresherProvider
  // on a successful purchase) registers a WidgetsBindingObserver.
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeStorePurchaseClient client;
  late _FakeAdapter adapter;
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    client = _FakeStorePurchaseClient();
    adapter = _FakeAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      purchaseRepositoryProvider.overrideWithValue(PurchaseRepository(client, dio)),
      dioClientProvider.overrideWithValue(dio),
      appDatabaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);
    addTearDown(db.close);
  });

  test('selectedSubscriptionProductIdProvider defaults to yearly', () {
    expect(container.read(selectedSubscriptionProductIdProvider), yearlySubscriptionProductId);
  });

  test('select() changes the selected plan', () {
    container.read(selectedSubscriptionProductIdProvider.notifier).select(monthlySubscriptionProductId);
    expect(container.read(selectedSubscriptionProductIdProvider), monthlySubscriptionProductId);
  });

  test('buy() marks the product as purchasing and calls through to the store', () async {
    client.queryResponse = ProductDetailsResponse(
      productDetails: [
        ProductDetails(
          id: monthlySubscriptionProductId,
          title: 'Lifey Pro',
          description: 'Lifey Pro subscription',
          price: '\$4.99',
          rawPrice: 4.99,
          currencyCode: 'USD',
        ),
      ],
      notFoundIDs: const [],
    );
    // buy() needs the ProductDetails queryProducts() caches internally
    // (PurchaseParam requires the exact store object, not just an id).
    await container.read(purchaseRepositoryProvider).queryProducts();

    container.listen(subscriptionControllerProvider, (_, __) {});
    await container.read(subscriptionControllerProvider.notifier).buy(monthlySubscriptionProductId);

    expect(container.read(subscriptionControllerProvider).purchasingProductId, monthlySubscriptionProductId);
    expect(client.buyRequests, [monthlySubscriptionProductId]);
  });

  test('restore() calls through to the repository', () async {
    await container.read(subscriptionControllerProvider.notifier).restore();
    expect(client.restoreCalled, isTrue);
  });

  test('a successful purchase clears purchasingProductId, sets lastOutcome, and refreshes entitlements',
      () async {
    container.listen(subscriptionControllerProvider, (_, __) {});
    await pumpEventQueue();

    client.emit(_purchase(productId: monthlySubscriptionProductId, status: PurchaseStatus.purchased));
    await pumpEventQueue();

    final state = container.read(subscriptionControllerProvider);
    expect(state.purchasingProductId, isNull);
    expect(state.lastOutcome, PurchaseOutcome.success);
    // The controller called entitlementRefresherProvider.refreshNow() (D-P3),
    // which hit /me/entitlements.
    expect(adapter.entitlementRequests, isNotEmpty);
  });

  test('a pending purchase keeps purchasingProductId set', () async {
    container.listen(subscriptionControllerProvider, (_, __) {});
    await pumpEventQueue();

    client.emit(_purchase(productId: yearlySubscriptionProductId, status: PurchaseStatus.pending));
    await pumpEventQueue();

    final state = container.read(subscriptionControllerProvider);
    expect(state.purchasingProductId, yearlySubscriptionProductId);
    expect(state.lastOutcome, PurchaseOutcome.pending);
  });

  test('a canceled purchase does not refresh entitlements', () async {
    container.listen(subscriptionControllerProvider, (_, __) {});
    await pumpEventQueue();

    client.emit(_purchase(productId: monthlySubscriptionProductId, status: PurchaseStatus.canceled));
    await pumpEventQueue();

    expect(container.read(subscriptionControllerProvider).lastOutcome, PurchaseOutcome.canceled);
    expect(adapter.entitlementRequests, isEmpty);
  });
}
