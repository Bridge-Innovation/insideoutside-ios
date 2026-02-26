//
//  AboutDataView.swift
//  InsideOutside
//
//  Created by Sarah Gilmore on 2/26/26.
//
import SwiftUI

struct AboutDataView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    Text("We're collecting sensor data to figure out how to automatically detect whether someone is inside or outside — without relying on them to tell us. Here's what we're tracking and why.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                    
                    // GPS Accuracy
                    DataExplainerCard(
                        icon: "location.fill",
                        color: .blue,
                        title: "GPS Accuracy",
                        signal: "Strong",
                        fields: "h_accuracy, v_accuracy, altitude, floor, speed",
                        explanation: "Horizontal accuracy is our best signal. It measures how confident the phone is about its GPS fix (in meters). Outdoors with clear sky, it stays low and stable. Indoors, the signal degrades and drifts upward over time.",
                        insight: "The absolute number overlaps a lot between inside and outside, but the direction of change over 30–60 seconds is reliable. Climbing = probably went inside. Dropping = probably went outside."
                    )
                    
                    // Magnetometer
                    DataExplainerCard(
                        icon: "minus.magnifyingglass",
                        color: .orange,
                        title: "Magnetometer",
                        signal: "Moderate",
                        fields: "mag_x, mag_y, mag_z, mag_magnitude",
                        explanation: "Measures the total magnetic field strength in microtesla (µT). Buildings have steel, wiring, and appliances that distort Earth's magnetic field, so indoor readings tend to be higher and more erratic.",
                        insight: "Early testing shows ~620 µT indoors vs ~570 µT outdoors consistently. It's a solid secondary signal that reinforces the GPS drift pattern."
                    )
                    
                    // Time in Daylight
                    DataExplainerCard(
                        icon: "sun.max.fill",
                        color: .yellow,
                        title: "Time in Daylight",
                        signal: "Reference",
                        fields: "time_in_daylight_min",
                        explanation: "Apple's own inside/outside detection from the Apple Watch's ambient light sensor. This is a cumulative daily total — we look at when it increments between snapshots to see when Apple thinks you were outdoors.",
                        insight: "This is our ground-truth comparison. If our GPS + magnetometer approach correlates well with Apple's daylight data, we know we're on the right track. Requires an Apple Watch to work."
                    )
                    
                    // Barometer
                    DataExplainerCard(
                        icon: "barometer",
                        color: .purple,
                        title: "Barometer",
                        signal: "Weak",
                        fields: "pressure_kPa, rel_altitude",
                        explanation: "We hoped to detect pressure changes when walking through doorways (air pressure differs slightly inside vs outside), but testing shows the changes are too small and too slow to be useful.",
                        insight: "Collected just in case a pattern emerges across more locations or building types, but so far this hasn't been a useful signal."
                    )
                    
                    // Network
                    DataExplainerCard(
                        icon: "wifi",
                        color: .teal,
                        title: "Network",
                        signal: "Weak",
                        fields: "network_type, is_expensive",
                        explanation: "Whether you're on WiFi or cellular. In theory, dropping off WiFi could indicate going outside. In practice, home WiFi reaches into yards and driveways, making this unreliable.",
                        insight: "Early data shows cellular in ~30% of outdoor readings vs ~1% indoor. More useful in urban settings where you'd leave a known WiFi network, but not reliable enough on its own."
                    )
                    
                    Divider()
                    
                    // Summary
                    VStack(alignment: .leading, spacing: 8) {
                        Label("The bottom line", systemImage: "lightbulb.fill")
                            .font(.headline)
                        
                        Text("GPS accuracy drift and magnetometer magnitude are doing the heavy lifting. Time in Daylight gives us Apple's answer to compare against. Everything else is supporting data we're collecting in case patterns show up across more locations.")
                            .font(.callout)
                            .foregroundColor(.secondary)
                        
                        Text("The more different buildings and environments you test in, the more confident we can be that these patterns are universal and not just specific to one house.")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle("About the Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.bold)
                }
            }
        }
    }
}

struct DataExplainerCard: View {
    let icon: String
    let color: Color
    let title: String
    let signal: String
    let fields: String
    let explanation: String
    let insight: String
    
    var signalColor: Color {
        switch signal {
        case "Strong": return .green
        case "Moderate": return .orange
        case "Reference": return .blue
        default: return .gray
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.headline)
                    .foregroundColor(color)
                
                Spacer()
                
                Text(signal)
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(signalColor.opacity(0.15))
                    .foregroundColor(signalColor)
                    .cornerRadius(6)
            }
            
            Text(fields)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
            
            Text(explanation)
                .font(.callout)
            
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(color)
                    .font(.caption)
                    .padding(.top, 2)
                Text(insight)
                    .font(.callout)
                    .italic()
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    AboutDataView()
}
