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
    @State private var showingOnboarding = true
    @State private var showingAboutData = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    
                    // ============================================
                    // GROUND TRUTH BUTTONS (with TRANSIT)
                    // ============================================
                    VStack(spacing: 8) {
                        Text("WHERE ARE YOU?")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 10) {
                            LabelButton(
                                title: "INSIDE",
                                icon: "house.fill",
                                color: .red,
                                isSelected: sensors.currentLabel == "INSIDE"
                            ) {
                                sensors.setLabel("INSIDE")
                            }
                            
                            LabelButton(
                                title: "OUTSIDE",
                                icon: "leaf.fill",
                                color: .green,
                                isSelected: sensors.currentLabel == "OUTSIDE"
                            ) {
                                sensors.setLabel("OUTSIDE")
                            }
                            
                            LabelButton(
                                title: "TRANSIT",
                                icon: "car.fill",
                                color: .blue,
                                isSelected: sensors.currentLabel == "TRANSIT"
                            ) {
                                sensors.setLabel("TRANSIT")
                            }
                        }
                        
                        Text("Current: \(sensors.currentLabel)")
                            .font(.headline)
                            .foregroundColor(labelColor(sensors.currentLabel))
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
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.orange)
                            Text("Logging every 5 seconds...")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    // ============================================
                    // GPS / LOCATION — THE KEY SIGNAL
                    // ============================================
                    SensorCard(title: "GPS / CoreLocation", icon: "location.fill", color: .blue) {
                        SensorRow(label: "H. Accuracy", value: sensors.horizontalAccuracy, unit: "m", format: "%.1f",
                                  note: "Drift over 30s is the key signal")
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
                    }
                    
                    // ============================================
                    // HEALTHKIT — TIME IN DAYLIGHT
                    // ============================================
                    SensorCard(title: "Time in Daylight", icon: "sun.max.fill", color: .yellow) {
                        HStack {
                            Text("Today's Total")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            if let minutes = sensors.timeInDaylight {
                                Text("\(String(format: "%.1f", minutes)) min")
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.medium)
                            } else {
                                Text("—")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        HStack {
                            Text("HealthKit")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(sensors.healthKitAuthorized ? "Authorized" : "Not authorized")
                                .font(.caption)
                                .foregroundColor(sensors.healthKitAuthorized ? .green : .red)
                        }
                        
                        Text("Apple's own indoor/outdoor signal via Watch ambient light sensor")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                    
                    // ============================================
                    // BAROMETER
                    // ============================================
                    SensorCard(title: "Barometer / Altimeter", icon: "barometer", color: .purple) {
                        SensorRow(label: "Pressure", value: sensors.pressure, unit: "kPa", format: "%.2f",
                                  note: "Watch for sudden changes at doors")
                        SensorRow(label: "Rel. Altitude", value: sensors.relativeAltitude, unit: "m", format: "%.3f",
                                  note: "Change since logging started")
                    }
                    
                    // ============================================
                    // MAGNETOMETER
                    // ============================================
                    SensorCard(title: "Magnetometer", icon: "minus.magnifyingglass", color: .orange) {
                        SensorRow(label: "X", value: sensors.magX, unit: "µT", format: "%.1f")
                        SensorRow(label: "Y", value: sensors.magY, unit: "µT", format: "%.1f")
                        SensorRow(label: "Z", value: sensors.magZ, unit: "µT", format: "%.1f")
                        SensorRow(label: "Magnitude", value: sensors.magMagnitude, unit: "µT", format: "%.1f",
                                  note: "More stable outdoors, erratic near steel/electronics")
                    }
                    
                    // ============================================
                    // NETWORK
                    // ============================================
                    SensorCard(title: "Network Path", icon: "wifi", color: .teal) {
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
                        SensorCard(title: "Recent Snapshots", icon: "list.bullet", color: .gray) {
                            ForEach(sensors.snapshots.suffix(5).reversed()) { snapshot in
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(snapshot.userLabel)
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(labelColor(snapshot.userLabel))
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
                                        if let dl = snapshot.timeInDaylight {
                                            Text("DL: \(String(format: "%.0f", dl))m")
                                                .font(.system(.caption2, design: .monospaced))
                                                .foregroundColor(.orange)
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
                    // HELP & ABOUT BUTTONS
                    // ============================================
                    HStack(spacing: 20) {
                        Button(action: { showingOnboarding = true }) {
                            Label("How to Use", systemImage: "questionmark.circle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Button(action: { showingAboutData = true }) {
                            Label("About the Data", systemImage: "chart.bar.doc.horizontal")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
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
            .sheet(isPresented: $showingOnboarding) {
                OnboardingView(isPresented: $showingOnboarding)
            }
            .sheet(isPresented: $showingAboutData) {
                AboutDataView()
            }
            .alert("Clear all logged data?", isPresented: $showingClearConfirm) {
                Button("Clear", role: .destructive) {
                    sensors.clearLog()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
    
    private func labelColor(_ label: String) -> Color {
        switch label {
        case "INSIDE": return .red
        case "OUTSIDE": return .green
        case "TRANSIT": return .blue
        default: return .gray
        }
    }
}

// MARK: - Onboarding

struct OnboardingView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Label("What is this?", systemImage: "info.circle.fill")
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        Text("This app collects sensor data to help us figure out how to automatically detect whether you're inside or outside. It's a research tool for the Outside app.\n\nPlease run it over a few days whenever you're going places — grocery store, work, coffee shops, errands. The more different buildings you visit, the better! Just flip the label when you go in or out, and export the CSV when you're done.")
                            .font(.body)
                        
                        Text("Tap \"About the Data\" on the main screen to learn what each sensor measures and why we're tracking it.")
                            .font(.callout)
                            .italic()
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Label("How to use it", systemImage: "hand.tap.fill")
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        InstructionRow(number: "1", text: "Tap INSIDE, OUTSIDE, or TRANSIT to tell the app where you are right now.")
                        
                        InstructionRow(number: "2", text: "Tap Start Logging. The app will record sensor data every 5 seconds.")
                        
                        InstructionRow(number: "3", text: "Update your label whenever your situation changes — step outside, enter a store, get in a car (TRANSIT), arrive somewhere new.")
                        
                        InstructionRow(number: "4", text: "The more transitions you capture (going in and out of different buildings), the more useful the data!")
                        
                        InstructionRow(number: "5", text: "When you're done, tap Export CSV and send the file to Sarah.")
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Tips", systemImage: "lightbulb.fill")
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        Text("Use TRANSIT when you're in a vehicle — driving, on a bus, train, etc. If you're walking outside, that still counts as OUTSIDE even if you're moving between places.")
                            .font(.callout)
                        
                        Text("Try different places if you can — your house, stores, coffee shops, the office, a friend's place. Different buildings have different sensor signatures.")
                            .font(.callout)
                        
                        Text("It's fine to leave it running in the background. The blue indicator bar means it's still tracking.")
                            .font(.callout)
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Privacy", systemImage: "lock.shield.fill")
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        Text("The exported CSV does NOT include your GPS coordinates — only accuracy readings and sensor data. Your location stays on your device.")
                            .font(.callout)
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Welcome!")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Got it") {
                        isPresented = false
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}

struct InstructionRow: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Color.blue)
                .clipShape(Circle())
            
            Text(text)
                .font(.callout)
        }
    }
}

// MARK: - Reusable Components

struct SensorCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
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

struct LabelButton: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption)
                    .fontWeight(.heavy)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? color : color.opacity(0.15))
            .foregroundColor(isSelected ? .white : color)
            .cornerRadius(12)
        }
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
