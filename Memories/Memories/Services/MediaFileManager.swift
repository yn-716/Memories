import Foundation

enum MediaFileManagerError: LocalizedError {
    case copyFailed
    case missingFile

    var errorDescription: String? {
        switch self {
        case .copyFailed:
            return "メディアファイルを準備できませんでした。"
        case .missingFile:
            return "メディアファイルが見つかりませんでした。"
        }
    }
}

struct MediaFileManager {
    nonisolated static let shared = MediaFileManager()

    nonisolated init() {}

    nonisolated private var fileManager: FileManager {
        FileManager.default
    }

    nonisolated func prepareTemporaryDirectories() throws {
        try createDirectoryIfNeeded(at: importsDirectory)
        try createDirectoryIfNeeded(at: exportsDirectory)
        try createDirectoryIfNeeded(at: sharesDirectory)
    }

    nonisolated func copyVideoToTemporaryImport(from sourceURL: URL) throws -> URL {
        try prepareTemporaryDirectories()
        let destination = importsDirectory.appendingPathComponent(uniqueFileName(prefix: "import", sourceURL: sourceURL))
        try copyFile(from: sourceURL, to: destination)
        return destination
    }

    nonisolated func makeTemporaryExportURL(fileExtension: String = "mp4") throws -> URL {
        try prepareTemporaryDirectories()
        let filename = "export-\(UUID().uuidString).\(fileExtension)"
        return exportsDirectory.appendingPathComponent(filename)
    }

    nonisolated func copyTemporaryShareFile(from sourceURL: URL) throws -> URL {
        try prepareTemporaryDirectories()
        let destination = sharesDirectory.appendingPathComponent(uniqueFileName(prefix: "share", sourceURL: sourceURL))
        try copyFile(from: sourceURL, to: destination)
        return destination
    }

    nonisolated func removeTemporaryFileIfPossible(at url: URL?) {
        guard let url, fileManager.fileExists(atPath: url.path) else {
            return
        }

        try? fileManager.removeItem(at: url)
    }

    @discardableResult
    nonisolated func cleanupTemporaryFiles(olderThan cutoff: Date = Date().addingTimeInterval(-24 * 60 * 60)) throws -> Int {
        try prepareTemporaryDirectories()
        var removedCount = 0

        for directory in [importsDirectory, exportsDirectory, sharesDirectory] {
            guard let urls = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey]
            ) else {
                continue
            }

            for url in urls {
                let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey])
                guard values?.isRegularFile == true else {
                    continue
                }

                if (values?.contentModificationDate ?? .distantPast) < cutoff {
                    try? fileManager.removeItem(at: url)
                    removedCount += 1
                }
            }
        }

        return removedCount
    }

    nonisolated func excludeFromBackupIfPossible(_ url: URL) {
        var mutableURL = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? mutableURL.setResourceValues(values)
    }

    nonisolated private func copyFile(from sourceURL: URL, to destinationURL: URL) throws {
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw MediaFileManagerError.missingFile
        }

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        do {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: destinationURL.path)
            excludeFromBackupIfPossible(destinationURL)
        } catch {
            throw MediaFileManagerError.copyFailed
        }
    }

    nonisolated private func createDirectoryIfNeeded(at url: URL) throws {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        excludeFromBackupIfPossible(url)
    }

    nonisolated private func uniqueFileName(prefix: String, sourceURL: URL) -> String {
        let ext = sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension
        return "\(prefix)-\(UUID().uuidString).\(ext)"
    }

    nonisolated private var cachesDirectory: URL {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    }

    nonisolated private var rootDirectory: URL {
        cachesDirectory.appendingPathComponent("MemoriesTemporaryMedia", isDirectory: true)
    }

    nonisolated private var importsDirectory: URL {
        rootDirectory.appendingPathComponent("Imports", isDirectory: true)
    }

    nonisolated private var exportsDirectory: URL {
        rootDirectory.appendingPathComponent("Exports", isDirectory: true)
    }

    nonisolated private var sharesDirectory: URL {
        rootDirectory.appendingPathComponent("Shares", isDirectory: true)
    }
}
