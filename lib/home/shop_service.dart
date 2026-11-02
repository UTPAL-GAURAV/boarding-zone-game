import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _googleClientId =
    '284949944908-sa94cbj5g93pv51fr500rb61ktn1pcq5.apps.googleusercontent.com';

class ShopService {
  ShopService() : _db = Supabase.instance.client;

  final SupabaseClient _db;

  static const _premiumKey = 'shop.premium_unlocked';
  static const _googleIdKey = 'shop.google_id';
  static const _emailKey = 'shop.email';

  // ── Local cache ────────────────────────────────────────────────────────────

  Future<bool> isPremiumUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_premiumKey) ?? false;
  }

  Future<String?> cachedGoogleId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_googleIdKey);
  }

  Future<String?> cachedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey);
  }

  Future<void> _cacheGoogleId(String googleId, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_googleIdKey, googleId);
    await prefs.setString(_emailKey, email);
  }

  Future<void> _cacheUnlocked(String googleId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumKey, true);
    await prefs.setString(_googleIdKey, googleId);
  }

  // ── Google Sign-In (v7 singleton API) ─────────────────────────────────────

  Future<void> initGoogleSignIn() async {
    await GoogleSignIn.instance.initialize(serverClientId: _googleClientId);
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
        if (silent != null) {
          await _cacheGoogleId(silent.id, silent.email);
          return silent;
        }
      }
      // Full interactive sign-in
      final account = await GoogleSignIn.instance.authenticate();
      await _cacheGoogleId(account.id, account.email);
      return account;
    } catch (e, st) {
      debugPrint('[ShopService.signIn] ERROR: $e\n$st');
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
    required String email,
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
          {'google_id': googleId, 'email': email, 'payment_id': paymentId},
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
