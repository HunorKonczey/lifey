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

/// Maps each [source] event to a new stream via [project], emitting only
/// from the most recently projected stream — the previous one is cancelled
/// as soon as a new [source] event arrives.
///
/// Used for paged joins where the page's id set ([source]) can itself change
/// (e.g. a meal entering/leaving the window): the join query depends on the
/// current id set, so the inner stream must be rebuilt and the stale one
/// torn down whenever that set changes.
Stream<T> switchMap<S, T>(Stream<S> source, Stream<T> Function(S value) project) {
  late final StreamController<T> controller;
  StreamSubscription<S>? sourceSub;
  StreamSubscription<T>? innerSub;

  controller = StreamController<T>(
    onListen: () {
      sourceSub = source.listen(
        (value) {
          innerSub?.cancel();
          innerSub = project(value).listen(controller.add, onError: controller.addError);
        },
        onError: controller.addError,
      );
    },
    onCancel: () async {
      await innerSub?.cancel();
      await sourceSub?.cancel();
    },
  );
  return controller.stream;
}
