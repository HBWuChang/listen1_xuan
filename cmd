fvm flutter build apk --split-per-abi
fvm flutter build apk --release --split-per-abi --dart-define=cronetHttpNoPlay=true
fvm flutter build windows
fvm dart run flutter_launcher_icons
fvm dart run build_runner build --delete-conflicting-outputs