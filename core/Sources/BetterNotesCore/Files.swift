import Foundation

/// Reading and writing the files of one notebook folder without ever losing the old version.
public enum NotebookFiles {
    /// Reads and checks a notebook, page or OCR file. A file from an older major version is
    /// migrated: the original goes to `.backup/` first, then the migrated file replaces it.
    public static func read(_ url: URL, notebook: URL, migrations: Migrations = Format.migrations) throws -> LoadedFile {
        let loaded = try Format.load(try Data(contentsOf: url), migrations: migrations)
        if loaded.migrated {
            try backup(url, notebook: notebook)
            try write(loaded.file, to: url)
        }
        return loaded
    }

    /// Checks the file, then replaces `url` in one step: a crash leaves either the old or the
    /// new version on disk, never half of one.
    public static func write(_ file: JSONObject, to url: URL) throws {
        let data = try Format.save(file)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    /// Copies a file to `.backup/<path inside the notebook>.<time>` and returns the copy's location.
    @discardableResult
    public static func backup(_ url: URL, notebook: URL, now: Date = Date()) throws -> URL {
        let base = notebook.standardizedFileURL.path
        let full = url.standardizedFileURL.path
        let relative = full.hasPrefix(base + "/") ? String(full.dropFirst(base.count + 1)) : url.lastPathComponent
        // 20261110T120000Z: no characters that some file systems refuse
        let stamp = Format.timestamp(now).filter { $0 != "-" && $0 != ":" }
        let folder = notebook.appendingPathComponent(".backup")
        var target = folder.appendingPathComponent("\(relative).\(stamp)")
        var n = 2
        while FileManager.default.fileExists(atPath: target.path) {
            target = folder.appendingPathComponent("\(relative).\(stamp)-\(n)")
            n += 1
        }
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: url, to: target)
        return target
    }
}
