import 'dart:async';
import 'dart:ui';

import 'package:cronet_http/cronet_http.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      options.release = 'boarding-bluster@1.0.2+5';
      options.tracesSampleRate = 0.2;
      options.attachScreenshot = false;
      options.sendDefaultPii = false;
    },
    appRunner: () async {
      WidgetsFlutterBinding.ensureInitialized();

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
        scaffoldBackgroundColor: const Color(0xFFEDF3FF),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFB930),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF060A1C),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFB930),
          brightness: Brightness.dark,
        ),
      ),
      home: const BoardingHomeShell(),
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor:
              dark ? const Color(0xFF0D1428) : const Color(0xFFEDF3FF),
          systemNavigationBarIconBrightness:
              dark ? Brightness.light : Brightness.dark,
        ),
        child: child!,
      ),
    );
  }
}

