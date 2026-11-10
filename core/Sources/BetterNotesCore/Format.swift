import Foundation

public enum FormatError: Error, Equatable {
    case invalid([String])
    /// The file was written by a newer major version and must not be saved.
    case readOnly
}

/// Upgrades a file by one major version. Keyed by the major version it upgrades FROM.
public typealias Migrations = [Int: (JSONObject) -> JSONObject]

public struct LoadedFile {
    public var file: JSONObject
    public var readOnly: Bool
    /// true: the original must be backed up before this is saved (FORMAT.md, 3.4).
    public var migrated: Bool
}

/// Swift reference implementation of the betternotes format. Spec: docs/FORMAT.md.
public enum Format {
    public static let major = 1
    public static let minor = 0
    public static let version = "\(major).\(minor)"

    /// Version 1 is the first format version, so there is nothing to migrate from yet.
    public static let migrations: Migrations = [:]

    /// Parses and checks the bytes of a notebook, page or OCR file.
    public static func load(_ data: Data, migrations: Migrations = Format.migrations) throws -> LoadedFile {
        let parsed: JSONValue
        do {
            parsed = try JSONValue.parse(data)
        } catch {
            throw FormatError.invalid(["$: not JSON"])
        }
        var file = parsed
        var migrated = false
        while let o = file.object, let fileMajor = o["formatVersion"]?.string.flatMap(majorVersion),
              fileMajor < major, let step = migrations[fileMajor] {
            file = .object(step(o))
            migrated = true
        }
        switch validate(file) {
        case .invalid(let errors): throw FormatError.invalid(errors)
        case .readOnly: return LoadedFile(file: file.object ?? [:], readOnly: true, migrated: migrated)
        case .ok: return LoadedFile(file: file.object ?? [:], readOnly: false, migrated: migrated)
        }
    }

    /// The bytes to write to disk. Throws instead of producing a file that other devices
    /// could not read, and for files from a newer major version (those are read-only).
    public static func save(_ file: JSONObject) throws -> Data {
        switch validate(.object(file)) {
        case .invalid(let errors): throw FormatError.invalid(errors)
        case .readOnly: throw FormatError.readOnly
        case .ok: return try JSONValue.serialize(file)
        }
    }

    public static func newID() -> String {
        UUID().uuidString.lowercased()
    }

    public static func timestamp(_ date: Date = Date()) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    // MARK: Ordering of chapters and pages (FORMAT.md, "Ordering")

    public static let orderStep = 1024

    /// An `order` between two neighbours (nil = no neighbour on that side).
    /// Returns nil when there is no gap left: renumber the siblings with `renumbered` first.
    public static func orderBetween(_ before: Int?, _ after: Int?) -> Int? {
        guard let before = before else { return after.map { $0 - orderStep } ?? orderStep }
        guard let after = after else { return before + orderStep }
        let middle = Int((Double(before + after) / 2).rounded(.down))
        return middle > before && middle < after ? middle : nil
    }

    /// Fresh `order` values for `count` items that are already in the right sequence.
    public static func renumbered(_ count: Int) -> [Int] {
        (0..<count).map { ($0 + 1) * orderStep }
    }

    /// Sorts by `order`, ties by `id`.
    public static func sorted<T: Ordered>(_ items: [T]) -> [T] {
        items.sorted { ($0.order, $0.id) < ($1.order, $1.id) }
    }
}
