# macOS direct-download updater

The Runner Debug, Profile and Release configurations must set
`ENABLE_APP_SANDBOX = NO`. Xcode's generated signing entitlements can otherwise
turn App Sandbox on even when the checked-in entitlement file says `false`.
Direct-download builds replace their own application bundle and launch an
external helper; they are not Mac App Store builds.

`MacosUpdater` extracts both Release ZIPs and Actions artifacts with macOS
`ditto`. Keep the framework symlinks and executable modes intact. In particular,
`App.framework/Resources -> Versions/Current/Resources` is needed to resolve the
Flutter assets directory. A missing link can cause `FlutterEngine.loadAOTData`
to insert a nil assets path into an NSArray and abort before Dart starts.

Before offering installation, validate the bundle identifier, executable,
Flutter resources and complete code signature. The detached Bash helper stages
the bundle on the installation volume and validates it again. The application
quits only after the helper signals readiness. The helper then moves the old
bundle aside, installs the staged bundle and requests launch. A failed move or
launch request restores the old bundle. Launch-request success does not prove
the new process remains healthy. Diagnostics go to `update_macos.log` in the
app's download directory. Non-writable install locations require manual
installation; the helper does not request administrator privileges.

The first non-sandboxed launch imports legacy Application Support data and
preferences before starting Flutter. Existing destination data takes priority;
the original container remains intact.

For an already damaged installation, extract an intact Release ZIP in Finder
or with `/usr/bin/ditto -x -k`, then replace the app manually. Do not reuse an
application bundle extracted by the old updater. The old sandboxed updater
requires one manual installation of a fixed build.

Verification:

- `flutter test test/macos_updater_test.dart` (macOS)
- `python3 -m unittest scripts.tests.test_macos_migration`
- `flutter build macos --release`

The macOS workflow verifies the packaged app's framework links, signature and
actual signing entitlements before uploading it.
