import Foundation
import Darwin

struct KeylessCurseClientPaths {
    static let fileName = "libcurseclient.dylib"
    static let downloadURL = URL(string: "https://github.com/rooootdev/CurseClient-Rust/releases/download/latest/libcurseclient.dylib")!

    static var baseDir: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CurseClient", isDirectory: true)
    }

    static var libraryURL: URL {
        baseDir.appendingPathComponent(fileName, isDirectory: false)
    }

    static var libraryPath: String {
        libraryURL.path
    }

    static func isInstalled() -> Bool {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        return fm.fileExists(atPath: libraryPath, isDirectory: &isDir) && !isDir.boolValue
    }
}

enum KeylessCurseClientError: LocalizedError {
    case missingLibrary
    case loadFailed(String)
    case symbolMissing(String)
    case invalidResponse
    case invalidJSON

    var errorDescription: String? {
        switch self {
        case .missingLibrary:
            return "Keyless CurseForge library is not installed"
        case .loadFailed(let reason):
            return "Failed to load CurseClient dylib: \(reason)"
        case .symbolMissing(let name):
            return "Missing symbol in CurseClient dylib: \(name)"
        case .invalidResponse:
            return "Keyless CurseForge returned an invalid response"
        case .invalidJSON:
            return "Keyless CurseForge returned malformed JSON"
        }
    }
}

final class KeylessCurseClient {
    static let shared = KeylessCurseClient()

    typealias GetJSONFn = @convention(c) (UnsafePointer<CChar>?) -> UnsafeMutablePointer<CChar>?
    typealias FreeFn = @convention(c) (UnsafeMutablePointer<CChar>?) -> Void

    private var handle: UnsafeMutableRawPointer?
    private var getModsListJSON: GetJSONFn?
    private var getModFilesJSON: GetJSONFn?
    private var freeString: FreeFn?

    func ensureLoaded() throws {
        if handle != nil { return }
        guard KeylessCurseClientPaths.isInstalled() else {
            throw KeylessCurseClientError.missingLibrary
        }

        guard let handle = dlopen(KeylessCurseClientPaths.libraryPath, RTLD_NOW) else {
            let err = String(cString: dlerror())
            let jitEnabled = jessi_check_jit_enabled()
            let tsInstalled = jessi_is_trollstore_installed()
            var hint = ""
            if !jitEnabled {
                hint = " (JIT disabled; dyld bypass may be inactive)"
            } else if !tsInstalled {
                hint = " (TrollStore not detected; library validation may block dylibs)"
            }
            throw KeylessCurseClientError.loadFailed(err + hint)
        }

        guard let modsSym = dlsym(handle, "cc_getmodslistjson") else {
            dlclose(handle)
            throw KeylessCurseClientError.symbolMissing("cc_getmodslistjson")
        }
        guard let filesSym = dlsym(handle, "cc_getmodfilesjson") else {
            dlclose(handle)
            throw KeylessCurseClientError.symbolMissing("cc_getmodfilesjson")
        }
        guard let freeSym = dlsym(handle, "cc_free_string") else {
            dlclose(handle)
            throw KeylessCurseClientError.symbolMissing("cc_free_string")
        }

        self.handle = handle
        self.getModsListJSON = unsafeBitCast(modsSym, to: GetJSONFn.self)
        self.getModFilesJSON = unsafeBitCast(filesSym, to: GetJSONFn.self)
        self.freeString = unsafeBitCast(freeSym, to: FreeFn.self)
    }

    func modsListJSON(query: String) throws -> String {
        try ensureLoaded()
        guard let fn = getModsListJSON, let free = freeString else {
            throw KeylessCurseClientError.invalidResponse
        }
        return try withCString(query) { cstr in
            guard let raw = fn(cstr) else { throw KeylessCurseClientError.invalidResponse }
            let result = String(cString: raw)
            free(raw)
            return result
        }
    }

    func modFilesJSON(dllink: String) throws -> String {
        try ensureLoaded()
        guard let fn = getModFilesJSON, let free = freeString else {
            throw KeylessCurseClientError.invalidResponse
        }
        return try withCString(dllink) { cstr in
            guard let raw = fn(cstr) else { throw KeylessCurseClientError.invalidResponse }
            let result = String(cString: raw)
            free(raw)
            return result
        }
    }

    private func withCString<T>(_ value: String, _ body: (UnsafePointer<CChar>) throws -> T) throws -> T {
        try value.withCString { try body($0) }
    }
}

func downloadKeylessCurseClient(completion: @escaping (Result<Void, Error>) -> Void) {
    let fm = FileManager.default
    let tmpRoot = fm.temporaryDirectory.appendingPathComponent("jessi-curseclient-install", isDirectory: true)
    let workDir = tmpRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let downloadPath = workDir.appendingPathComponent(KeylessCurseClientPaths.fileName)

    let task = URLSession.shared.downloadTask(with: KeylessCurseClientPaths.downloadURL) { tempURL, _, error in
        if let error {
            completion(.failure(error))
            return
        }
        guard let tempURL else {
            completion(.failure(NSError(domain: "JESSI", code: 2, userInfo: [NSLocalizedDescriptionKey: "Download failed"])))
            return
        }

        do {
            try fm.createDirectory(at: workDir, withIntermediateDirectories: true)
            defer { try? fm.removeItem(at: workDir) }

            if fm.fileExists(atPath: downloadPath.path) { try? fm.removeItem(at: downloadPath) }
            try fm.moveItem(at: tempURL, to: downloadPath)

            let finalDir = KeylessCurseClientPaths.baseDir
            let staging = finalDir.deletingLastPathComponent()
                .appendingPathComponent("CurseClient.staging-\(UUID().uuidString)", isDirectory: true)
            if fm.fileExists(atPath: staging.path) { try? fm.removeItem(at: staging) }
            try fm.createDirectory(at: staging, withIntermediateDirectories: true)

            let stagedFile = staging.appendingPathComponent(KeylessCurseClientPaths.fileName, isDirectory: false)
            if fm.fileExists(atPath: stagedFile.path) { try? fm.removeItem(at: stagedFile) }
            try fm.moveItem(at: downloadPath, to: stagedFile)

            if fm.fileExists(atPath: finalDir.path) {
                let backup = finalDir.deletingLastPathComponent()
                    .appendingPathComponent("CurseClient.backup-\(UUID().uuidString)", isDirectory: true)
                try? fm.removeItem(at: backup)
                try fm.moveItem(at: finalDir, to: backup)
                try? fm.removeItem(at: backup)
            }

            try fm.moveItem(at: staging, to: finalDir)
            completion(.success(()))
        } catch {
            completion(.failure(error))
        }
    }

    task.resume()
}
