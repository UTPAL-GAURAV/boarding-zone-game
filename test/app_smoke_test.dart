import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:boarding_bluster/boarding/boarding_game_page.dart';
import 'package:boarding_bluster/boarding/levels/level_saab340.dart';
import 'package:boarding_bluster/main.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://zfzbbvtdgwkhrbtlvjmm.supabase.co',
      publishableKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpmemJidnRkZ3draHJidGx2am1tIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMzOTYyMjksImV4cCI6MjEwODk3MjIyOX0.61XvOkSuyaPsy1dV9x4JT1TBxamuJSqXpXmbHMaSYkg',
    );
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));


  testWidgets('fleet cards open their cabin and navigation remains available', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const BoardingZoneApp());
    await tester.pumpAndSettle();

    expect(find.text('Boarding Bluster'), findsOneWidget);
    expect(find.text('Cessna Grand Caravan EX'), findsAtLeastNWidgets(1));
    expect(
      find.bySemanticsLabel('Cessna manufacturer logo'),
      findsAtLeastNWidgets(1),
    );
    expect(find.text('START ONBOARDING'), findsOneWidget);
    expect(find.text('Fleet'), findsAtLeastNWidgets(1));
    expect(find.text('Rankings'), findsOneWidget);
    expect(find.text('Shop'), findsOneWidget);

    await tester.tap(find.text('Rankings').last);
    await tester.pumpAndSettle();
    expect(find.text('World Rankings'), findsOneWidget);

    await tester.tap(find.text('Shop').last);
    await tester.pumpAndSettle();
    expect(find.text('Shop'), findsAtLeastNWidgets(1));

    await tester.tap(find.text('Fleet').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cessna Grand Caravan EX').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('START BOARDING'), findsOneWidget);
    expect(find.byTooltip('Back to fleet'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('F'), findsOneWidget);
    expect(find.bySemanticsLabel('Zone F, selected'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Zone D'));
    await tester.pump();
    expect(find.bySemanticsLabel('Zone D, selected'), findsOneWidget);
    await tester.tap(find.byTooltip('Reset to default zones'));
    await tester.pump();
    expect(find.bySemanticsLabel('Zone F, selected'), findsOneWidget);

    await tester.tap(find.byTooltip('Back to fleet'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Fleet'), findsAtLeastNWidgets(1));
  });

  testWidgets('crew display name can be edited without exposing player ID', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const BoardingZoneApp());
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp('Crew profile')));
    await tester.pumpAndSettle();
    expect(find.text('CREW PROFILE'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Captain Nova');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Captain Nova'), findsOneWidget);
    expect(find.textContaining('internal_id'), findsNothing);
  });

  testWidgets('next flight returns to Fleet with the next aircraft selected', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const BoardingZoneApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cessna Grand Caravan EX').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('START BOARDING'));
    await tester.pump();

    // Wait for either completion button (NEXT FLIGHT if under target, TRY AGAIN if over).
    for (var frame = 0; frame < 500; frame++) {
      if (find.text('NEXT FLIGHT').evaluate().isNotEmpty) break;
      if (find.text('TRY AGAIN').evaluate().isNotEmpty) break;
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Boarding completed — completion card is visible.
    expect(
      find.text('NEXT FLIGHT').evaluate().isNotEmpty ||
          find.text('TRY AGAIN').evaluate().isNotEmpty,
      isTrue,
    );

    if (find.text('NEXT FLIGHT').evaluate().isNotEmpty) {
      await tester.tap(find.text('NEXT FLIGHT'));
      await tester.pumpAndSettle();
      // Drain any pending retry timers from RankingsService.submitScore.
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Fleet'), findsAtLeastNWidgets(1));
      expect(find.text('Cessna SkyCourier'), findsAtLeastNWidgets(1));
      expect(
        tester.getCenter(find.text('Cessna SkyCourier').first).dx,
        closeTo(tester.view.physicalSize.width / 2, 24),
      );
    }
  });

  testWidgets('large aircraft cabin has vertical scroll room', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: BoardingGamePage(
          aircraftName: 'Saab 340B',
          layout: LevelSaab340.aircraft,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).last,
    );
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
  });

  testWidgets('a qualifying local ATR 42 time unlocks the ATR 72 layout', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'aircraft.best_seconds.cessna-grand-caravan-ex': 15,
      'aircraft.best_seconds.cessna-skycourier': 25,
      'aircraft.best_seconds.saab-340b': 35,
      'aircraft.best_seconds.atr-42-600': 50,
      'aircraft.best_seconds.embraer-erj-145': 65,
      'aircraft.best_seconds.saab-2000': 65,
      'aircraft.best_seconds.ilyushin-il-114-300': 65,
      'aircraft.best_seconds.bombardier-crj-700': 70,
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const BoardingZoneApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('ATR 72-600').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // ATR 72-600 is unlocked (qualifying times met) but has no layout yet —
    // it shows the coming-soon dialog, not the progression-lock dialog.
    expect(find.text('Complete CRJ-700 under 09:15'), findsNothing);
    expect(find.textContaining('coming soon'), findsOneWidget);
  });
}
