import Foundation
import AppKit
import SwiftUI
import Combine

@MainActor
class UpdateChecker: ObservableObject {
    private let RELEASE_URL = "https://github.com/Speedly-dk/recorder-app/releases/tag/v"
    private let API_URL = "https://api.github.com/repos/Speedly-dk/recorder-app/releases"

    @Published var updateAvailable = false
    @Published var latestVersion: String?
    @Published var isChecking = false
    @Published var lastCheckError: Error?

    private var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    var updateURL: String {
        guard let version = latestVersion else { return "" }
        return RELEASE_URL + version
    }

    func checkForUpdates() async {
        guard !isChecking else { return }

        await MainActor.run {
            isChecking = true
            lastCheckError = nil
        }

        defer {
            Task { @MainActor in
                isChecking = false
            }
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: URL(string: API_URL)!)

            let releases = try JSONDecoder().decode([FailableDecodable<GHRelease>].self, from: data)
                .compactMap { $0.base }

            guard let latestRelease = releases.first else {
                print("No releases found")
                return
            }

            let tagName = latestRelease.tag_name
            let versionString = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName

            await MainActor.run {
                self.latestVersion = versionString
                self.updateAvailable = isNewerVersion(versionString, than: currentVersion)

                if updateAvailable {
                    print("Update available: \(currentVersion) -> \(versionString)")
                } else {
                    print("Current version \(currentVersion) is up to date")
                }
            }
        } catch {
            await MainActor.run {
                self.lastCheckError = error
                print("Update check failed: \(error.localizedDescription)")
            }
        }
    }

    func openReleasePage() {
        guard let version = latestVersion else { return }
        if let url = URL(string: RELEASE_URL + version) {
            NSWorkspace.shared.open(url)
        }
    }

    private func isNewerVersion(_ new: String, than current: String) -> Bool {
        let newComponents = parseVersion(new)
        let currentComponents = parseVersion(current)

        if newComponents.major > currentComponents.major { return true }
        if newComponents.major < currentComponents.major { return false }

        if newComponents.minor > currentComponents.minor { return true }
        if newComponents.minor < currentComponents.minor { return false }

        if newComponents.patch > currentComponents.patch { return true }

        return false
    }

    private func parseVersion(_ version: String) -> (major: Int, minor: Int, patch: Int) {
        let components = version.split(separator: ".").compactMap { Int($0) }
        let major = components.count > 0 ? components[0] : 0
        let minor = components.count > 1 ? components[1] : 0
        let patch = components.count > 2 ? components[2] : 0
        return (major, minor, patch)
    }
}

struct GHRelease: Decodable {
    let tag_name: String
}

struct FailableDecodable<Base: Decodable>: Decodable {
    let base: Base?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.base = try? container.decode(Base.self)
    }
}