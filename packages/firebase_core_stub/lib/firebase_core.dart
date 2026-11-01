// Build-time placeholder. This package deliberately declares no native plugin.
class FirebaseOptions {
  const FirebaseOptions({required this.projectId});
  final String projectId;
}

class FirebaseApp {
  const FirebaseApp();
  FirebaseOptions get options => const FirebaseOptions(projectId: '');
}

class Firebase {
  static Future<FirebaseApp> initializeApp() => Future.error(
    UnsupportedError('Firebase is excluded from this build'),
  );
  static FirebaseApp app() => throw UnsupportedError('Firebase is excluded from this build');
}
