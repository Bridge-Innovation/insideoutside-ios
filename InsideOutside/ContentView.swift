//
//  ContentView.swift
//  InsideOutside
//
//  Created by Sarah Gilmore on 2/24/26.
//
import SwiftUI

struct ContentView: View {
    @StateObject private var sensors = SensorManager()
    @State private var showingShareSheet = false
    @State private var csvURL: URL?
    @State private var showingClearConfirm = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    
                    // ============================================
                    // GROUND TRUTH BUTTONS
                    // ============================================
                    VStack(spacing: 8) {
                        Text("WHERE ARE YOU?")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 12) {
                            Button(action: { sensors.setLabel("INSIDE") }) {
                                Text("🏠 INSIDE")
                                    .font(.title2)
                                    .fontWeight(.heavy)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 20)
                                    .background(sensors.currentLabel == "INSIDE" ? Color.red : Color.red.opacity(0.2))
                                    .foregroundColor(sensors.currentLabel == "INSIDE" ? .white : .red)
                                    .cornerRadius(12)
                            }
                            
                            Button(action: { sensors.setLabel("OUTSIDE") }) {
                                Text("🌳 OUTSIDE")
                                    .font(.title2)
                                    .fontWeight(.heavy)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 20)
                                    .background(sensors.currentLabel == "OUTSIDE" ? Color.green : Color.green.opacity(0.2))
                                    .foregroundColor(sensors.currentLabel == "OUTSIDE" ? .white : .green)
                                    .cornerRadius(12)
                            }
                        }
                        
                        Text("Current: \(sensors.currentLabel)")
                            .font(.headline)
                            .foregroundColor(sensors.currentLabel == "OUTSIDE" ? .green : sensors.currentLabel == "INSIDE" ? .red : .gray)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // ============================================
                    // LOGGING CONTROLS
                    // ============================================
                    HStack {
                        Button(action: {
                            if sensors.isLogging {
                                sensors.stopLogging()
                            } else {
                                sensors.startLogging()
                            }
                        }) {
                            Label(sensors.isLogging ? "Stop Logging" : "Start Logging",
                                  systemImage: sensors.isLogging ? "stop.circle.fill" : "record.circle")
                                .font(.headline)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(sensors.isLogging ? Color.orange : Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        
                        Text("\(sensors.logCount) rows")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 70)
                    }
                    
                    if sensors.isLogging {
                        Text("📍 Logging every 5 seconds...")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    // ============================================
                    // GPS / LOCATION — THE KEY SIGNAL
                    // ============================================
                    SensorCard(title: "📍 GPS / CoreLocation", color: .blue) {
                        SensorRow(label: "H. Accuracy", value: sensors.horizontalAccuracy, unit: "m", format: "%.1f",
                                  note: "< 15m likely outdoor, > 30m likely indoor")
                        SensorRow(label: "V. Accuracy", value: sensors.verticalAccuracy, unit: "m", format: "%.1f")
                        SensorRow(label: "Altitude", value: sensors.altitude, unit: "m", format: "%.1f")
                        
                        HStack {
                            Text("Floor")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            if let floor = sensors.floor {
                                Text("Level \(floor)")
                                    .font(.system(.body, design: .monospaced))
                            } else {
                                Text("nil (often nil outdoors)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        SensorRow(label: "Speed", value: sensors.speed, unit: "m/s", format: "%.2f")
                        
                        if let lat = sensors.latitude, let lon = sensors.longitude {
                            HStack {
                                Text("Coords")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(String(format: "%.4f", lat)), \(String(format: "%.4f", lon))")
                                    .font(.system(.caption, design: .monospaced))
                            }
                        }
                    }
                    
                    // ============================================
                    // BAROMETER
                    // ============================================
                    SensorCard(title: "🌡️ Barometer / Altimeter", color: .purple) {
                        SensorRow(label: "Pressure", value: sensors.pressure, unit: "kPa", format: "%.2f",
                                  note: "Watch for sudden changes at doors")
                        SensorRow(label: "Rel. Altitude", value: sensors.relativeAltitude, unit: "m", format: "%.3f",
                                  note: "Change since logging started")
                    }
                    
                    // ============================================
                    // MAGNETOMETER
                    // ============================================
                    SensorCard(title: "🧲 Magnetometer", color: .orange) {
                        SensorRow(label: "X", value: sensors.magX, unit: "µT", format: "%.1f")
                        SensorRow(label: "Y", value: sensors.magY, unit: "µT", format: "%.1f")
                        SensorRow(label: "Z", value: sensors.magZ, unit: "µT", format: "%.1f")
                        SensorRow(label: "Magnitude", value: sensors.magMagnitude, unit: "µT", format: "%.1f",
                                  note: "More stable outdoors, erratic near steel/electronics")
                    }
                    
                    // ============================================
                    // NETWORK
                    // ============================================
                    SensorCard(title: "📶 Network Path", color: .teal) {
                        HStack {
                            Text("Type")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(sensors.networkType.uppercased())
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.bold)
                        }
                        HStack {
                            Text("Expensive (cellular)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(sensors.isExpensive ? "YES" : "NO")
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                    
                    // ============================================
                    // RECENT LOG ENTRIES
                    // ============================================
                    if !sensors.snapshots.isEmpty {
                        SensorCard(title: "📋 Recent Log (\(sensors.snapshots.count) total)", color: .gray) {
                            ForEach(sensors.snapshots.suffix(5).reversed()) { snapshot in
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(snapshot.userLabel)
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(snapshot.userLabel == "OUTSIDE" ? .green : snapshot.userLabel == "INSIDE" ? .red : .gray)
                                        
                                        Spacer()
                                        
                                        Text(snapshot.timestamp, style: .time)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    HStack(spacing: 12) {
                                        if let ha = snapshot.horizontalAccuracy {
                                            Text("GPS: \(String(format: "%.0f", ha))m")
                                                .font(.system(.caption2, design: .monospaced))
                                        }
                                        Text(snapshot.networkPathType)
                                            .font(.system(.caption2, design: .monospaced))
                                        if let p = snapshot.pressure {
                                            Text("\(String(format: "%.1f", p))kPa")
                                                .font(.system(.caption2, design: .monospaced))
                                        }
                                    }
                                }
                                .padding(.vertical, 2)
                                
                                if snapshot.id != sensors.snapshots.suffix(5).reversed().last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                    
                    // ============================================
                    // EXPORT / CLEAR
                    // ============================================
                    HStack(spacing: 12) {
                        Button(action: {
                            if let url = sensors.exportCSV() {
                                csvURL = url
                                showingShareSheet = true
                            }
                        }) {
                            Label("Export CSV", systemImage: "square.and.arrow.up")
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(sensors.snapshots.isEmpty ? Color.gray.opacity(0.3) : Color.blue.opacity(0.2))
                                .foregroundColor(sensors.snapshots.isEmpty ? .gray : .blue)
                                .cornerRadius(10)
                        }
                        .disabled(sensors.snapshots.isEmpty)
                        
                        Button(action: {
                            showingClearConfirm = true
                        }) {
                            Label("Clear", systemImage: "trash")
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(sensors.snapshots.isEmpty ? Color.gray.opacity(0.3) : Color.red.opacity(0.2))
                                .foregroundColor(sensors.snapshots.isEmpty ? .gray : .red)
                                .cornerRadius(10)
                        }
                        .disabled(sensors.snapshots.isEmpty)
                    }
                    
                    // ============================================
                    // NOTES
                    // ============================================
                    VStack(alignment: .leading, spacing: 4) {
                        Text("How to use this app:")
                            .font(.caption)
                            .fontWeight(.bold)
                        Text("1. Tap INSIDE or OUTSIDE whenever you change location")
                            .font(.caption2)
                        Text("2. Tap Start Logging to record sensor data every 5s")
                            .font(.caption2)
                        Text("3. Go about your day — walk outside, come back in")
                            .font(.caption2)
                        Text("4. Export CSV to analyze which signals predict in/out")
                            .font(.caption2)
                        Text("5. Key hypothesis: horizontalAccuracy < 15m = outside")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    
                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle("Inside / Outside")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingShareSheet) {
                if let url = csvURL {
                    ShareSheet(items: [url])
                }
            }
            .alert("Clear all logged data?", isPresented: $showingClearConfirm) {
                Button("Clear", role: .destructive) {
                    sensors.clearLog()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}

// MARK: - Reusable Components

struct SensorCard<Content: View>: View {
    let title: String
    let color: Color
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct SensorRow: View {
    let label: String
    let value: Double?
    let unit: String
    let format: String
    var note: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if let value = value {
                    Text("\(String(format: format, value)) \(unit)")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                } else {
                    Text("—")
                        .foregroundColor(.secondary)
                }
            }
            if let note = note {
                Text(note)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ContentView()
}
