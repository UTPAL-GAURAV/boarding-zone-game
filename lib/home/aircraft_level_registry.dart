import '../boarding/aircraft_layout.dart';
import '../boarding/levels/level_c208.dart';
import '../boarding/levels/level_one.dart';
import '../boarding/levels/level_saab340.dart';
import '../boarding/levels/level_skycourier.dart';
import '../boarding/levels/level_two.dart';
import 'aircraft.dart';

/// Adapter between fleet metadata and the independently authored game levels.
abstract final class AircraftLevelRegistry {
  static final Map<String, AircraftLayout> _layouts = {
    'level_c208': LevelC208.aircraft,
    'level_skycourier': LevelSkyCourier.aircraft,
    'level_saab340': LevelSaab340.aircraft,
    'level_one': LevelOne.aircraft,
    'level_two': LevelTwo.aircraft,
  };

  static AircraftLayout? resolve(Aircraft aircraft) {
    final key = aircraft.gameLayoutId;
    return key == null ? null : _layouts[key];
  }
}
