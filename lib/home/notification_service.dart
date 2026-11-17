import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  NotificationService()
      : _db = Supabase.instance.client,
        _fcm = FirebaseMessaging.instance;

  final SupabaseClient _db;
  final FirebaseMessaging _fcm;

  /// Call once on app launch (after a good boarding run for first-time prompt).
  /// Returns true if notifications are currently authorized.
  Future<bool> requestPermissionIfNeeded() async {
    final status = await Permission.notification.status;
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) return false;
    final result = await Permission.notification.request();
    return result.isGranted;
  }

  /// Uploads the current FCM token for [playerId] to Supabase profiles.
  /// Safe to call on every launch — no-ops if token hasn't changed.
  Future<void> syncToken(String playerId) async {
    try {
      final token = await _fcm.getToken();
      if (token == null) return;
      await _db.from('profiles').update({'fcm_token': token}).eq('id', playerId);
      Sentry.addBreadcrumb(Breadcrumb(
        message: 'FCM token synced for $playerId',
        category: 'notifications',
        level: SentryLevel.info,
      ));
      // Refresh whenever the token rotates.
      _fcm.onTokenRefresh.listen((newToken) async {
        try {
          await _db
              .from('profiles')
              .update({'fcm_token': newToken}).eq('id', playerId);
        } catch (e, st) {
          await Sentry.captureException(e, stackTrace: st,
              hint: Hint.withMap({'place': 'fcm_token_refresh'}));
        }
      });
    } catch (e, st) {
      await Sentry.captureException(e, stackTrace: st,
          hint: Hint.withMap({'place': 'syncToken', 'player_id': playerId}));
    }
  }
}
