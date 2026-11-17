import 'dart:async';
import 'dart:ui';

import 'package:cronet_http/cronet_http.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home/boarding_home_shell.dart';
import 'home/local_profile_store.dart';

const _sentryDsn = 'https://2c6b906a81468551cdf862646d84cf5c@o4511406258257920.ingest.de.sentry.io/4512349082681424';

/// Global theme-mode notifier — any widget can write to this and the root app rebuilds.
final appThemeMode = ValueNotifier<ThemeMode>(ThemeMode.light);

Future<void> main() async {
  await SentryFlutter.init(
    (options) {
      options.dsn = _sentryDsn;
      options.environment = const String.fromEnvironment(
        'FLUTTER_ENV',
        defaultValue: 'production',
      );
      options.release = 'boarding-bluster@1.0.4+8';
      options.tracesSampleRate = 0.2;
      options.attachScreenshot = false;
      options.sendDefaultPii = false;
    },
    appRunner: () async {
      WidgetsFlutterBinding.ensureInitialized();

      await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        unawaited(Sentry.captureException(
          details.exception,
          stackTrace: details.stack,
          hint: Hint.withMap({
            'place': 'FlutterError.onError',
            'context': details.context?.toDescription() ?? '',
          }),
        ));
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        unawaited(Sentry.captureException(
          error,
          stackTrace: stack,
          hint: Hint.withMap({'place': 'PlatformDispatcher.onError'}),
        ));
        return true;
      };

      await Supabase.initialize(
        url: 'https://zfzbbvtdgwkhrbtlvjmm.supabase.co',
        publishableKey:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpmemJidnRkZ3draHJidGx2am1tIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMzOTYyMjksImV4cCI6MjEwODk3MjIyOX0.61XvOkSuyaPsy1dV9x4JT1TBxamuJSqXpXmbHMaSYkg',
        httpClient: CronetClient.defaultCronetEngine(),
      );

      await Firebase.initializeApp();

      // Restore persisted theme before the first frame.
      final stored = await LocalProfileStore().loadThemeMode();
      appThemeMode.value = _parseThemeMode(stored);

      runApp(const BoardingZoneApp());
    },
  );
}

ThemeMode _parseThemeMode(String value) => switch (value) {
  'light' => ThemeMode.light,
  'system' => ThemeMode.system,
  _ => ThemeMode.dark,
};

class BoardingZoneApp extends StatefulWidget {
  const BoardingZoneApp({super.key});

  @override
  State<BoardingZoneApp> createState() => _BoardingZoneAppState();
}

class _BoardingZoneAppState extends State<BoardingZoneApp> {
  @override
  void initState() {
    super.initState();
    appThemeMode.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    appThemeMode.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final mode = appThemeMode.value;
    final dark = mode == ThemeMode.dark ||
        (mode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return MaterialApp(
      title: 'Boarding Bluster',
      debugShowCheckedModeBanner: false,
      themeMode: mode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        textTheme: _weightedTextTheme(GoogleFonts.rajdhaniTextTheme(ThemeData.light().textTheme)),
        scaffoldBackgroundColor: const Color(0xFFEDF3FF),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2F8FFF),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        textTheme: _weightedTextTheme(GoogleFonts.rajdhaniTextTheme(ThemeData.dark().textTheme)),
        scaffoldBackgroundColor: const Color(0xFF0D0F14),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2F8FFF),
          brightness: Brightness.dark,
        ),
      ),
      home: const BoardingHomeShell(),
      builder: (context, child) {
        // Clamp text scale to max 1.2 so large system font sizes don't overflow layouts.
        final mq = MediaQuery.of(context);
        final clamped = mq.copyWith(
          textScaler: TextScaler.linear(mq.textScaler.scale(1.0).clamp(0.8, 1.2)),
        );
        return MediaQuery(
          data: clamped,
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
              systemNavigationBarColor:
                  dark ? const Color(0xFF0D0F14) : const Color(0xFFEDF3FF),
              systemNavigationBarIconBrightness:
                  dark ? Brightness.light : Brightness.dark,
            ),
            child: child!,
          ),
        );
      },
    );
  }
}

// Bumps every text style in the theme to at least w600 so body copy
// (which Rajdhani renders thin at w400) is comfortably readable.
TextTheme _weightedTextTheme(TextTheme base) {
  TextStyle _bump(TextStyle? s) {
    if (s == null) return const TextStyle(fontWeight: FontWeight.w600);
    final w = s.fontWeight?.index ?? FontWeight.w400.index;
    return s.copyWith(
      fontWeight: w < FontWeight.w600.index ? FontWeight.w600 : s.fontWeight,
    );
  }

  return base.copyWith(
    displayLarge: _bump(base.displayLarge),
    displayMedium: _bump(base.displayMedium),
    displaySmall: _bump(base.displaySmall),
    headlineLarge: _bump(base.headlineLarge),
    headlineMedium: _bump(base.headlineMedium),
    headlineSmall: _bump(base.headlineSmall),
    titleLarge: _bump(base.titleLarge),
    titleMedium: _bump(base.titleMedium),
    titleSmall: _bump(base.titleSmall),
    bodyLarge: _bump(base.bodyLarge),
    bodyMedium: _bump(base.bodyMedium),
    bodySmall: _bump(base.bodySmall),
    labelLarge: _bump(base.labelLarge),
    labelMedium: _bump(base.labelMedium),
    labelSmall: _bump(base.labelSmall),
  );
}
