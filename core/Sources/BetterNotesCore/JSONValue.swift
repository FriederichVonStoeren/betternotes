import Foundation

public typealias JSONObject = [String: JSONValue]

/// A parsed JSON file, kept whole.
///
/// Swift's `Codable` silently drops fields it does not know. The format requires the opposite
/// (docs/FORMAT.md, section 3), so files are held as this tree and the typed model in
/// Model.swift only reads from and writes into it.
public enum JSONValue: Equatable, Sendable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object(JSONObject)

    public var string: String? { if case .string(let v) = self { return v } else { return nil } }
    public var int: Int? { if case .int(let v) = self { return v } else { return nil } }
    public var bool: Bool? { if case .bool(let v) = self { return v } else { return nil } }
    public var array: [JSONValue]? { if case .array(let v) = self { return v } else { return nil } }
    public var object: JSONObject? { if case .object(let v) = self { return v } else { return nil } }

    public static func parse(_ data: Data) throws -> JSONValue {
        JSONValue(foundation: try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]))
    }

    /// Compact JSON with sorted keys, so the same content always gives the same bytes.
    public static func serialize(_ object: JSONObject) throws -> Data {
        let tree = JSONValue.object(object).foundation
        // JSONSerialization raises an Objective-C exception (a crash) for NaN and infinity.
        guard JSONSerialization.isValidJSONObject(tree) else {
            throw FormatError.invalid(["$: contains a number that JSON cannot represent"])
        }
        return try JSONSerialization.data(withJSONObject: tree, options: [.sortedKeys, .withoutEscapingSlashes])
    }

    private init(foundation value: Any) {
        switch value {
        case let s as String:
            self = .string(s)
        case let n as NSNumber:
            if CFGetTypeID(n) == CFBooleanGetTypeID() {
                self = .bool(n.boolValue)
            } else if CFNumberIsFloatType(n as CFNumber) {
                // 3.0 counts as the integer 3, as it does in JavaScript.
                let d = n.doubleValue
                self = d == d.rounded() && abs(d) < 9_007_199_254_740_992 ? .int(Int(d)) : .double(d)
            } else {
                self = .int(n.intValue)
            }
        case let a as [Any]:
            self = .array(a.map { JSONValue(foundation: $0) })
        case let o as [String: Any]:
            self = .object(o.mapValues { JSONValue(foundation: $0) })
        default:
            self = .null
        }
    }

    private var foundation: Any {
        switch self {
        case .null: return NSNull()
        case .bool(let v): return NSNumber(value: v)
        case .int(let v): return NSNumber(value: v)
        case .double(let v): return NSNumber(value: v)
        case .string(let v): return v
        case .array(let v): return v.map { $0.foundation }
        case .object(let v): return v.mapValues { $0.foundation }
        }
    }
}
