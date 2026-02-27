import SwiftUI

struct PracticeTimePopoverField: View {
    let title: String
    @Binding var value: String

    @State private var showPopover = false
    @State private var hours = 0
    @State private var minutes = 0
    @State private var seconds = 0

    var body: some View {
        Button {
            showPopover = true
        } label: {
            HStack(spacing: 8) {
                Text(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "00:00:00" : value)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "clock")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appControlStyle()
        }
        .buttonStyle(.plain)
        .popover(
            isPresented: $showPopover,
            attachmentAnchor: .rect(.bounds),
            arrowEdge: .top
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    FiniteWheelNumberPicker(value: $hours, upperBound: 24)
                    Text(":").monospacedDigit().foregroundStyle(.secondary)
                    FiniteWheelNumberPicker(value: $minutes, upperBound: 59)
                    Text(":").monospacedDigit().foregroundStyle(.secondary)
                    FiniteWheelNumberPicker(value: $seconds, upperBound: 59)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(12)
            .frame(minWidth: 280)
            .onAppear {
                syncFromValue()
            }
            .onChange(of: hours) { _, _ in syncToValue() }
            .onChange(of: minutes) { _, _ in syncToValue() }
            .onChange(of: seconds) { _, _ in syncToValue() }
            .presentationCompactAdaptation(.popover)
        }
        .onAppear {
            if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                value = "00:00:00"
            }
            syncFromValue()
        }
    }

    private func syncToValue() {
        value = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private func syncFromValue() {
        let parts = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: ":")
        guard parts.count == 3 else {
            hours = 0
            minutes = 0
            seconds = 0
            syncToValue()
            return
        }

        let parsedHours = Int(parts[0]) ?? 0
        let parsedMinutes = Int(parts[1]) ?? 0
        let parsedSeconds = Int(parts[2]) ?? 0

        hours = min(max(parsedHours, 0), 24)
        minutes = min(max(parsedMinutes, 0), 59)
        seconds = min(max(parsedSeconds, 0), 59)
        syncToValue()
    }
}

private struct FiniteWheelNumberPicker: View {
    @Binding var value: Int
    let upperBound: Int

    var body: some View {
        Picker("", selection: $value) {
            ForEach(0...upperBound, id: \.self) { index in
                Text(String(format: "%02d", index))
                    .monospacedDigit()
                    .tag(index)
            }
        }
        .labelsHidden()
        .pickerStyle(.wheel)
        .frame(width: 70, height: 140)
        .clipped()
        .sensoryFeedback(.selection, trigger: value)
        .onChange(of: upperBound) { _, _ in
            value = min(max(value, 0), upperBound)
        }
        .onAppear {
            value = min(max(value, 0), upperBound)
        }
    }
}
