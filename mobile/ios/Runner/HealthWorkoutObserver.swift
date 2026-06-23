import Flutter
import HealthKit
import UIKit

/// Bridges Apple HealthKit strength-workout completion events to Dart.
///
/// HealthKit gives no live "workout started" signal for workouts logged by
/// another app (e.g. Apple Fitness) — `HKObserverQuery` only fires once the
/// finished `HKWorkout` sample has been written. We use that, combined with
/// `enableBackgroundDelivery`, to wake the app and push the completed
/// workout's data (active calories, average heart rate) to Dart over an
/// event channel. This class is read-only — it never writes back to
/// HealthKit or touches app data; Dart decides what to do with the event
/// (see docs/16-apple-health-integration-plan.md, Phase 1).
final class HealthWorkoutObserver: NSObject, FlutterStreamHandler {
    private static let eventChannelName = "com.lifey.health/workout_events"
    // Versioned: an earlier bug could mark a workout processed before it was
    // actually delivered to Dart (fixed by the pendingPayloads buffer below),
    // permanently stranding UUIDs under the unversioned key. Bump again if
    // the dedup semantics ever change in a way that invalidates old entries.
    private static let processedWorkoutsKey = "com.lifey.health.processedWorkoutUUIDs.v2"
    private static let maxProcessedWorkoutsRemembered = 200

    private let healthStore = HKHealthStore()
    private let workoutType = HKObjectType.workoutType()
    private var eventSink: FlutterEventSink?
    private var observerQuery: HKObserverQuery?

    /// Events computed while no Dart listener was attached yet (e.g. the app
    /// was woken in the background specifically for this HealthKit delivery,
    /// and the Flutter engine/EventChannel listener hasn't finished spinning
    /// up). Flushed once [onListen] supplies a sink — without this, an event
    /// computed with a nil [eventSink] would be silently dropped and, since
    /// it's already marked processed, never redelivered.
    private var pendingPayloads: [[String: Any?]] = []

    init(messenger: FlutterBinaryMessenger) {
        super.init()
        let channel = FlutterEventChannel(name: Self.eventChannelName, binaryMessenger: messenger)
        channel.setStreamHandler(self)
    }

    /// Registers the background observer. Safe to call repeatedly — only
    /// executes the query once. No-ops if HealthKit isn't available (e.g.
    /// simulator) or permission was never granted (the query then simply
    /// never fires).
    func startObserving() {
        guard observerQuery == nil, HKHealthStore.isHealthDataAvailable() else { return }

        let query = HKObserverQuery(sampleType: workoutType, predicate: nil) { [weak self] _, completionHandler, error in
            guard let self = self else {
                completionHandler()
                return
            }
            guard error == nil else {
                completionHandler()
                return
            }
            // Don't call completionHandler() until the whole async chain below
            // (fetch -> stats -> send to Dart) actually finishes. Calling it
            // early tells iOS "I'm done, you can suspend me now" — and it may
            // do exactly that mid-chain, before the payload ever reaches Dart
            // or the notification gets shown. beginBackgroundTask buys extra
            // wall-clock time for the full round trip, including the Dart-side
            // notification display.
            self.runWithExtendedBackgroundTime { done in
                self.fetchAndForwardNewStrengthWorkouts {
                    completionHandler()
                    done()
                }
            }
        }
        observerQuery = query
        healthStore.execute(query)
        healthStore.enableBackgroundDelivery(for: workoutType, frequency: .immediate) { _, _ in }
    }

    /// Requests a short extension of background execution time (Apple grants
    /// a budget on the order of seconds-to-tens-of-seconds; exact amount is
    /// not documented/guaranteed) so the async work in [work] — including the
    /// round trip into Dart to show the local notification — has a real
    /// chance to finish before the process is suspended again.
    private func runWithExtendedBackgroundTime(_ work: @escaping (_ done: @escaping () -> Void) -> Void) {
        var taskId = UIBackgroundTaskIdentifier.invalid
        var didFinish = false
        let finish = {
            guard !didFinish else { return }
            didFinish = true
            if taskId != .invalid {
                UIApplication.shared.endBackgroundTask(taskId)
            }
        }
        taskId = UIApplication.shared.beginBackgroundTask(withName: "HealthWorkoutObserver.fire") {
            finish()
        }
        work { finish() }
    }

    // MARK: FlutterStreamHandler

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        for payload in pendingPayloads {
            events(payload)
        }
        pendingPayloads.removeAll()
        startObserving()
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    // MARK: - Fetching newly-finished strength workouts

    private func fetchAndForwardNewStrengthWorkouts(completion: @escaping () -> Void) {
        let traditional = HKQuery.predicateForWorkouts(with: .traditionalStrengthTraining)
        let functional = HKQuery.predicateForWorkouts(with: .functionalStrengthTraining)
        let predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [traditional, functional])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: 20, sortDescriptors: [sort]) { [weak self] _, samples, error in
            guard let self = self, error == nil, let workouts = samples as? [HKWorkout] else {
                completion()
                return
            }
            let unseen = workouts.filter { !self.isProcessed($0.uuid) }
            guard !unseen.isEmpty else {
                completion()
                return
            }

            let group = DispatchGroup()
            for workout in unseen {
                self.markProcessed(workout.uuid)
                group.enter()
                self.processWorkout(workout) { group.leave() }
            }
            group.notify(queue: .main, execute: completion)
        }
        healthStore.execute(query)
    }

    private func processWorkout(_ workout: HKWorkout, completion: @escaping () -> Void) {
        let group = DispatchGroup()
        var activeCalories: Double?
        var averageHeartRate: Double?

        group.enter()
        queryStatistic(
            identifier: .activeEnergyBurned, start: workout.startDate, end: workout.endDate,
            option: .cumulativeSum, unit: .kilocalorie()
        ) { value in
            activeCalories = value
            group.leave()
        }

        group.enter()
        queryStatistic(
            identifier: .heartRate, start: workout.startDate, end: workout.endDate,
            option: .discreteAverage, unit: HKUnit.count().unitDivided(by: .minute())
        ) { value in
            averageHeartRate = value
            group.leave()
        }

        group.notify(queue: .main) {
            self.send(workout: workout, activeCalories: activeCalories, averageHeartRate: averageHeartRate)
            completion()
        }
    }

    private func queryStatistic(
        identifier: HKQuantityTypeIdentifier, start: Date, end: Date,
        option: HKStatisticsOptions, unit: HKUnit, completion: @escaping (Double?) -> Void
    ) {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            completion(nil)
            return
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: quantityType, quantitySamplePredicate: predicate, options: option) { _, statistics, _ in
            let value = option.contains(.cumulativeSum)
                ? statistics?.sumQuantity()?.doubleValue(for: unit)
                : statistics?.averageQuantity()?.doubleValue(for: unit)
            completion(value)
        }
        healthStore.execute(query)
    }

    private func send(workout: HKWorkout, activeCalories: Double?, averageHeartRate: Double?) {
        let formatter = ISO8601DateFormatter()
        let payload: [String: Any?] = [
            "uuid": workout.uuid.uuidString,
            "startDate": formatter.string(from: workout.startDate),
            "endDate": formatter.string(from: workout.endDate),
            "activeCalories": activeCalories,
            "averageHeartRate": averageHeartRate,
        ]
        if let eventSink = eventSink {
            eventSink(payload)
        } else {
            pendingPayloads.append(payload)
        }
    }

    // MARK: - Dedup (HealthKit re-delivers every workout on every observer fire,
    // not just the new one, so we must remember which UUIDs we already sent)

    private func isProcessed(_ uuid: UUID) -> Bool {
        processedUUIDs().contains(uuid.uuidString)
    }

    private func markProcessed(_ uuid: UUID) {
        var uuids = processedUUIDs()
        uuids.append(uuid.uuidString)
        if uuids.count > Self.maxProcessedWorkoutsRemembered {
            uuids.removeFirst(uuids.count - Self.maxProcessedWorkoutsRemembered)
        }
        UserDefaults.standard.set(uuids, forKey: Self.processedWorkoutsKey)
    }

    private func processedUUIDs() -> [String] {
        UserDefaults.standard.stringArray(forKey: Self.processedWorkoutsKey) ?? []
    }
}
