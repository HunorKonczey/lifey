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
    private static let eventChannelName = "com.lifey.health/workout_events"
    private static let processedWorkoutsKey = "com.lifey.health.processedWorkoutUUIDs"
    private static let maxProcessedWorkoutsRemembered = 200

    private let healthStore = HKHealthStore()
    private let workoutType = HKObjectType.workoutType()
    private var eventSink: FlutterEventSink?
    private var observerQuery: HKObserverQuery?

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
            defer { completionHandler() }
            guard error == nil else { return }
            self?.fetchAndForwardNewStrengthWorkouts()
        }
        observerQuery = query
        healthStore.execute(query)
        healthStore.enableBackgroundDelivery(for: workoutType, frequency: .immediate) { _, _ in }
    }

    // MARK: FlutterStreamHandler

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        startObserving()
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
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
            guard let self = self, error == nil, let workouts = samples as? [HKWorkout] else { return }
            for workout in workouts where !self.isProcessed(workout.uuid) {
                self.markProcessed(workout.uuid)
                self.processWorkout(workout)
            }
        }
        healthStore.execute(query)
    }

    private func processWorkout(_ workout: HKWorkout) {
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
        eventSink?(payload)
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
