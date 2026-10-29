import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:boarding_zone_game/main.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('fleet carousel offers navigation and the existing game', (
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
    await tester.tap(find.text('START FLIGHT'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('START BOARDING'), findsOneWidget);
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
    await tester.drag(find.byType(ListView).first, const Offset(-2400, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ATR 72-600'));
    await tester.pumpAndSettle();
    expect(find.text('Complete CRJ-700 under 09:15'), findsNothing);
    expect(find.text('START FLIGHT'), findsOneWidget);

    await tester.tap(find.text('START FLIGHT'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('0 / 72'), findsOneWidget);
  });
}
