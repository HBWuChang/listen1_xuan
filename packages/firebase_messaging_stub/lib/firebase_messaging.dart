import 'dart:async';

// Only the API used by feedback_push_transport.dart is provided here.
// No platform implementations or real Firebase dependencies belong in this package.
enum AuthorizationStatus { notDetermined, denied, authorized, provisional }

class NotificationSettings {
  const NotificationSettings({required this.authorizationStatus});
  final AuthorizationStatus authorizationStatus;
}

class RemoteNotification {
  const RemoteNotification({this.title});
  final String? title;
}

class RemoteMessage {
  const RemoteMessage({this.data = const {}, this.notification});
  final Map<String, dynamic> data;
  final RemoteNotification? notification;
}

class FirebaseMessaging {
  static final instance = FirebaseMessaging();
  static Stream<RemoteMessage> get onMessage => const Stream.empty();
  static Stream<RemoteMessage> get onMessageOpenedApp => const Stream.empty();
  Stream<String> get onTokenRefresh => const Stream.empty();
  Future<RemoteMessage?> getInitialMessage() async => null;
  Future<NotificationSettings> requestPermission() async => getNotificationSettings();
  Future<NotificationSettings> getNotificationSettings() async =>
      const NotificationSettings(authorizationStatus: AuthorizationStatus.denied);
  Future<String?> getToken() async => null;
  Future<void> deleteToken() async {}
  Future<void> setAutoInitEnabled(bool enabled) async {}
}
