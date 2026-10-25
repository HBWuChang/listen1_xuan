import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    LegacySandboxMigration.run()
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}


/// Preserve settings when moving from the old sandboxed direct-download build.
enum LegacySandboxMigration {
  static func run(
    home: URL = FileManager.default.homeDirectoryForCurrentUser,
    identifier: String = Bundle.main.bundleIdentifier ?? "com.xiebian.listen1Xuan",
    defaults: UserDefaults = .standard
  ) {
    let marker = "listen1SandboxMigrationV1"
    if defaults.bool(forKey: marker) { return }
    let manager = FileManager.default
    let legacy = home.appendingPathComponent("Library/Containers/\(identifier)/Data/Library")
    // Sandboxed builds must never try to migrate their own container.
    if home.path.contains("/Library/Containers/") { return }
    guard manager.fileExists(atPath: legacy.path) else { return }
    do {
      let source = legacy.appendingPathComponent("Application Support/\(identifier)")
      let target = home.appendingPathComponent("Library/Application Support/\(identifier)")
      if manager.fileExists(atPath: source.path) {
        try manager.createDirectory(at: target, withIntermediateDirectories: true)
        for item in try manager.contentsOfDirectory(at: source, includingPropertiesForKeys: nil) {
          let destination = target.appendingPathComponent(item.lastPathComponent)
          // Existing non-sandbox data wins; never merge or overwrite Hive files.
          if !manager.fileExists(atPath: destination.path) {
            let staging = target.appendingPathComponent(".migration-\(UUID().uuidString)")
            do {
              try manager.copyItem(at: item, to: staging)
              try manager.moveItem(at: staging, to: destination)
            } catch {
              try? manager.removeItem(at: staging)
              throw error
            }
          }
        }
      }
      let preferences = legacy.appendingPathComponent("Preferences/\(identifier).plist")
      if manager.fileExists(atPath: preferences.path) {
        let data = try Data(contentsOf: preferences)
        if let old = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
          var current = defaults.persistentDomain(forName: identifier) ?? [:]
          for (key, value) in old where current[key] == nil { current[key] = value }
          current[marker] = true
          defaults.setPersistentDomain(current, forName: identifier)
          return
        }
      }
      defaults.set(true, forKey: marker)
    } catch {
      // Leave the original container intact and retry migration on next launch.
      NSLog("Legacy sandbox data migration failed: %@", String(describing: error))
    }
  }
}
