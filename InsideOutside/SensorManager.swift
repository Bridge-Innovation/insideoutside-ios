//
//  SensorManager.swift
//  InsideOutside
//
//  Created by Sarah Gilmore on 2/24/26.
import Foundation
import CoreLocation
import CoreMotion
import Network
import HealthKit
import Combine

/// Holds a snapshot of all sensor readings at a point in time
struct SensorSnapshot: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    
    // CoreLocation
    let latitude: Double?
    let longitude: Double?
    let horizontalAccuracy: Double?  // KEY SIGNAL: low = outdoors, high = indoors
    let verticalAccuracy: Double?
    let altitude: Double?
    let floor: Int?                  // CLFloor - nil outdoors, sometimes set indoors
    let speed: Double?
    let course: Double?
    
    // Barometer (CMAltimeter)
    let relativeAltitude: Double?    // Meters of change since start
    let pressure: Double?            // kPa
    
    // Magnetometer
    let magX: Double?
    let magY: Double?
    let magZ: Double?
    let magMagnitude: Double?        // Total field strength
    
    // Network
    let networkPathType: String      // "wifi", "cellular", "wired", "loopback", "other"
    let isExpensive: Bool            // True = cellular
    let isConstrained: Bool          // True = low data mode
    
    // HealthKit
    let timeInDaylight: Double?      // Cumulative minutes today from Apple's sensor
    
    // Ground truth
    let userLabel: String            // "INSIDE", "OUTSIDE", "TRANSIT", or "UNKNOWN"
    
    init(timestamp: Date, latitude: Double?, longitude: Double?, horizontalAccuracy: Double?,
         verticalAccuracy: Double?, altitude: Double?, floor: Int?, speed: Double?, course: Double?,
         relativeAltitude: Double?, pressure: Double?, magX: Double?, magY: Double?, magZ: Double?,
         magMagnitude: Double?, networkPathType: String, isExpensive: Bool, isConstrained: Bool,
         timeInDaylight: Double?, userLabel: String) {
        self.id = UUID()
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.horizontalAccuracy = horizontalAccuracy
        self.verticalAccuracy = verticalAccuracy
        self.altitude = altitude
        self.floor = floor
        self.speed = speed
        self.course = course
        self.relativeAltitude = relativeAltitude
        self.pressure = pressure
        self.magX = magX
        self.magY = magY
        self.magZ = magZ
        self.magMagnitude = magMagnitude
        self.networkPathType = networkPathType
        self.isExpensive = isExpensive
        self.isConstrained = isConstrained
        self.timeInDaylight = timeInDaylight
        self.userLabel = userLabel
    }
}

class SensorManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    
    // MARK: - Published state for the UI
    @Published var currentLabel: String = "UNKNOWN"
    @Published var isLogging: Bool = false
    
    // Latest readings
    @Published var horizontalAccuracy: Double?
    @Published var verticalAccuracy: Double?
    @Published var altitude: Double?
    @Published var floor: Int?
    @Published var latitude: Double?
    @Published var longitude: Double?
    @Published var speed: Double?
    
    @Published var pressure: Double?
    @Published var relativeAltitude: Double?
    
    @Published var magX: Double?
    @Published var magY: Double?
    @Published var magZ: Double?
    @Published var magMagnitude: Double?
    
    @Published var networkType: String = "unknown"
    @Published var isExpensive: Bool = false
    
    // HealthKit
    @Published var timeInDaylight: Double?  // Cumulative minutes today
    @Published var healthKitAuthorized: Bool = false
    
    // Log
    @Published var snapshots: [SensorSnapshot] = []
    @Published var logCount: Int = 0
    
    // MARK: - Sensors
    private let locationManager = CLLocationManager()
    private let altimeter = CMAltimeter()
    private let motionManager = CMMotionManager()
    private let pathMonitor = NWPathMonitor()
    private let pathQueue = DispatchQueue(label: "NetworkPathMonitor")
    private let healthStore = HKHealthStore()
    
    // Logging timer
    private var logTimer: Timer?
    
    // HealthKit polling timer (less frequent — every 30s)
    private var healthTimer: Timer?
    
    // Auto-save
    private var saveCounter: Int = 0
    private let saveEveryN = 12  // Auto-save every 60 seconds (12 x 5s)
    
    private var savePath: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("sensor_snapshots.json")
    }
    
    override init() {
        super.init()
        loadFromDisk()
        setupLocation()
        setupAltimeter()
        setupMagnetometer()
        setupNetworkMonitor()
        requestHealthKitAccess()
    }
    
    // MARK: - Setup
    
    private func setupLocation() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        #if !targetEnvironment(simulator)
        locationManager.allowsBackgroundLocationUpdates = true
        #endif
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.showsBackgroundLocationIndicator = true
        locationManager.requestAlwaysAuthorization()
    }
    
    private func setupAltimeter() {
        guard CMAltimeter.isRelativeAltitudeAvailable() else {
            print("⚠️ Altimeter not available")
            return
        }
    }
    
    private func setupMagnetometer() {
        guard motionManager.isMagnetometerAvailable else {
            print("⚠️ Magnetometer not available")
            return
        }
        motionManager.magnetometerUpdateInterval = 1.0
    }
    
    private func setupNetworkMonitor() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.updateNetworkPath(path)
            }
        }
        pathMonitor.start(queue: pathQueue)
    }
    
    private func updateNetworkPath(_ path: NWPath) {
        if path.usesInterfaceType(.wifi) {
            networkType = "wifi"
        } else if path.usesInterfaceType(.cellular) {
            networkType = "cellular"
        } else if path.usesInterfaceType(.wiredEthernet) {
            networkType = "wired"
        } else if path.usesInterfaceType(.loopback) {
            networkType = "loopback"
        } else {
            networkType = "other"
        }
        isExpensive = path.isExpensive
    }
    
    // MARK: - HealthKit
    
    private func requestHealthKitAccess() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("⚠️ HealthKit not available")
            return
        }
        
        // Time in Daylight — available iOS 17+
        guard let daylightType = HKQuantityType.quantityType(forIdentifier: .timeInDaylight) else {
            print("⚠️ Time in Daylight type not available (requires iOS 17+)")
            return
        }
        
        let readTypes: Set<HKObjectType> = [daylightType]
        
        healthStore.requestAuthorization(toShare: nil, read: readTypes) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.healthKitAuthorized = true
                    print("✅ HealthKit authorized for Time in Daylight")
                    self?.fetchTimeInDaylight()
                } else {
                    print("❌ HealthKit authorization failed: \(error?.localizedDescription ?? "unknown")")
                }
            }
        }
    }
    
    func fetchTimeInDaylight() {
        guard let daylightType = HKQuantityType.quantityType(forIdentifier: .timeInDaylight) else { return }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let now = Date()
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: daylightType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, result, error in
            DispatchQueue.main.async {
                if let sum = result?.sumQuantity() {
                    let minutes = sum.doubleValue(for: HKUnit.minute())
                    self?.timeInDaylight = minutes
                    print("☀️ Time in Daylight today: \(String(format: "%.1f", minutes)) min")
                } else {
                    self?.timeInDaylight = 0
                    print("☀️ Time in Daylight: no data yet today (\(error?.localizedDescription ?? ""))")
                }
            }
        }
        
        healthStore.execute(query)
    }
    
    // MARK: - Start / Stop Logging
    
    func startLogging() {
        isLogging = true
        
        // Start all sensors
        locationManager.startUpdatingLocation()
        
        if CMAltimeter.isRelativeAltitudeAvailable() {
            altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, error in
                guard let data = data, error == nil else { return }
                self?.relativeAltitude = data.relativeAltitude.doubleValue
                self?.pressure = data.pressure.doubleValue  // kPa
            }
        }
        
        if motionManager.isMagnetometerAvailable {
            motionManager.startMagnetometerUpdates(to: .main) { [weak self] data, error in
                guard let data = data, error == nil else { return }
                self?.magX = data.magneticField.x
                self?.magY = data.magneticField.y
                self?.magZ = data.magneticField.z
                let mag = sqrt(pow(data.magneticField.x, 2) + pow(data.magneticField.y, 2) + pow(data.magneticField.z, 2))
                self?.magMagnitude = mag
            }
        }
        
        // Fetch HealthKit immediately and then every 30s
        fetchTimeInDaylight()
        healthTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.fetchTimeInDaylight()
        }
        
        // Record first snapshot immediately (slight delay for sensors to populate)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.recordSnapshot()
        }
        
        // Then log a snapshot every 5 seconds
        logTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.recordSnapshot()
        }
    }
    
    func stopLogging() {
        isLogging = false
        logTimer?.invalidate()
        logTimer = nil
        healthTimer?.invalidate()
        healthTimer = nil
        locationManager.stopUpdatingLocation()
        altimeter.stopRelativeAltitudeUpdates()
        motionManager.stopMagnetometerUpdates()
        saveToDisk()
    }
    
    // MARK: - Ground Truth Toggle
    
    func setLabel(_ label: String) {
        currentLabel = label
        // Record an immediate snapshot on label change
        recordSnapshot()
    }
    
    // MARK: - Snapshot Recording
    
    private func recordSnapshot() {
        let snapshot = SensorSnapshot(
            timestamp: Date(),
            latitude: latitude,
            longitude: longitude,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: verticalAccuracy,
            altitude: altitude,
            floor: floor,
            speed: speed,
            course: nil,
            relativeAltitude: relativeAltitude,
            pressure: pressure,
            magX: magX,
            magY: magY,
            magZ: magZ,
            magMagnitude: magMagnitude,
            networkPathType: networkType,
            isExpensive: isExpensive,
            isConstrained: false,
            timeInDaylight: timeInDaylight,
            userLabel: currentLabel
        )
        
        snapshots.append(snapshot)
        logCount = snapshots.count
        
        // Auto-save periodically
        saveCounter += 1
        if saveCounter >= saveEveryN {
            saveCounter = 0
            saveToDisk()
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude
        horizontalAccuracy = location.horizontalAccuracy
        verticalAccuracy = location.verticalAccuracy
        altitude = location.altitude
        speed = location.speed
        
        if let clFloor = location.floor {
            floor = clFloor.level
        } else {
            floor = nil
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            print("✅ Location authorized")
        case .denied, .restricted:
            print("❌ Location denied")
        default:
            break
        }
    }
    
    // MARK: - Persistence (auto-save to disk)
    
    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(snapshots)
            try data.write(to: savePath)
            print("💾 Saved \(snapshots.count) snapshots to disk")
        } catch {
            print("Save error: \(error)")
        }
    }
    
    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: savePath.path) else { return }
        do {
            let data = try Data(contentsOf: savePath)
            snapshots = try JSONDecoder().decode([SensorSnapshot].self, from: data)
            logCount = snapshots.count
            print("📂 Loaded \(snapshots.count) snapshots from disk")
        } catch {
            print("Load error: \(error)")
        }
    }
    
    // MARK: - CSV Export (NO lat/lon for privacy)
    
    func exportCSV() -> URL? {
        let dateFormatter = ISO8601DateFormatter()
        
        var csv = "timestamp,label,h_accuracy,v_accuracy,altitude,floor,speed,rel_altitude,pressure_kPa,mag_x,mag_y,mag_z,mag_magnitude,network_type,is_expensive,time_in_daylight_min\n"
        
        for s in snapshots {
            var row = [String]()
            row.append(dateFormatter.string(from: s.timestamp))
            row.append(s.userLabel)
            // NO lat/lon — privacy for shared testing
            row.append(s.horizontalAccuracy.map { String(format: "%.1f", $0) } ?? "")
            row.append(s.verticalAccuracy.map { String(format: "%.1f", $0) } ?? "")
            row.append(s.altitude.map { String(format: "%.1f", $0) } ?? "")
            row.append(s.floor.map { String($0) } ?? "")
            row.append(s.speed.map { String(format: "%.2f", $0) } ?? "")
            row.append(s.relativeAltitude.map { String(format: "%.3f", $0) } ?? "")
            row.append(s.pressure.map { String(format: "%.2f", $0) } ?? "")
            row.append(s.magX.map { String(format: "%.2f", $0) } ?? "")
            row.append(s.magY.map { String(format: "%.2f", $0) } ?? "")
            row.append(s.magZ.map { String(format: "%.2f", $0) } ?? "")
            row.append(s.magMagnitude.map { String(format: "%.2f", $0) } ?? "")
            row.append(s.networkPathType)
            row.append(String(s.isExpensive))
            row.append(s.timeInDaylight.map { String(format: "%.1f", $0) } ?? "")
            csv += row.joined(separator: ",") + "\n"
        }
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("sensor_log_\(Date().timeIntervalSince1970).csv")
        
        do {
            try csv.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            print("CSV export error: \(error)")
            return nil
        }
    }
    
    func clearLog() {
        snapshots.removeAll()
        logCount = 0
        try? FileManager.default.removeItem(at: savePath)
    }
}
