import Foundation
import OSLog

private let pinballPerformanceSubsystem = "com.pillyliu.PinProf"
private let pinballPerformanceLog = OSLog(subsystem: pinballPerformanceSubsystem, category: "Performance")
private let pinballPerformanceLogger = Logger(subsystem: pinballPerformanceSubsystem, category: "Performance")

struct PinballPerformanceInterval {
    let name: StaticString
    let signpostID: OSSignpostID
    let startedUptimeNanos: UInt64
    let detail: String?
}

enum PinballPerformanceTrace {
    static func begin(_ name: StaticString, detail: String? = nil) -> PinballPerformanceInterval {
        let signpostID = OSSignpostID(log: pinballPerformanceLog)
        os_signpost(.begin, log: pinballPerformanceLog, name: name, signpostID: signpostID)
        return PinballPerformanceInterval(
            name: name,
            signpostID: signpostID,
            startedUptimeNanos: DispatchTime.now().uptimeNanoseconds,
            detail: detail
        )
    }

    static func end(_ interval: PinballPerformanceInterval) {
        let elapsedNanos = DispatchTime.now().uptimeNanoseconds - interval.startedUptimeNanos
        let durationMs = Double(elapsedNanos) / 1_000_000
        let durationText = String(format: "%.2f", durationMs)
        let name = String(describing: interval.name)

        os_signpost(
            .end,
            log: pinballPerformanceLog,
            name: interval.name,
            signpostID: interval.signpostID,
            "duration_ms=%{public}.2f",
            durationMs
        )

        if let detail = interval.detail, !detail.isEmpty {
            pinballPerformanceLogger.notice(
                "practice_perf name=\(name, privacy: .public) duration_ms=\(durationText, privacy: .public) detail=\(detail, privacy: .public)"
            )
        } else {
            pinballPerformanceLogger.notice(
                "practice_perf name=\(name, privacy: .public) duration_ms=\(durationText, privacy: .public)"
            )
        }
    }

    static func measure<T>(
        _ name: StaticString,
        detail: String? = nil,
        _ body: () throws -> T
    ) rethrows -> T {
        let interval = begin(name, detail: detail)
        defer { end(interval) }
        return try body()
    }

    static func measure<T>(
        _ name: StaticString,
        detail: String? = nil,
        _ body: () async throws -> T
    ) async rethrows -> T {
        let interval = begin(name, detail: detail)
        defer { end(interval) }
        return try await body()
    }
}
