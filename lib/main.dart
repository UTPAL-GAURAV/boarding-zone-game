import 'dart:async';
import 'dart:ui';

import 'package:cronet_http/cronet_http.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home/boarding_home_shell.dart';

const _sentryDsn = 'https://2c6b906a81468551cdf862646d84cf5c@o4511406258257920.ingest.de.sentry.io/4512349082681424';

Future<void> main() async {
  await SentryFlutter.init(
    (options) {
      options.dsn = _sentryDsn;
      options.environment = const String.fromEnvironment(
        'FLUTTER_ENV',
        defaultValue: 'production',
      );
      options.release = 'boarding-bluster@1.0.0';
      options.tracesSampleRate = 0.2;
      options.attachScreenshot = false;
      options.sendDefaultPii = false;
    },
    appRunner: () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Catch Flutter framework errors (widget build failures, etc.).
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

      // Catch async Dart errors outside the Flutter zone.
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
        anonKey:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpmemJidnRkZ3draHJidGx2am1tIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMzOTYyMjksImV4cCI6MjEwODk3MjIyOX0.61XvOkSuyaPsy1dV9x4JT1TBxamuJSqXpXmbHMaSYkg',
        httpClient: CronetClient.defaultCronetEngine(),
      );

      runApp(const BoardingZoneApp());
    },
  );
}

class BoardingZoneApp extends StatelessWidget {
  const BoardingZoneApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Boarding Bluster',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0A0E1A),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFFFB930),
        brightness: Brightness.dark,
      ),
      fontFamily: 'sans-serif',
    ),
    home: const BoardingHomeShell(),
    builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF151C2E),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: child!,
    ),
  );
}
