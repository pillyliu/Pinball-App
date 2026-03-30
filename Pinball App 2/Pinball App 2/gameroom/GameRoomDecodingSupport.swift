import Foundation

private func trimmedNilIfBlank(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

extension KeyedDecodingContainer {
    func decodeTrimmedStringIfPresent(forKey key: Key) -> String? {
        trimmedNilIfBlank(try? decodeIfPresent(String.self, forKey: key))
    }

    func decodeUUIDIfPresent(forKey key: Key) -> UUID? {
        guard let raw = decodeTrimmedStringIfPresent(forKey: key) else { return nil }
        return UUID(uuidString: raw)
    }

    func decodeUUID(forKey key: Key, default fallback: @autoclosure () -> UUID) -> UUID {
        decodeUUIDIfPresent(forKey: key) ?? fallback()
    }

    func decodeDateIfPresent(forKey key: Key) -> Date? {
        try? decodeIfPresent(Date.self, forKey: key)
    }

    func decodeEnum<T>(forKey key: Key, default fallback: T) -> T
    where T: RawRepresentable & CaseIterable, T.RawValue == String {
        guard let raw = decodeTrimmedStringIfPresent(forKey: key) else { return fallback }
        return T.allCases.first(where: { $0.rawValue.caseInsensitiveCompare(raw) == .orderedSame }) ?? fallback
    }
}
