import 'package:google_sign_in/google_sign_in.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _googleClientId =
    '284949944908-2j3p30poivtnbpn6f2q55i6hsru54ijo.apps.googleusercontent.com';

class ShopService {
  ShopService() : _db = Supabase.instance.client;

  final SupabaseClient _db;

  static const _premiumKey = 'shop.premium_unlocked';
  static const _googleIdKey = 'shop.google_id';

  // ── Local cache ────────────────────────────────────────────────────────────

  Future<bool> isPremiumUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_premiumKey) ?? false;
  }

  Future<String?> cachedGoogleId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_googleIdKey);
  }

  Future<void> _cacheUnlocked(String googleId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumKey, true);
    await prefs.setString(_googleIdKey, googleId);
  }

  // ── Google Sign-In (v7 singleton API) ─────────────────────────────────────

  Future<void> initGoogleSignIn() async {
    await GoogleSignIn.instance.initialize(clientId: _googleClientId);
  }

  /// Tries silent auth first, then shows picker. Returns null on cancel/error.
  Future<GoogleSignInAccount?> signIn() async {
    try {
      await initGoogleSignIn();
      // Try lightweight (silent) first
      final silentFuture =
          GoogleSignIn.instance.attemptLightweightAuthentication();
      if (silentFuture != null) {
        final silent = await silentFuture;
        if (silent != null) return silent;
      }
      // Full interactive sign-in
      return await GoogleSignIn.instance.authenticate();
    } catch (e, st) {
      await Sentry.captureException(
        e,
        stackTrace: st,
        hint: Hint.withMap({'place': 'ShopService.signIn'}),
      );
      return null;
    }
  }

  // ── Purchase record ─────────────────────────────────────────────────────────

  /// Writes the purchase to Supabase. Returns true on success.
  Future<bool> recordPurchase({
    required String googleId,
    required String paymentId,
  }) async {
    Sentry.addBreadcrumb(Breadcrumb(
      message: 'recordPurchase: $googleId',
      category: 'shop',
      level: SentryLevel.info,
    ));
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await _db.from('purchases').upsert(
          {'google_id': googleId, 'payment_id': paymentId},
          onConflict: 'google_id',
        );
        await _cacheUnlocked(googleId);
        Sentry.addBreadcrumb(Breadcrumb(
          message: 'recordPurchase ok',
          category: 'shop',
          level: SentryLevel.info,
        ));
        return true;
      } catch (e, st) {
        if (attempt == 2) {
          await Sentry.captureException(
            e,
            stackTrace: st,
            hint: Hint.withMap({
              'place': 'recordPurchase',
              'google_id': googleId,
              'attempt': attempt,
            }),
          );
          return false;
        }
        await Future<void>.delayed(const Duration(milliseconds: 800));
      }
    }
    return false;
  }

  /// Checks Supabase for an existing purchase. Call after reinstall to restore.
  Future<bool> restorePurchase(String googleId) async {
    Sentry.addBreadcrumb(Breadcrumb(
      message: 'restorePurchase: $googleId',
      category: 'shop',
      level: SentryLevel.info,
    ));
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final rows = await _db
            .from('purchases')
            .select('google_id')
            .eq('google_id', googleId)
            .limit(1);
        if (rows.isNotEmpty) {
          await _cacheUnlocked(googleId);
          return true;
        }
        return false;
      } catch (e, st) {
        if (attempt == 2) {
          await Sentry.captureException(
            e,
            stackTrace: st,
            hint: Hint.withMap(
                {'place': 'restorePurchase', 'attempt': attempt}),
          );
          return false;
        }
        await Future<void>.delayed(const Duration(milliseconds: 800));
      }
    }
    return false;
  }
}
