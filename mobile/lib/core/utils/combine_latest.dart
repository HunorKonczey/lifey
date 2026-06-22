import 'dart:async';

/// Emits the latest pairing of [a] and [b] whenever either emits, once both
/// have emitted at least one value.
///
/// Used instead of depending on Riverpod's watch-and-rebuild to combine two
/// reactive sources (e.g. an entity table and `pending_operations`):
/// watching a derived provider from inside a `StreamNotifier.build()`
/// disposes the old stream and resubscribes to a new one on every change,
/// and Flutter briefly keeps showing the old stream's last value during
/// that resubscription — which can flash an item back into a list right
/// after it was filtered out. Combining at the stream level instead emits
/// one atomic, already-filtered snapshot per change, with no such gap.
Stream<T> combineLatest2<A, B, T>(Stream<A> a, Stream<B> b, T Function(A a, B b) combine) {
  late final StreamController<T> controller;
  A? lastA;
  B? lastB;
  var hasA = false;
  var hasB = false;
  StreamSubscription<A>? subA;
  StreamSubscription<B>? subB;

  void emit() {
    if (hasA && hasB) controller.add(combine(lastA as A, lastB as B));
  }

  controller = StreamController<T>(
    onListen: () {
      subA = a.listen(
        (value) {
          lastA = value;
          hasA = true;
          emit();
        },
        onError: controller.addError,
      );
      subB = b.listen(
        (value) {
          lastB = value;
          hasB = true;
          emit();
        },
        onError: controller.addError,
      );
    },
    onCancel: () async {
      await subA?.cancel();
      await subB?.cancel();
    },
  );
  return controller.stream;
}

/// Same as [combineLatest2], but for four sources at once. Prefer this over
/// nesting two [combineLatest2] calls (e.g. combining a pair-of-pairs) — each
/// nested controller adds another async hop between a source emitting and
/// the final value reaching listeners, which is enough lag for a UI that
/// assumes an immediate update (e.g. a [Dismissible] expecting its item gone
/// from the very next rebuild) to flash the stale value back into view.
Stream<(A, B, C, D)> combineLatest4<A, B, C, D>(
  Stream<A> a,
  Stream<B> b,
  Stream<C> c,
  Stream<D> d,
) {
  late final StreamController<(A, B, C, D)> controller;
  A? lastA;
  B? lastB;
  C? lastC;
  D? lastD;
  var hasA = false;
  var hasB = false;
  var hasC = false;
  var hasD = false;
  StreamSubscription<A>? subA;
  StreamSubscription<B>? subB;
  StreamSubscription<C>? subC;
  StreamSubscription<D>? subD;

  void emit() {
    if (hasA && hasB && hasC && hasD) {
      controller.add((lastA as A, lastB as B, lastC as C, lastD as D));
    }
  }

  controller = StreamController<(A, B, C, D)>(
    onListen: () {
      subA = a.listen((value) {
        lastA = value;
        hasA = true;
        emit();
      }, onError: controller.addError);
      subB = b.listen((value) {
        lastB = value;
        hasB = true;
        emit();
      }, onError: controller.addError);
      subC = c.listen((value) {
        lastC = value;
        hasC = true;
        emit();
      }, onError: controller.addError);
      subD = d.listen((value) {
        lastD = value;
        hasD = true;
        emit();
      }, onError: controller.addError);
    },
    onCancel: () async {
      await subA?.cancel();
      await subB?.cancel();
      await subC?.cancel();
      await subD?.cancel();
    },
  );
  return controller.stream;
}
