import Foundation

// Checks a parsed file against docs/FORMAT.md.
// packages/format-ts/src/validate.ts is the same code in TypeScript: change both together.
// Unknown fields and unknown object types are never an error.

public enum Validation: Equatable {
    case ok
    /// Written by a newer major version: show it if you can, never save it.
    case readOnly
    case invalid([String])
}

extension Format {
    public static func validate(_ file: JSONValue) -> Validation {
        guard let o = file.object else { return .invalid(["$: must be an object"]) }
        let format = o["format"]?.string
        guard format == "betternotes.notebook" || format == "betternotes.page" || format == "betternotes.ocr" else {
            return .invalid(["$.format: unknown or missing"])
        }
        guard let version = o["formatVersion"]?.string, let fileMajor = majorVersion(version) else {
            return .invalid(["$.formatVersion: must look like \"1.0\""])
        }
        if fileMajor > major { return .readOnly }
        if fileMajor < major { return .invalid(["$.formatVersion: older major version, migrate first"]) }

        let c = Checker()
        if format == "betternotes.notebook" {
            notebook(c, o)
        } else if format == "betternotes.page" {
            page(c, o)
        } else {
            ocr(c, o)
        }
        return c.errors.isEmpty ? .ok : .invalid(c.errors)
    }

    /// The major number of "major.minor", or nil when the text does not have that form.
    static func majorVersion(_ version: String) -> Int? {
        let parts = version.utf8.split(separator: UInt8(ascii: "."), omittingEmptySubsequences: false)
        guard parts.count == 2, parts.allSatisfy({ !$0.isEmpty && $0.count < 10 && $0.allSatisfy(isDigit) }) else { return nil }
        return Int(String(decoding: parts[0], as: UTF8.self))
    }
}

// MARK: - Forms of single values (the regular expressions of validate.ts, written out)

private func isDigit(_ c: UInt8) -> Bool { c >= 48 && c <= 57 }
private func isLower(_ c: UInt8) -> Bool { c >= 97 && c <= 122 }
private func isUpper(_ c: UInt8) -> Bool { c >= 65 && c <= 90 }
private func isHex(_ c: UInt8) -> Bool { isDigit(c) || (c >= 97 && c <= 102) }

/// 1 to 64 characters from A-Z a-z 0-9 _ -
private func isID(_ s: String) -> Bool {
    let u = s.utf8
    return u.count >= 1 && u.count <= 64 && u.allSatisfy { isDigit($0) || isLower($0) || isUpper($0) || $0 == 95 || $0 == 45 }
}

/// #rrggbb or #rrggbbaa, lowercase
private func isColor(_ s: String) -> Bool {
    let u = Array(s.utf8)
    return (u.count == 7 || u.count == 9) && u[0] == 35 && u.dropFirst().allSatisfy(isHex)
}

/// 64 lowercase hex characters, a dot, an extension of 1 to 8 characters from a-z 0-9
private func isAsset(_ s: String) -> Bool {
    let u = Array(s.utf8)
    guard u.count >= 66, u.count <= 73, u[64] == 46 else { return false }
    return u[..<64].allSatisfy(isHex) && u[65...].allSatisfy { isDigit($0) || isLower($0) }
}

/// 2026-11-10T12:00:00Z
private func isTime(_ s: String) -> Bool {
    let u = Array(s.utf8)
    let form = Array("dddd-dd-ddTdd:dd:ddZ".utf8)
    guard u.count == form.count else { return false }
    // 100 is "d": a digit goes here
    return zip(u, form).allSatisfy { $0.1 == 100 ? isDigit($0.0) : $0.0 == $0.1 }
}

private let boxShapes: Set<String> = ["rect", "roundRect", "ellipse", "triangle"]
private let pathShapes: Set<String> = ["line", "arrow", "polygon", "curve", "connector"]

// MARK: - Checker

private struct Opt {
    var optional = false
    var nullable = false
    var form: ((String) -> Bool)? = nil
    var min: Int? = nil
    var max: Int? = nil
}

private final class Checker {
    var errors: [String] = []

    func fail(_ path: String, _ message: String) {
        errors.append("\(path): \(message)")
    }

    /// The field's value, or nil when there is nothing (more) to check.
    private func field(_ o: JSONObject, _ key: String, _ path: String, _ opt: Opt) -> JSONValue? {
        guard let v = o[key] else {
            if !opt.optional { fail("\(path).\(key)", "missing") }
            return nil
        }
        if v == .null && opt.nullable { return nil }
        return v
    }

    func str(_ o: JSONObject, _ key: String, _ path: String, _ opt: Opt = Opt()) {
        guard let v = field(o, key, path, opt) else { return }
        guard let s = v.string else {
            fail("\(path).\(key)", "must be a string")
            return
        }
        if let form = opt.form, !form(s) { fail("\(path).\(key)", "has the wrong form") }
    }

    func int(_ o: JSONObject, _ key: String, _ path: String, _ opt: Opt = Opt()) {
        guard let v = field(o, key, path, opt) else { return }
        guard let n = v.int else {
            fail("\(path).\(key)", "must be an integer")
            return
        }
        if let min = opt.min, n < min { fail("\(path).\(key)", "is out of range") }
        if let max = opt.max, n > max { fail("\(path).\(key)", "is out of range") }
    }

    func bool(_ o: JSONObject, _ key: String, _ path: String) {
        guard let v = field(o, key, path, Opt()) else { return }
        if v.bool == nil { fail("\(path).\(key)", "must be true or false") }
    }

    func obj(_ o: JSONObject, _ key: String, _ path: String, _ opt: Opt = Opt()) -> JSONObject? {
        guard let v = field(o, key, path, opt) else { return nil }
        if v.object == nil { fail("\(path).\(key)", "must be an object") }
        return v.object
    }

    func arr(_ o: JSONObject, _ key: String, _ path: String, _ opt: Opt = Opt()) -> [JSONValue]? {
        guard let v = field(o, key, path, opt) else { return nil }
        if v.array == nil { fail("\(path).\(key)", "must be a list") }
        return v.array
    }

    /// A list of integers with at least opt.min entries. Returns its length.
    @discardableResult
    func ints(_ o: JSONObject, _ key: String, _ path: String, _ opt: Opt = Opt()) -> Int? {
        guard let a = arr(o, key, path, opt) else { return nil }
        if !a.allSatisfy({ $0.int != nil }) {
            fail("\(path).\(key)", "must contain only integers")
        } else if a.count < (opt.min ?? 0) {
            fail("\(path).\(key)", "has too few entries")
        }
        return a.count
    }

    func strs(_ o: JSONObject, _ key: String, _ path: String, _ opt: Opt = Opt()) {
        guard let a = arr(o, key, path, opt) else { return }
        if !a.allSatisfy({ $0.string != nil }) { fail("\(path).\(key)", "must contain only strings") }
    }

    /// Each entry of a list that must contain objects, with its path.
    func objects(_ o: JSONObject, _ key: String, _ path: String) -> [(JSONObject, String)] {
        var out: [(JSONObject, String)] = []
        for (i, v) in (arr(o, key, path) ?? []).enumerated() {
            if let child = v.object {
                out.append((child, "\(path).\(key)[\(i)]"))
            } else {
                fail("\(path).\(key)[\(i)]", "must be an object")
            }
        }
        return out
    }

    func unique(_ ids: [String?], _ path: String, _ what: String) {
        var seen: Set<String> = []
        for case let id? in ids {
            if !seen.insert(id).inserted { fail(path, "duplicate \(what) id \"\(id)\"") }
        }
    }
}

// MARK: - The three kinds of file

private func notebook(_ c: Checker, _ o: JSONObject) {
    let p = "$"
    c.str(o, "id", p, Opt(form: isID))
    c.str(o, "title", p)
    c.str(o, "created", p, Opt(form: isTime))
    c.str(o, "modified", p, Opt(form: isTime))
    c.strs(o, "tags", p, Opt(optional: true))
    if let cover = c.obj(o, "cover", p, Opt(optional: true)) {
        c.str(cover, "color", "\(p).cover", Opt(optional: true, form: isColor))
        c.str(cover, "asset", "\(p).cover", Opt(optional: true, form: isAsset))
    }
    let chapters = c.objects(o, "chapters", p)
    for (ch, cp) in chapters {
        c.str(ch, "id", cp, Opt(form: isID))
        c.str(ch, "title", cp)
        c.int(ch, "order", cp)
    }
    c.unique(chapters.map { $0.0["id"]?.string }, "\(p).chapters", "chapter")
}

private func page(_ c: Checker, _ o: JSONObject) {
    let p = "$"
    c.str(o, "id", p, Opt(form: isID))
    c.str(o, "chapter", p, Opt(nullable: true, form: isID))
    c.int(o, "order", p)
    c.str(o, "title", p, Opt(optional: true))
    c.str(o, "created", p, Opt(form: isTime))
    c.str(o, "modified", p, Opt(form: isTime))
    c.strs(o, "tags", p, Opt(optional: true))
    if let size = c.obj(o, "size", p) {
        c.int(size, "w", "\(p).size", Opt(min: 1))
        c.int(size, "h", "\(p).size", Opt(min: 1))
    }
    if let paper = c.obj(o, "paper", p, Opt(optional: true)) {
        c.str(paper, "type", "\(p).paper", Opt(optional: true))
        c.str(paper, "color", "\(p).paper", Opt(optional: true, form: isColor))
        c.str(paper, "lineColor", "\(p).paper", Opt(optional: true, form: isColor))
        c.int(paper, "spacing", "\(p).paper", Opt(optional: true, min: 1))
    }
    if let mirror = c.obj(o, "mirror", p, Opt(optional: true)) {
        c.str(mirror, "mode", "\(p).mirror")
        c.int(mirror, "cx", "\(p).mirror", Opt(optional: true))
        c.int(mirror, "cy", "\(p).mirror", Opt(optional: true))
        c.int(mirror, "count", "\(p).mirror", Opt(optional: true, min: 2))
    }
    let layers = c.objects(o, "layers", p)
    var objectIds: [String?] = []
    for (layer, lp) in layers {
        c.str(layer, "id", lp, Opt(form: isID))
        c.str(layer, "name", lp)
        c.bool(layer, "visible", lp)
        c.bool(layer, "locked", lp)
        c.int(layer, "opacity", lp, Opt(optional: true, min: 0, max: 1000))
        for (obj, op) in c.objects(layer, "objects", lp) {
            object(c, obj, op)
            objectIds.append(obj["id"]?.string)
        }
    }
    c.unique(layers.map { $0.0["id"]?.string }, "\(p).layers", "layer")
    c.unique(objectIds, "\(p).layers", "object")
}

private func object(_ c: Checker, _ o: JSONObject, _ p: String) {
    c.str(o, "id", p, Opt(form: isID))
    c.str(o, "type", p)
    c.str(o, "link", p, Opt(optional: true))
    let type = o["type"]?.string
    let shape = o["shape"]?.string
    // Which kinds must have a box: text needs no height, path shapes need no box at all.
    let needsBox = type == "image" || type == "pdf" || (type == "shape" && boxShapes.contains(shape ?? ""))
    let needsXYW = needsBox || type == "text"
    c.int(o, "x", p, Opt(optional: !needsXYW))
    c.int(o, "y", p, Opt(optional: !needsXYW))
    c.int(o, "w", p, Opt(optional: !needsXYW, min: 0))
    c.int(o, "h", p, Opt(optional: !needsBox, min: 0))
    c.int(o, "rotation", p, Opt(optional: true))

    if type == "stroke" {
        c.str(o, "tool", p)
        c.str(o, "color", p, Opt(form: isColor))
        c.int(o, "width", p, Opt(min: 0))
        if let pts = c.obj(o, "pts", p) {
            let pp = "\(p).pts"
            let n = c.ints(pts, "x", pp, Opt(min: 1))
            var lengths = [c.ints(pts, "y", pp, Opt(min: 1))]
            for key in ["p", "tilt", "az", "roll", "t"] {
                lengths.append(c.ints(pts, key, pp, Opt(optional: true)))
            }
            if let n = n, lengths.contains(where: { $0 != nil && $0 != n }) {
                c.fail(pp, "all lists must have the same length as x")
            }
        }
    } else if type == "shape" {
        c.str(o, "shape", p)
        let needsPoints = pathShapes.contains(shape ?? "")
        if let n = c.ints(o, "points", p, Opt(optional: !needsPoints, min: 4)), n % 2 != 0 {
            c.fail("\(p).points", "must have an even number of entries")
        }
        c.int(o, "radius", p, Opt(optional: true, min: 0))
        if let stroke = c.obj(o, "stroke", p, Opt(optional: true)) {
            c.str(stroke, "color", "\(p).stroke", Opt(form: isColor))
            c.int(stroke, "width", "\(p).stroke", Opt(min: 0))
            c.ints(stroke, "dash", "\(p).stroke", Opt(optional: true))
        }
        c.str(o, "fill", p, Opt(optional: true, nullable: true, form: isColor))
        c.str(o, "start", p, Opt(optional: true))
        c.str(o, "end", p, Opt(optional: true))
        for key in ["from", "to"] {
            if let a = c.obj(o, key, p, Opt(optional: true)) {
                c.str(a, "object", "\(p).\(key)", Opt(form: isID))
                c.str(a, "anchor", "\(p).\(key)")
            }
        }
    } else if type == "text" {
        c.str(o, "markdown", p)
        c.int(o, "fontSize", p, Opt(optional: true, min: 1))
        c.str(o, "color", p, Opt(optional: true, form: isColor))
    } else if type == "image" {
        c.str(o, "asset", p, Opt(form: isAsset))
    } else if type == "pdf" {
        c.str(o, "asset", p, Opt(form: isAsset))
        c.int(o, "page", p, Opt(min: 1))
    }
}

private func ocr(_ c: Checker, _ o: JSONObject) {
    let p = "$"
    c.str(o, "page", p, Opt(form: isID))
    c.str(o, "pageModified", p, Opt(form: isTime))
    c.str(o, "engine", p, Opt(optional: true))
    for (item, ip) in c.objects(o, "items", p) {
        c.str(item, "text", ip)
        c.int(item, "x", ip)
        c.int(item, "y", ip)
        c.int(item, "w", ip, Opt(min: 0))
        c.int(item, "h", ip, Opt(min: 0))
        c.int(item, "confidence", ip, Opt(optional: true, min: 0, max: 1000))
    }
}
