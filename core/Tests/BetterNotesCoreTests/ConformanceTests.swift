import XCTest
import BetterNotesCore

// Runs the shared fixtures (fixtures/README.md) and the cross-language check.
// The same tests exist in packages/format-ts/test/conformance.test.ts.
//   BN_OUT_DIR      if set, every valid fixture is saved there (CI hands these to the TypeScript tests)
//   BN_FOREIGN_DIR  if set, files written by the TypeScript implementation are compared with the fixtures

private let repo = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
private let fixtures = repo.appendingPathComponent("fixtures")
private let validDir = fixtures.appendingPathComponent("valid")

/// Paths of all .json files below `dir`, relative to it.
private func jsonFiles(_ dir: URL) throws -> [String] {
    try FileManager.default.subpathsOfDirectory(atPath: dir.path).filter { $0.hasSuffix(".json") }.sorted()
}

private func parse(_ url: URL) throws -> JSONValue {
    try JSONValue.parse(try Data(contentsOf: url))
}

/// Reads a page through the typed model and writes every nested part back, so the
/// round trip also proves that the typed views lose nothing.
private func touched(_ file: JSONObject) -> JSONObject {
    guard file["format"]?.string == "betternotes.page" else { return file }
    var page = Page(raw: file)
    let size = page.size
    page.size = size
    if let paper = page.paper { page.paper = paper }
    if let mirror = page.mirror { page.mirror = mirror }
    page.layers = page.layers.map { (item: Layer) -> Layer in
        var layer = item
        layer.objects = item.objects.map { (original: PageObject) -> PageObject in
            var object = original
            if let points = original.pts {
                var copy = points
                copy.x = points.x
                copy.y = points.y
                if let v = points.p { copy.p = v }
                if let v = points.tilt { copy.tilt = v }
                if let v = points.az { copy.az = v }
                if let v = points.roll { copy.roll = v }
                if let v = points.t { copy.t = v }
                object.pts = copy
            }
            if let outline = original.stroke {
                var copy = outline
                copy.color = outline.color
                copy.width = outline.width
                if let v = outline.dash { copy.dash = v }
                object.stroke = copy
            }
            if let v = original.from { object.from = v }
            if let v = original.to { object.to = v }
            if let v = original.points { object.points = v }
            if let v = original.fill { object.fill = v }
            if let v = original.markdown { object.markdown = v }
            return object
        }
        return layer
    }
    return page.raw
}

final class ConformanceTests: XCTestCase {
    private func temporaryNotebook() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("bn-\(UUID().uuidString)/Test.bnote")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir.deletingLastPathComponent()) }
        return dir
    }

    func testValidFixturesAreUnchangedByLoadAndSave() throws {
        let files = try jsonFiles(validDir)
        XCTAssertGreaterThanOrEqual(files.count, 8)
        for rel in files {
            let url = validDir.appendingPathComponent(rel)
            let original = try parse(url)
            let loaded = try Format.load(try Data(contentsOf: url))
            XCTAssertFalse(loaded.readOnly, rel)
            XCTAssertFalse(loaded.migrated, rel)
            let written = try Format.save(touched(loaded.file))
            XCTAssertEqual(try JSONValue.parse(written), original, rel)
            if let out = ProcessInfo.processInfo.environment["BN_OUT_DIR"] {
                let target = URL(fileURLWithPath: out).appendingPathComponent(rel)
                try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                try written.write(to: target)
            }
        }
    }

    func testInvalidFixturesAreRejected() throws {
        for folder in ["invalid", "invalid-beyond-schema"] {
            let dir = fixtures.appendingPathComponent(folder)
            let files = try jsonFiles(dir)
            XCTAssertGreaterThanOrEqual(files.count, 6)
            for rel in files {
                let data = try Data(contentsOf: dir.appendingPathComponent(rel))
                XCTAssertThrowsError(try Format.load(data), "\(folder)/\(rel)")
            }
        }
        XCTAssertThrowsError(try Format.load(Data("{ not json".utf8)))
    }

    func testNewerMajorVersionIsReadOnly() throws {
        let dir = fixtures.appendingPathComponent("readonly")
        let files = try jsonFiles(dir)
        XCTAssertEqual(files.count, 2)
        for rel in files {
            let loaded = try Format.load(try Data(contentsOf: dir.appendingPathComponent(rel)))
            XCTAssertTrue(loaded.readOnly, rel)
            XCTAssertThrowsError(try Format.save(loaded.file), rel) { error in
                XCTAssertEqual(error as? FormatError, FormatError.readOnly)
            }
        }
    }

    func testParsingKeepsTheKindOfEachValue() throws {
        let parsed = try JSONValue.parse(Data("[1,true,2.5,3.0,null,\"x\",0,false]".utf8))
        let expected: [JSONValue] = [.int(1), .bool(true), .double(2.5), .int(3), .null, .string("x"), .int(0), .bool(false)]
        XCTAssertEqual(parsed, JSONValue.array(expected))
    }

    func testSerializeGivesTheSameBytesForTheSameContent() throws {
        let inner: JSONObject = ["c": .string("ü/"), "d": .array([.int(3), .double(2.5), .bool(false), .null])]
        let data = try JSONValue.serialize(["b": .int(1), "a": .object(inner)])
        XCTAssertEqual(String(decoding: data, as: UTF8.self), "{\"a\":{\"c\":\"ü/\",\"d\":[3,2.5,false,null]},\"b\":1}")
        XCTAssertThrowsError(try JSONValue.serialize(["x": .double(.nan)]))
    }

    func testTypedViewsReadTheFullFixture() throws {
        let book = validDir.appendingPathComponent("full.bnote")
        let notebook = Notebook(raw: try parse(book.appendingPathComponent("notebook.json")).object ?? [:])
        XCTAssertEqual(notebook.title, "Physik Übungen")
        XCTAssertEqual(notebook.tags, ["school", "physics"])
        XCTAssertEqual(notebook.cover?.color, "#3a3a3a")
        XCTAssertEqual(notebook.chapters.map { $0.id }, ["ch-mechanics", "ch-optics"])

        let page = Page(raw: try parse(book.appendingPathComponent("pages/p-fall.json")).object ?? [:])
        XCTAssertEqual(page.chapter, "ch-mechanics")
        XCTAssertEqual(page.size.w, 59528)
        XCTAssertEqual(page.paper?.spacing, 1417)
        XCTAssertEqual(page.layers.map { $0.id }, ["l-pdf", "l-ink", "l-shapes", "l-text"])
        XCTAssertTrue(page.layers[0].locked)
        XCTAssertEqual(page.layers[0].objects[0].page, 1)
        XCTAssertEqual(page.layers[0].opacity, 1000)
        XCTAssertEqual(page.layers[1].opacity, 900)
        XCTAssertFalse(page.layers[3].visible)
        let stroke = page.layers[1].objects[0]
        XCTAssertEqual(stroke.type, "stroke")
        XCTAssertEqual(stroke.pts?.count, 3)
        XCTAssertEqual(stroke.pts?.roll, [0, 12, -25])
        XCTAssertNil(page.layers[1].objects[1].pts?.p)
        let connector = page.layers[2].objects[8]
        XCTAssertEqual(connector.shape, "connector")
        XCTAssertEqual(connector.from?.object, "r1")
        XCTAssertEqual(connector.to?.anchor, "w")
        XCTAssertEqual(connector.points, [17000, 8000, 30000, 8000])
        XCTAssertEqual(page.layers[2].objects[1].stroke?.dash, [600, 300])
        XCTAssertEqual(page.layers[2].objects[1].rotation, 150)
        XCTAssertEqual(page.layers[3].objects[2].rotation, -900)

        let units = Page(raw: try parse(book.appendingPathComponent("pages/p-units.json")).object ?? [:])
        XCTAssertEqual(units.mirror?.mode, "radial")
        XCTAssertEqual(units.mirror?.count, 6)

        let ocr = OCRSidecar(raw: try parse(book.appendingPathComponent("pages/p-fall.ocr.json")).object ?? [:])
        XCTAssertEqual(ocr.items[0].confidence, 870)
        XCTAssertNil(ocr.items[1].confidence)
    }

    func testEditingAPageKeepsWhatThisVersionDoesNotKnow() throws {
        let url = validDir.appendingPathComponent("future-minor.bnote/pages/p-future.json")
        var page = Page(raw: try Format.load(try Data(contentsOf: url)).file)
        var layers = page.layers
        XCTAssertFalse(layers[0].objects[0].isKnown)
        XCTAssertTrue(layers[0].objects[1].isKnown)
        layers[0].objects.append(PageObject.newText(id: "new", x: 0, y: 0, w: 100, markdown: "added"))
        page.layers = layers
        page.modified = "2026-12-01T00:00:00Z"

        let after = try JSONValue.parse(try Format.save(page.raw)).object ?? [:]
        let before = try parse(url).object ?? [:]
        XCTAssertEqual(after["formatVersion"], JSONValue.string("1.7"))
        XCTAssertEqual(after["futurePageField"], JSONValue.string("keep me"))
        XCTAssertEqual(after["zoom"], JSONValue.double(1.5))
        XCTAssertEqual(after["size"], before["size"])
        let afterLayer = after["layers"]?.array?.first?.object ?? [:]
        let beforeLayer = before["layers"]?.array?.first?.object ?? [:]
        XCTAssertEqual(afterLayer["blendMode"], JSONValue.string("multiply"))
        let afterObjects = afterLayer["objects"]?.array ?? []
        XCTAssertEqual(afterObjects.count, 6)
        XCTAssertEqual(Array(afterObjects.prefix(5)), beforeLayer["objects"]?.array ?? [])
    }

    func testNewlyCreatedFilesAreValid() throws {
        var notebook = Notebook(title: "Neu")
        notebook.chapters = [Chapter(title: "Eins", order: Format.orderStep)]
        notebook.tags = ["a"]
        XCTAssertNoThrow(try Format.save(notebook.raw))

        var page = Page(chapter: notebook.chapters[0].id, order: 1024, width: 59528, height: 84189)
        var layer = Layer(name: "Layer 1")
        var pts = StrokePoints(x: [1, 2], y: [3, 4])
        pts.p = [500, 600]
        pts.roll = [0, -10]
        layer.objects = [PageObject.newStroke(tool: "pen", color: "#1a1a1a", width: 180, pts: pts)]
        page.layers = [layer]
        let again = Page(raw: try Format.load(try Format.save(page.raw)).file)
        XCTAssertEqual(again.layers[0].objects[0].pts?.roll, [0, -10])
        XCTAssertEqual(again.chapter, notebook.chapters[0].id)
        XCTAssertEqual(again.raw["formatVersion"], JSONValue.string("1.0"))

        page.chapter = nil
        XCTAssertEqual(page.raw["chapter"], JSONValue.null)
        XCTAssertNoThrow(try Format.save(page.raw))

        pts.p = [1]
        layer.objects = [PageObject.newStroke(tool: "pen", color: "#1a1a1a", width: 180, pts: pts)]
        page.layers = [layer]
        XCTAssertThrowsError(try Format.save(page.raw))
    }

    func testOrdering() {
        XCTAssertEqual(Format.orderBetween(nil, nil), 1024)
        XCTAssertEqual(Format.orderBetween(1024, nil), 2048)
        XCTAssertEqual(Format.orderBetween(nil, 1024), 0)
        XCTAssertEqual(Format.orderBetween(1024, 2048), 1536)
        XCTAssertEqual(Format.orderBetween(-3, 0), -2)
        XCTAssertNil(Format.orderBetween(5, 6))
        XCTAssertNil(Format.orderBetween(5, 5))
        XCTAssertEqual(Format.renumbered(3), [1024, 2048, 3072])
        let items = [Chapter(id: "b", title: "", order: 2), Chapter(id: "c", title: "", order: 1), Chapter(id: "a", title: "", order: 2)]
        XCTAssertEqual(Format.sorted(items).map { $0.id }, ["c", "a", "b"])
    }

    func testTimestampHasTheFormTheFormatRequires() {
        XCTAssertEqual(Format.timestamp(Date(timeIntervalSince1970: 1_794_312_000.9)), "2026-11-10T12:00:00Z")
    }

    func testWriteReplacesTheFileAndRefusesInvalidContent() throws {
        let notebook = try temporaryNotebook()
        let url = notebook.appendingPathComponent("pages/p1.json")
        var page = Page(id: "p1", chapter: nil, order: 1024, width: 100, height: 200)
        try NotebookFiles.write(page.raw, to: url)
        page.title = "second version"
        try NotebookFiles.write(page.raw, to: url)
        XCTAssertEqual(Page(raw: try NotebookFiles.read(url, notebook: notebook).file).title, "second version")

        page.raw["size"] = nil
        XCTAssertThrowsError(try NotebookFiles.write(page.raw, to: url))
        XCTAssertEqual(Page(raw: try NotebookFiles.read(url, notebook: notebook).file).title, "second version")
        // nothing but the page itself is left behind (no temporary files)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: notebook.appendingPathComponent("pages").path), ["p1.json"])
    }

    func testBackupKeepsEveryVersion() throws {
        let notebook = try temporaryNotebook()
        let url = notebook.appendingPathComponent("pages/p1.json")
        try NotebookFiles.write(Page(id: "p1", chapter: nil, order: 1, width: 1, height: 1).raw, to: url)
        let now = Date(timeIntervalSince1970: 1_794_312_000)
        let first = try NotebookFiles.backup(url, notebook: notebook, now: now)
        let second = try NotebookFiles.backup(url, notebook: notebook, now: now)
        XCTAssertEqual(first.lastPathComponent, "p1.json.20261110T120000Z")
        XCTAssertEqual(second.lastPathComponent, "p1.json.20261110T120000Z-2")
        XCTAssertEqual(first.deletingLastPathComponent().lastPathComponent, "pages")
        XCTAssertEqual(try Data(contentsOf: first), try Data(contentsOf: url))
    }

    func testMigrationBacksUpTheOriginalFirst() throws {
        let old = Data("{\"format\":\"betternotes.ocr\",\"formatVersion\":\"0.3\",\"pageId\":\"p\",\"items\":[]}".utf8)
        XCTAssertTrue(Format.migrations.isEmpty)
        XCTAssertThrowsError(try Format.load(old))
        let table: Migrations = [0: { file in
            var next = file
            next["formatVersion"] = .string("1.0")
            next["page"] = file["pageId"]
            next["pageId"] = nil
            next["pageModified"] = .string("2026-01-01T00:00:00Z")
            return next
        }]
        let loaded = try Format.load(old, migrations: table)
        XCTAssertTrue(loaded.migrated)
        XCTAssertFalse(loaded.readOnly)

        let notebook = try temporaryNotebook()
        let url = notebook.appendingPathComponent("pages/p.ocr.json")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try old.write(to: url)
        XCTAssertEqual(OCRSidecar(raw: try NotebookFiles.read(url, notebook: notebook, migrations: table).file).page, "p")
        let backups = try FileManager.default.contentsOfDirectory(atPath: notebook.appendingPathComponent(".backup/pages").path)
        XCTAssertEqual(backups.count, 1)
        XCTAssertEqual(try Data(contentsOf: notebook.appendingPathComponent(".backup/pages/\(backups[0])")), old)
        // the file on disk is now version 1.0 and needs no second migration
        XCTAssertFalse(try NotebookFiles.read(url, notebook: notebook).migrated)
    }

    func testFilesWrittenByTheTypeScriptImplementationHaveTheSameContent() throws {
        guard let path = ProcessInfo.processInfo.environment["BN_FOREIGN_DIR"] else {
            throw XCTSkip("BN_FOREIGN_DIR is not set")
        }
        let foreign = URL(fileURLWithPath: path)
        let files = try jsonFiles(foreign)
        XCTAssertEqual(files, try jsonFiles(validDir), "TypeScript should have written every valid fixture")
        for rel in files {
            let data = try Data(contentsOf: foreign.appendingPathComponent(rel))
            XCTAssertNoThrow(try Format.load(data), rel)
            XCTAssertEqual(try JSONValue.parse(data), try parse(validDir.appendingPathComponent(rel)), rel)
        }
    }
}
