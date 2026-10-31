import '../boarding/aircraft_layout.dart';
import '../boarding/levels/level_767.dart';
import '../boarding/levels/level_a380.dart';
import '../boarding/levels/level_c208.dart';
import '../boarding/levels/level_one.dart';
import '../boarding/levels/level_saab340.dart';
import '../boarding/levels/level_skycourier.dart';
import '../boarding/levels/level_three.dart';
import '../boarding/levels/level_two.dart';
import '../boarding/levels/level_wide_232.dart';
import '../boarding/levels/level_wide_333.dart';
import 'aircraft.dart';

/// Adapter between fleet metadata and the independently authored game levels.
abstract final class AircraftLevelRegistry {
  static final Map<String, AircraftLayout> _layouts = {
    'level_c208': LevelC208.aircraft,
    'level_skycourier': LevelSkyCourier.aircraft,
    'level_saab340': LevelSaab340.aircraft,
    'level_one': LevelOne.aircraft,
    'level_two': LevelTwo.aircraft,
    'level_three': LevelThree.aircraft,
    'level_767_242': Level767.aircraft,
    'level_wide_232': LevelWide232.aircraft,
    'level_wide_333': LevelWide333.aircraft,
    'level_a380_343': LevelA380.aircraft,
  };

  static AircraftLayout? resolve(Aircraft aircraft) {
    final key = aircraft.gameLayoutId;
    return key == null ? null : _layouts[key];
  }
}
