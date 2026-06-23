import Flutter
import HealthKit
import Foundation

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
    private static let logTag = "[HealthWorkoutObserver]"
    private static let eventChannelName = "com.lifey.health/workout_events"
    private static let processedWorkoutsKey = "com.lifey.health.processedWorkoutUUIDs"
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
        NSLog("%@ initialized, event channel registered", Self.logTag)
    }

    /// Registers the background observer. Safe to call repeatedly — only
    /// executes the query once. No-ops if HealthKit isn't available (e.g.
    /// simulator) or permission was never granted (the query then simply
    /// never fires).
    func startObserving() {
        guard observerQuery == nil else {
            NSLog("%@ startObserving: already observing, skipping", Self.logTag)
            return
        }
        guard HKHealthStore.isHealthDataAvailable() else {
            NSLog("%@ startObserving: HealthKit not available on this device", Self.logTag)
            return
        }

        let query = HKObserverQuery(sampleType: workoutType, predicate: nil) { [weak self] _, completionHandler, error in
            defer { completionHandler() }
            if let error = error {
                NSLog("%@ observer query fired with error: %@", Self.logTag, error.localizedDescription)
                return
            }
            NSLog("%@ observer query fired — checking for new strength workouts", Self.logTag)
            self?.fetchAndForwardNewStrengthWorkouts()
        }
        observerQuery = query
        healthStore.execute(query)
        NSLog("%@ HKObserverQuery executed", Self.logTag)

        healthStore.enableBackgroundDelivery(for: workoutType, frequency: .immediate) { success, error in
            if let error = error {
                NSLog("%@ enableBackgroundDelivery failed: %@", Self.logTag, error.localizedDescription)
            } else {
                NSLog("%@ enableBackgroundDelivery succeeded=%@", Self.logTag, success ? "true" : "false")
            }
        }
    }

    // MARK: FlutterStreamHandler

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        NSLog("%@ onListen — Dart attached, flushing %d pending payload(s)", Self.logTag, pendingPayloads.count)
        eventSink = events
        for payload in pendingPayloads {
            events(payload)
        }
        pendingPayloads.removeAll()
        startObserving()
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        NSLog("%@ onCancel — Dart detached", Self.logTag)
        eventSink = nil
        return nil
    }

    // MARK: - Fetching newly-finished strength workouts

    private func fetchAndForwardNewStrengthWorkouts() {
        let traditional = HKQuery.predicateForWorkouts(with: .traditionalStrengthTraining)
        let functional = HKQuery.predicateForWorkouts(with: .functionalStrengthTraining)
        let predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [traditional, functional])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: 20, sortDescriptors: [sort]) { [weak self] _, samples, error in
            guard let self = self else { return }
            if let error = error {
                NSLog("%@ sample query failed: %@", Self.logTag, error.localizedDescription)
                return
            }
            let workouts = samples as? [HKWorkout] ?? []
            NSLog("%@ sample query returned %d strength workout(s)", Self.logTag, workouts.count)
            let unseen = workouts.filter { !self.isProcessed($0.uuid) }
            NSLog("%@ %d of those are unseen (new)", Self.logTag, unseen.count)
            for workout in unseen {
                self.markProcessed(workout.uuid)
                self.processWorkout(workout)
            }
        }
        healthStore.execute(query)
    }

    private func processWorkout(_ workout: HKWorkout) {
        NSLog("%@ processing workout %@ (start=%@ end=%@)", Self.logTag, workout.uuid.uuidString,
              "\(workout.startDate)", "\(workout.endDate)")
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
        let query = HKStatisticsQuery(quantityType: quantityType, quantitySamplePredicate: predicate, options: option) { _, statistics, error in
            if let error = error {
                NSLog("%@ statistics query for %@ failed: %@", Self.logTag, identifier.rawValue, error.localizedDescription)
            }
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
            NSLog("%@ sending payload for %@ to Dart (calories=%@ avgHR=%@)", Self.logTag,
                  workout.uuid.uuidString, "\(activeCalories ?? -1)", "\(averageHeartRate ?? -1)")
            eventSink(payload)
        } else {
            NSLog("%@ no active listener — buffering payload for %@ until Dart attaches", Self.logTag,
                  workout.uuid.uuidString)
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
