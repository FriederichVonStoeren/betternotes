import Foundation

// Typed views of the files in docs/FORMAT.md.
//
// Every type wraps the raw JSON object it came from and reads and writes single fields in it.
// Whatever a type has no property for (fields from a newer version) stays in `raw` and is
// saved again untouched.
//
// shortcut: list properties (layers, objects, pts.x ...) convert the whole list on every
// access. Fine for loading and saving; a drawing canvas should convert once into its own
// render model instead of reading these in a loop.

public protocol RawBacked {
    var raw: JSONObject { get set }
    init(raw: JSONObject)
}

extension RawBacked {
    func string(_ key: String) -> String? { raw[key]?.string }
    func int(_ key: String) -> Int? { raw[key]?.int }
    func bool(_ key: String) -> Bool? { raw[key]?.bool }
    func ints(_ key: String) -> [Int]? { raw[key]?.array?.compactMap { $0.int } }
    func strings(_ key: String) -> [String]? { raw[key]?.array?.compactMap { $0.string } }
    func child<T: RawBacked>(_ key: String) -> T? { raw[key]?.object.map { T(raw: $0) } }
    func children<T: RawBacked>(_ key: String) -> [T] {
        (raw[key]?.array ?? []).compactMap { $0.object.map { T(raw: $0) } }
    }

    // Setting nil removes the field.
    mutating func set(_ key: String, _ value: String?) { raw[key] = value.map { JSONValue.string($0) } }
    mutating func set(_ key: String, _ value: Int?) { raw[key] = value.map { JSONValue.int($0) } }
    mutating func set(_ key: String, _ value: Bool?) { raw[key] = value.map { JSONValue.bool($0) } }
    mutating func set(_ key: String, _ value: [Int]?) {
        raw[key] = value.map { list in JSONValue.array(list.map { JSONValue.int($0) }) }
    }
    mutating func set(_ key: String, _ value: [String]?) {
        raw[key] = value.map { list in JSONValue.array(list.map { JSONValue.string($0) }) }
    }
    mutating func setChild<T: RawBacked>(_ key: String, _ value: T?) {
        raw[key] = value.map { JSONValue.object($0.raw) }
    }
    mutating func setChildren<T: RawBacked>(_ key: String, _ value: [T]) {
        raw[key] = JSONValue.array(value.map { JSONValue.object($0.raw) })
    }
}

/// Something with a position among its siblings (FORMAT.md, "Ordering").
public protocol Ordered {
    var id: String { get }
    var order: Int { get }
}

// MARK: - Notebook

public struct Notebook: RawBacked {
    public var raw: JSONObject
    public init(raw: JSONObject) { self.raw = raw }

    public init(id: String = Format.newID(), title: String, now: String = Format.timestamp()) {
        raw = [
            "format": .string("betternotes.notebook"), "formatVersion": .string(Format.version),
            "id": .string(id), "title": .string(title),
            "created": .string(now), "modified": .string(now), "chapters": .array([]),
        ]
    }

    public var id: String { get { string("id") ?? "" } set { set("id", newValue) } }
    public var title: String { get { string("title") ?? "" } set { set("title", newValue) } }
    public var created: String { get { string("created") ?? "" } set { set("created", newValue) } }
    public var modified: String { get { string("modified") ?? "" } set { set("modified", newValue) } }
    public var tags: [String] { get { strings("tags") ?? [] } set { set("tags", newValue) } }
    public var cover: Cover? { get { child("cover") } set { setChild("cover", newValue) } }
    public var chapters: [Chapter] { get { children("chapters") } set { setChildren("chapters", newValue) } }
}

public struct Cover: RawBacked {
    public var raw: JSONObject
    public init(raw: JSONObject) { self.raw = raw }
    public var color: String? { get { string("color") } set { set("color", newValue) } }
    public var asset: String? { get { string("asset") } set { set("asset", newValue) } }
}

public struct Chapter: RawBacked, Ordered {
    public var raw: JSONObject
    public init(raw: JSONObject) { self.raw = raw }

    public init(id: String = Format.newID(), title: String, order: Int) {
        raw = ["id": .string(id), "title": .string(title), "order": .int(order)]
    }

    public var id: String { get { string("id") ?? "" } set { set("id", newValue) } }
    public var title: String { get { string("title") ?? "" } set { set("title", newValue) } }
    public var order: Int { get { int("order") ?? 0 } set { set("order", newValue) } }
}

// MARK: - Page

public struct Page: RawBacked, Ordered {
    public var raw: JSONObject
    public init(raw: JSONObject) { self.raw = raw }

    public init(id: String = Format.newID(), chapter: String?, order: Int, width: Int, height: Int,
                now: String = Format.timestamp()) {
        raw = [
            "format": .string("betternotes.page"), "formatVersion": .string(Format.version),
            "id": .string(id), "chapter": chapter.map { JSONValue.string($0) } ?? JSONValue.null, "order": .int(order),
            "created": .string(now), "modified": .string(now),
            "size": .object(["w": .int(width), "h": .int(height)]), "layers": .array([]),
        ]
    }

    public var id: String { get { string("id") ?? "" } set { set("id", newValue) } }
    /// nil = the page is outside any chapter. The field itself is always written.
    public var chapter: String? {
        get { string("chapter") }
        set { raw["chapter"] = newValue.map { JSONValue.string($0) } ?? JSONValue.null }
    }
    public var order: Int { get { int("order") ?? 0 } set { set("order", newValue) } }
    public var title: String? { get { string("title") } set { set("title", newValue) } }
    public var created: String { get { string("created") ?? "" } set { set("created", newValue) } }
    public var modified: String { get { string("modified") ?? "" } set { set("modified", newValue) } }
    public var tags: [String] { get { strings("tags") ?? [] } set { set("tags", newValue) } }
    public var size: Size { get { child("size") ?? Size(raw: [:]) } set { setChild("size", newValue) } }
    public var paper: Paper? { get { child("paper") } set { setChild("paper", newValue) } }
    public var mirror: Symmetry? { get { child("mirror") } set { setChild("mirror", newValue) } }
    /// Bottom layer first.
    public var layers: [Layer] { get { children("layers") } set { setChildren("layers", newValue) } }
}

public struct Size: RawBacked {
    public var raw: JSONObject
    public init(raw: JSONObject) { self.raw = raw }
    public var w: Int { get { int("w") ?? 0 } set { set("w", newValue) } }
    public var h: Int { get { int("h") ?? 0 } set { set("h", newValue) } }
}

public struct Paper: RawBacked {
    public var raw: JSONObject
    public init(raw: JSONObject) { self.raw = raw }
    public var type: String? { get { string("type") } set { set("type", newValue) } }
    public var color: String? { get { string("color") } set { set("color", newValue) } }
    public var lineColor: String? { get { string("lineColor") } set { set("lineColor", newValue) } }
    public var spacing: Int? { get { int("spacing") } set { set("spacing", newValue) } }
}

public struct Symmetry: RawBacked {
    public var raw: JSONObject
    public init(raw: JSONObject) { self.raw = raw }
    public var mode: String { get { string("mode") ?? "" } set { set("mode", newValue) } }
    public var cx: Int? { get { int("cx") } set { set("cx", newValue) } }
    public var cy: Int? { get { int("cy") } set { set("cy", newValue) } }
    public var count: Int? { get { int("count") } set { set("count", newValue) } }
}

public struct Layer: RawBacked {
    public var raw: JSONObject
    public init(raw: JSONObject) { self.raw = raw }

    public init(id: String = Format.newID(), name: String) {
        raw = ["id": .string(id), "name": .string(name), "visible": .bool(true), "locked": .bool(false), "objects": .array([])]
    }

    public var id: String { get { string("id") ?? "" } set { set("id", newValue) } }
    public var name: String { get { string("name") ?? "" } set { set("name", newValue) } }
    public var visible: Bool { get { bool("visible") ?? true } set { set("visible", newValue) } }
    public var locked: Bool { get { bool("locked") ?? false } set { set("locked", newValue) } }
    /// 0 to 1000.
    public var opacity: Int { get { int("opacity") ?? 1000 } set { set("opacity", newValue) } }
    /// Bottom object first.
    public var objects: [PageObject] { get { children("objects") } set { setChildren("objects", newValue) } }
}

// MARK: - Objects

/// Any object on a page. Which properties mean something depends on `type` (FORMAT.md, section 7).
/// An unknown `type` must be kept and not edited.
public struct PageObject: RawBacked {
    public var raw: JSONObject
    public init(raw: JSONObject) { self.raw = raw }

    public static let knownTypes: Set<String> = ["stroke", "shape", "text", "image", "pdf"]
    public var isKnown: Bool { PageObject.knownTypes.contains(type) }

    public static func newStroke(id: String = Format.newID(), tool: String, color: String, width: Int, pts: StrokePoints) -> PageObject {
        PageObject(raw: ["id": .string(id), "type": .string("stroke"), "tool": .string(tool),
                         "color": .string(color), "width": .int(width), "pts": .object(pts.raw)])
    }

    public static func newText(id: String = Format.newID(), x: Int, y: Int, w: Int, markdown: String) -> PageObject {
        PageObject(raw: ["id": .string(id), "type": .string("text"), "x": .int(x), "y": .int(y), "w": .int(w),
                         "markdown": .string(markdown)])
    }

    // All objects
    public var id: String { get { string("id") ?? "" } set { set("id", newValue) } }
    public var type: String { get { string("type") ?? "" } set { set("type", newValue) } }
    public var link: String? { get { string("link") } set { set("link", newValue) } }
    public var x: Int? { get { int("x") } set { set("x", newValue) } }
    public var y: Int? { get { int("y") } set { set("y", newValue) } }
    public var w: Int? { get { int("w") } set { set("w", newValue) } }
    public var h: Int? { get { int("h") } set { set("h", newValue) } }
    public var rotation: Int { get { int("rotation") ?? 0 } set { set("rotation", newValue) } }

    // stroke (color also: text)
    public var tool: String? { get { string("tool") } set { set("tool", newValue) } }
    public var color: String? { get { string("color") } set { set("color", newValue) } }
    public var width: Int? { get { int("width") } set { set("width", newValue) } }
    public var pts: StrokePoints? { get { child("pts") } set { setChild("pts", newValue) } }

    // shape
    public var shape: String? { get { string("shape") } set { set("shape", newValue) } }
    /// Flat list x0, y0, x1, y1, ...
    public var points: [Int]? { get { ints("points") } set { set("points", newValue) } }
    public var radius: Int? { get { int("radius") } set { set("radius", newValue) } }
    public var stroke: ShapeStroke? { get { child("stroke") } set { setChild("stroke", newValue) } }
    public var fill: String? { get { string("fill") } set { set("fill", newValue) } }
    public var start: String? { get { string("start") } set { set("start", newValue) } }
    public var end: String? { get { string("end") } set { set("end", newValue) } }
    public var from: Attachment? { get { child("from") } set { setChild("from", newValue) } }
    public var to: Attachment? { get { child("to") } set { setChild("to", newValue) } }

    // text
    public var markdown: String? { get { string("markdown") } set { set("markdown", newValue) } }
    public var fontSize: Int? { get { int("fontSize") } set { set("fontSize", newValue) } }

    // image, pdf
    public var asset: String? { get { string("asset") } set { set("asset", newValue) } }
    public var page: Int? { get { int("page") } set { set("page", newValue) } }
}

/// The points of a stroke as parallel lists. Units: FORMAT.md, section 7.1.
public struct StrokePoints: RawBacked {
    public var raw: JSONObject
    public init(raw: JSONObject) { self.raw = raw }

    public init(x: [Int], y: [Int]) {
        raw = [:]
        self.x = x
        self.y = y
    }

    public var count: Int { raw["x"]?.array?.count ?? 0 }
    public var x: [Int] { get { ints("x") ?? [] } set { set("x", newValue) } }
    public var y: [Int] { get { ints("y") ?? [] } set { set("y", newValue) } }
    public var p: [Int]? { get { ints("p") } set { set("p", newValue) } }
    public var tilt: [Int]? { get { ints("tilt") } set { set("tilt", newValue) } }
    public var az: [Int]? { get { ints("az") } set { set("az", newValue) } }
    public var roll: [Int]? { get { ints("roll") } set { set("roll", newValue) } }
    public var t: [Int]? { get { ints("t") } set { set("t", newValue) } }
}

public struct ShapeStroke: RawBacked {
    public var raw: JSONObject
    public init(raw: JSONObject) { self.raw = raw }
    public var color: String { get { string("color") ?? "#000000" } set { set("color", newValue) } }
    public var width: Int { get { int("width") ?? 0 } set { set("width", newValue) } }
    public var dash: [Int]? { get { ints("dash") } set { set("dash", newValue) } }
}

public struct Attachment: RawBacked {
    public var raw: JSONObject
    public init(raw: JSONObject) { self.raw = raw }
    public var object: String { get { string("object") ?? "" } set { set("object", newValue) } }
    public var anchor: String { get { string("anchor") ?? "" } set { set("anchor", newValue) } }
}

// MARK: - OCR sidecar

public struct OCRSidecar: RawBacked {
    public var raw: JSONObject
    public init(raw: JSONObject) { self.raw = raw }
    public var page: String { get { string("page") ?? "" } set { set("page", newValue) } }
    public var pageModified: String { get { string("pageModified") ?? "" } set { set("pageModified", newValue) } }
    public var engine: String? { get { string("engine") } set { set("engine", newValue) } }
    public var items: [OCRItem] { get { children("items") } set { setChildren("items", newValue) } }
}

public struct OCRItem: RawBacked {
    public var raw: JSONObject
    public init(raw: JSONObject) { self.raw = raw }
    public var text: String { get { string("text") ?? "" } set { set("text", newValue) } }
    public var x: Int { get { int("x") ?? 0 } set { set("x", newValue) } }
    public var y: Int { get { int("y") ?? 0 } set { set("y", newValue) } }
    public var w: Int { get { int("w") ?? 0 } set { set("w", newValue) } }
    public var h: Int { get { int("h") ?? 0 } set { set("h", newValue) } }
    /// 0 to 1000.
    public var confidence: Int? { get { int("confidence") } set { set("confidence", newValue) } }
}
