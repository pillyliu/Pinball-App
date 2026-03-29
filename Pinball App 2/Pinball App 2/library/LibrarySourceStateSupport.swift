import Foundation

func postPinballLibrarySourcesDidChange() {
    NotificationCenter.default.post(name: .pinballLibrarySourcesDidChange, object: nil)
}

func normalizeStringMap(_ raw: [String: Any]?) -> [String: String] {
    dictionaryPreservingLastValue((raw ?? [:]).compactMap { key, value in
        guard let canonicalKey = canonicalLibrarySourceID(key), let stringValue = value as? String else { return nil }
        return (canonicalKey, stringValue)
    })
}

func normalizeIntMap(_ raw: [String: Any]?) -> [String: Int] {
    dictionaryPreservingLastValue((raw ?? [:]).compactMap { key, value in
        guard let canonicalKey = canonicalLibrarySourceID(key) else { return nil }
        if let intValue = value as? Int { return (canonicalKey, intValue) }
        if let numberValue = value as? NSNumber { return (canonicalKey, numberValue.intValue) }
        return nil
    })
}

func dedupedPairs<Key: Hashable, Value>(_ pairs: [(Key, Value)]) -> [(Key, Value)] {
    Array(dictionaryPreservingLastValue(pairs))
}

func dictionaryPreservingLastValue<Key: Hashable, Value>(_ pairs: [(Key, Value)]) -> [Key: Value] {
    var out: [Key: Value] = [:]
    for (key, value) in pairs {
        out[key] = value
    }
    return out
}
