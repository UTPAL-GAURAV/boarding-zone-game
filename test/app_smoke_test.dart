import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:boarding_zone_game/boarding/boarding_game_page.dart';
import 'package:boarding_zone_game/boarding/levels/level_saab340.dart';
import 'package:boarding_zone_game/main.dart';

void main() {
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

    expect(find.text('Boarding Zone'), findsOneWidget);
    expect(find.text('Cessna Grand Caravan EX'), findsAtLeastNWidgets(1));
    expect(
      find.bySemanticsLabel('Cessna manufacturer logo'),
      findsAtLeastNWidgets(1),
    );
    expect(find.text('START FLIGHT'), findsOneWidget);
    expect(find.textContaining('Crew '), findsOneWidget);
    expect(find.text('World Rankings'), findsNothing);
    expect(find.text('Fleet'), findsAtLeastNWidgets(1));
    expect(find.text('Rankings'), findsOneWidget);
    expect(find.text('Shop'), findsOneWidget);

    await tester.tap(find.text('Rankings').last);
    await tester.pumpAndSettle();
    expect(find.text('World Rankings'), findsOneWidget);
    expect(find.textContaining('Sample rankings only'), findsOneWidget);
    expect(find.text('PREVIEW LIST'), findsOneWidget);

    await tester.tap(find.text('Shop').last);
    await tester.pumpAndSettle();
    expect(find.text('Aircraft Shop'), findsOneWidget);
    expect(find.text('Airbus A350-900'), findsOneWidget);

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
    await tester.tap(find.byTooltip('Reset seats to Zone F'));
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
    expect(find.text('Crew profile'), findsOneWidget);

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

    for (var frame = 0; frame < 500; frame++) {
      if (find.text('NEXT FLIGHT').evaluate().isNotEmpty) break;
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('NEXT FLIGHT'), findsOneWidget);

    await tester.tap(find.text('NEXT FLIGHT'));
    await tester.pumpAndSettle();
    expect(find.text('Fleet'), findsAtLeastNWidgets(1));
    expect(find.text('Cessna SkyCourier'), findsAtLeastNWidgets(1));
    expect(
      tester.getCenter(find.text('Cessna SkyCourier').first).dx,
      closeTo(tester.view.physicalSize.width / 2, 24),
    );
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

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
  });

  testWidgets('a qualifying local ATR 42 time unlocks the ATR 72 layout', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'aircraft.best_seconds.cessna-grand-caravan-ex': 299,
      'aircraft.best_seconds.cessna-skycourier': 359,
      'aircraft.best_seconds.saab-340b': 419,
      'aircraft.best_seconds.atr-42-600': 479,
      'aircraft.best_seconds.embraer-erj-145': 509,
      'aircraft.best_seconds.saab-2000': 509,
      'aircraft.best_seconds.ilyushin-il-114-300': 539,
      'aircraft.best_seconds.bombardier-crj-700': 554,
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
    expect(find.text('Complete CRJ-700 under 09:15'), findsNothing);
    expect(find.text('0 / 72'), findsOneWidget);
  });
}
