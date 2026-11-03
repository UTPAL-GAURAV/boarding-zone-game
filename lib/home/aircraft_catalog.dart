import 'aircraft.dart';
import '../boarding/levels/level_c208.dart';
import '../boarding/levels/level_skycourier.dart';
import '../boarding/levels/level_saab340.dart';
import '../boarding/levels/level_4abreast.dart';
import '../boarding/levels/level_atr42.dart';
import '../boarding/levels/level_saab2000.dart';
import '../boarding/levels/level_il114.dart';
import '../boarding/levels/level_crj700.dart';
import '../boarding/levels/level_atr72.dart';
import '../boarding/levels/level_e170.dart';
import '../boarding/levels/level_dash8.dart';
import '../boarding/levels/level_e175.dart';
import '../boarding/levels/level_an148.dart';
import '../boarding/levels/level_arj21.dart';
import '../boarding/levels/level_an158.dart';
import '../boarding/levels/level_e190.dart';
import '../boarding/levels/level_superjet.dart';
import '../boarding/levels/level_a220_100.dart';
import '../boarding/levels/level_e195.dart';
import '../boarding/levels/level_a319.dart';
import '../boarding/levels/level_b737_700.dart';
import '../boarding/levels/level_a220_300.dart';
import '../boarding/levels/level_a320.dart';
import '../boarding/levels/level_c919.dart';
import '../boarding/levels/level_b737_800.dart';
import '../boarding/levels/level_a321neo.dart';
import '../boarding/levels/level_b737_9.dart';
import '../boarding/levels/level_dual_aisle.dart';
import '../boarding/levels/level_b757.dart';
import '../boarding/levels/level_a321xlr.dart';
import '../boarding/levels/level_767.dart';
import '../boarding/levels/level_a330_200.dart';
import '../boarding/levels/level_787_8.dart';
import '../boarding/levels/level_il96.dart';
import '../boarding/levels/level_a330_300.dart';
import '../boarding/levels/level_787_9.dart';
import '../boarding/levels/level_777_200er.dart';
import '../boarding/levels/level_a350_900.dart';
import '../boarding/levels/level_a350_1000.dart';
import '../boarding/levels/level_777_300er.dart';
import '../boarding/levels/level_747_8.dart';
import '../boarding/levels/level_a380.dart';

void registerAircraftCatalog() {
  AircraftCatalog.register([
    const Aircraft(
      id: 'cessna-grand-caravan-ex',
      level: 1,
      manufacturer: 'Cessna',
      model: 'Grand Caravan EX',
      description:
          'A rugged single-engine commuter that opened up routes no paved runway could serve.',
      imageAsset: 'assets/aircraft/cessna-grand-caravan-ex.jpeg',
      typicalSeats: 14,
      targetSeconds: 22,
      unlockType: AircraftUnlockType.free,
      layout: LevelC208.aircraft,
    ),
    const Aircraft(
      id: 'cessna-skycourier',
      level: 2,
      manufacturer: 'Cessna',
      model: 'SkyCourier',
      description:
          'A twin-engine utility turboprop designed for high-frequency short hops.',
      imageAsset: 'assets/aircraft/cessna-skycourier.jpeg',
      typicalSeats: 20,
      targetSeconds: 26,
      unlockType: AircraftUnlockType.progression,
      unlockRequirement: 'Complete Grand Caravan EX under 05:00',
      layout: LevelSkyCourier.aircraft,
    ),
    const Aircraft(
      id: 'saab-340b',
      level: 3,
      manufacturer: 'Saab',
      model: '340B',
      description:
          'A compact turboprop beloved by regional operators for its efficiency and range.',
      imageAsset: 'assets/aircraft/saab-340b.jpeg',
      typicalSeats: 34,
      targetSeconds: 32,
      unlockType: AircraftUnlockType.progression,
      unlockRequirement: 'Complete SkyCourier under 06:00',
      layout: LevelSaab340.aircraft,
    ),
    const Aircraft(
      id: 'atr-42-600',
      level: 4,
      manufacturer: 'ATR',
      model: '42-600',
      description: 'A compact turboprop built for short regional hops.',
      imageAsset: 'assets/aircraft/atr-42-600.jpeg',
      typicalSeats: 48,
      targetSeconds: 56,
      unlockType: AircraftUnlockType.progression,
      unlockRequirement: 'Complete 340B under 07:00',
      layout: LevelAtr42.aircraft,
    ),
    const Aircraft(
      id: 'embraer-erj-145',
      level: 5,
      manufacturer: 'Embraer',
      model: 'ERJ-145',
      description: 'A slim regional jet that brought jet comfort to thin routes.',
      imageAsset: 'assets/aircraft/embraer-erj-145.jpeg',
      typicalSeats: 52,
      targetSeconds: 66,
      unlockType: AircraftUnlockType.progression,
      unlockRequirement: 'Complete 42-600 under 08:00',
      layout: Level4Abreast.aircraft,
    ),
    const Aircraft(
      id: 'saab-2000',
      level: 6,
      manufacturer: 'Saab',
      model: '2000',
      description:
          'A fast regional turboprop engineered to compete with short-haul jets.',
      imageAsset: 'assets/aircraft/saab-2000.jpeg',
      typicalSeats: 52,
      targetSeconds: 70,
      unlockType: AircraftUnlockType.progression,
      unlockRequirement: 'Complete ERJ-145 under 08:30',
      layout: LevelSaab2000.aircraft,
    ),
    const Aircraft(
      id: 'ilyushin-il-114-300',
      level: 7,
      manufacturer: 'Ilyushin',
      model: 'Il-114-300',
      description:
          'A modernized turboprop reviving Soviet-era short-haul efficiency.',
      imageAsset: 'assets/aircraft/ilyushin-il-114-300.jpeg',
      typicalSeats: 60,
      targetSeconds: 72,
      unlockType: AircraftUnlockType.progression,
      unlockRequirement: 'Complete Saab 2000 under 08:30',
      layout: LevelIl114.aircraft,
    ),
    const Aircraft(
      id: 'bombardier-crj-700',
      level: 8,
      manufacturer: 'Bombardier',
      model: 'CRJ-700',
      description: 'A stretched regional jet that redefined the 70-seat market.',
      imageAsset: 'assets/aircraft/bombardier-crj-700.jpeg',
      typicalSeats: 72,
      targetSeconds: 78,
      unlockType: AircraftUnlockType.progression,
      unlockRequirement: 'Complete Il-114-300 under 09:00',
      layout: LevelCrj700.aircraft,
    ),
    const Aircraft(
      id: 'atr-72-600',
      level: 9,
      manufacturer: 'ATR',
      model: '72-600',
      description: 'A high-wing regional workhorse for busy short routes.',
      imageAsset: 'assets/aircraft/atr-72-600.jpeg',
      typicalSeats: 72,
      targetSeconds: 90,
      unlockType: AircraftUnlockType.progression,
      unlockRequirement: 'Complete CRJ-700 under 09:15',
      layout: LevelAtr72.aircraft,
    ),
    const Aircraft(
      id: 'embraer-e170',
      level: 10,
      manufacturer: 'Embraer',
      model: 'E170',
      description:
          'A clean-sheet E-Jet that brought new economy to 70-seat flying.',
      imageAsset: 'assets/aircraft/embraer-e170.jpeg',
      typicalSeats: 72,
      targetSeconds: 110,
      unlockType: AircraftUnlockType.progression,
      unlockRequirement: 'Complete 72-600 under 09:00',
      layout: LevelE170.aircraft,
    ),
    const Aircraft(
      id: 'dash-8-q400',
      level: 11,
      manufacturer: 'De Havilland Canada',
      model: 'Dash 8-400',
      description:
          'A high-speed turboprop that rivals jets on short sectors.',
      imageAsset: 'assets/aircraft/dash-8-q400.jpeg',
      typicalSeats: 80,
      targetSeconds: 90,
      unlockType: AircraftUnlockType.progression,
      unlockRequirement: 'Complete E170 under 09:15',
      layout: LevelDash8.aircraft,
    ),
    const Aircraft(
      id: 'embraer-e175',
      level: 12,
      manufacturer: 'Embraer',
      model: 'E175',
      description:
          'A stretched E-Jet balancing capacity and operating economics.',
      imageAsset: 'assets/aircraft/embraer-e175.jpeg',
      typicalSeats: 80,
      targetSeconds: 84,
      unlockType: AircraftUnlockType.progression,
      unlockRequirement: 'Complete Dash 8-400 under 09:30',
      layout: LevelE175.aircraft,
    ),
    const Aircraft(
      id: 'antonov-an-148',
      level: 13,
      manufacturer: 'Antonov',
      model: 'An-148',
      description:
          'A Ukrainian regional jet built for rough airstrips and harsh climates.',
      imageAsset: 'assets/aircraft/antonov-an-148.jpeg',
      typicalSeats: 85,
      targetSeconds: 110,
      unlockType: AircraftUnlockType.progression,
      unlockRequirement: 'Complete E175 under 09:30',
      layout: LevelAn148.aircraft,
    ),
    const Aircraft(
      id: 'comac-arj21',
      level: 14,
      manufacturer: 'COMAC',
      model: 'ARJ21-700',
      description:
          "China's first indigenous regional jet, opening up new domestic routes.",
      imageAsset: 'assets/aircraft/comac-arj21.jpeg',
      typicalSeats: 90,
      targetSeconds: 110,
      unlockType: AircraftUnlockType.progression,
      unlockRequirement: 'Complete An-148 under 10:00',
      layout: LevelArj21.aircraft,
    ),
    const Aircraft(
      id: 'antonov-an-158',
      level: 15,
      manufacturer: 'Antonov',
      model: 'An-158',
      description:
          'A stretched An-148 pushing capacity for medium regional sectors.',
      imageAsset: 'assets/aircraft/antonov-an-158.jpeg',
      typicalSeats: 100,
      targetSeconds: 120,
      unlockType: AircraftUnlockType.progression,
      unlockRequirement: 'Complete ARJ21-700 under 10:15',
      layout: LevelAn158.aircraft,
    ),
    const Aircraft(
      id: 'embraer-e190',
      level: 16,
      manufacturer: 'Embraer',
      model: 'E190',
      description:
          'The workhorse E-Jet that struck a sweet spot between range and capacity.',
      imageAsset: 'assets/aircraft/embraer-e190.jpeg',
      typicalSeats: 100,
      targetSeconds: 120,
      unlockType: AircraftUnlockType.progression,
      unlockRequirement: 'Complete An-158 under 10:30',
      layout: LevelE190.aircraft,
    ),
    const Aircraft(
      id: 'sukhoi-superjet-100',
      level: 17,
      manufacturer: 'Sukhoi',
      model: 'Superjet 100',
      description:
          "Russia's first modern regional jet, built for high-frequency operations.",
      imageAsset: 'assets/aircraft/sukhoi-superjet-100.jpeg',
      typicalSeats: 100,
      targetSeconds: 130,
      unlockType: AircraftUnlockType.progression,
      unlockRequirement: 'Complete E190 under 10:30',
      layout: LevelSuperjet.aircraft,
    ),
    const Aircraft(
      id: 'airbus-a220-100',
      level: 18,
      manufacturer: 'Airbus',
      model: 'A220-100',
      description:
          'A game-changer for thin long routes with its fuel-sipping efficiency.',
      imageAsset: 'assets/aircraft/a220-100.jpeg',
      typicalSeats: 125,
      targetSeconds: 130,
      unlockType: AircraftUnlockType.progression,
      unlockRequirement: 'Complete Superjet 100 under 10:30',
      layout: LevelA220_100.aircraft,
    ),
    const Aircraft(
      id: 'embraer-e195',
      level: 19,
      manufacturer: 'Embraer',
      model: 'E195-E2',
      description:
          'The largest E-Jet E2, redefining economics for the 130-seat segment.',
      imageAsset: 'assets/aircraft/embraer-e195-e2.jpeg',
      typicalSeats: 130,
      targetSeconds: 134,
      unlockType: AircraftUnlockType.progression,
      unlockRequirement: 'Complete A220-100 under 11:15',
      layout: LevelE195.aircraft,
    ),
    const Aircraft(
      id: 'airbus-a319neo',
      level: 20,
      manufacturer: 'Airbus',
      model: 'A319neo',
      description:
          'A nimble narrowbody that sips fuel on routes too thin for bigger jets.',
      imageAsset: 'assets/aircraft/a319neo.jpeg',
      typicalSeats: 138,
      targetSeconds: 150,
      unlockType: AircraftUnlockType.progression,
      unlockRequirement: 'Complete E195-E2 under 11:30',
      layout: LevelA319.aircraft,
    ),
    const Aircraft(
      id: 'boeing-737-700',
      level: 21,
      manufacturer: 'Boeing',
      model: '737-700',
      description:
          'The compact classic that launched the Next Generation 737 family.',
      imageAsset: 'assets/aircraft/b737.jpeg',
      typicalSeats: 138,
      targetSeconds: 160,
      unlockType: AircraftUnlockType.progression,
      unlockRequirement: 'Complete A319neo under 12:00',
      layout: LevelB737_700.aircraft,
    ),
    const Aircraft(
      id: 'airbus-a220-300',
      level: 22,
      manufacturer: 'Airbus',
      model: 'A220-300',
      description:
          'A stretched A220 challenging narrowbody stalwarts on medium sectors.',
      imageAsset: 'assets/aircraft/a220-300.jpeg',
      typicalSeats: 145,
      targetSeconds: 150,
      unlockType: AircraftUnlockType.progression,
      unlockRequirement: 'Complete 737-700 under 12:00',
      layout: LevelA220_300.aircraft,
    ),
    const Aircraft(
      id: 'airbus-a320',
      level: 23,
      manufacturer: 'Airbus',
      model: 'A320',
      description:
          'The jet that defined modern short-haul flying for a generation.',
      imageAsset: 'assets/aircraft/a320.jpeg',
      typicalSeats: 150,
      targetSeconds: 150,
      unlockType: AircraftUnlockType.progression,
      unlockRequirement: 'Complete A220-300 under 12:00',
      layout: LevelA320.aircraft,
    ),
    const Aircraft(
      id: 'comac-c919',
      level: 24,
      manufacturer: 'COMAC',
      model: 'C919',
      description:
          "China's answer to the A320, built to dominate Asia's booming domestic market.",
      imageAsset: 'assets/aircraft/comac-c919.jpeg',
      typicalSeats: 156,
      targetSeconds: 200,
      unlockType: AircraftUnlockType.progression,
      unlockRequirement: 'Complete A320 under 12:30',
      layout: LevelC919.aircraft,
    ),
    const Aircraft(
      id: 'boeing-737-800',
      level: 25,
      manufacturer: 'Boeing',
      model: '737-800',
      description:
          'The backbone of low-cost carriers worldwide, reliable and high-density.',
      imageAsset: 'assets/aircraft/b737.jpeg',
      typicalSeats: 174,
      targetSeconds: 180,
      unlockType: AircraftUnlockType.progression,
      unlockRequirement: 'Complete C919 under 12:45',
      layout: LevelB737_800.aircraft,
    ),
    const Aircraft(
      id: 'airbus-a321neo',
      level: 26,
      manufacturer: 'Airbus',
      model: 'A321neo',
      description:
          'The stretched A320 family leader, stretching range and seat count.',
      imageAsset: 'assets/aircraft/a321neo.jpeg',
      typicalSeats: 186,
      targetSeconds: 180,
      unlockType: AircraftUnlockType.progression,
      unlockRequirement: 'Complete 737-800 under 13:30',
      layout: LevelA321neo.aircraft,
    ),
    const Aircraft(
      id: 'boeing-737-9',
      level: 27,
      manufacturer: 'Boeing',
      model: '737-9 MAX',
      description:
          "Boeing's answer to the A321neo, optimised for medium-haul efficiency.",
      imageAsset: 'assets/aircraft/b737.jpeg',
      typicalSeats: 192,
      targetSeconds: 180,
      unlockType: AircraftUnlockType.progression,
      unlockRequirement: 'Complete A321neo under 14:00',
      layout: LevelB737_9.aircraft,
    ),
    const Aircraft(
      id: 'tupolev-tu-214',
      level: 28,
      manufacturer: 'Tupolev',
      model: 'Tu-214',
      description:
          'A twin-aisle narrowbody from Russia, offering widebody comfort on domestic routes.',
      imageAsset: 'assets/aircraft/tupolev-tu-214.jpeg',
      typicalSeats: 196,
      targetSeconds: 160,
      unlockType: AircraftUnlockType.progression,
      unlockRequirement: 'Complete 737-9 MAX under 14:15',
      layout: LevelDualAisle.aircraft,
    ),
    const Aircraft(
      id: 'boeing-757-200',
      level: 29,
      manufacturer: 'Boeing',
      model: '757-200',
      description:
          'The narrow twin that conquered transatlantic routes with its remarkable range.',
      imageAsset: 'assets/aircraft/757-200.jpeg',
      typicalSeats: 198,
      targetSeconds: 180,
      unlockType: AircraftUnlockType.progression,
      unlockRequirement: 'Complete Tu-214 under 14:30',
      layout: LevelB757.aircraft,
    ),
    const Aircraft(
      id: 'airbus-a321xlr',
      level: 30,
      manufacturer: 'Airbus',
      model: 'A321XLR',
      description:
          'The extra-long-range A321 pushing narrowbody flying to its absolute limits.',
      imageAsset: 'assets/aircraft/a321xlr.jpeg',
      typicalSeats: 204,
      targetSeconds: 180,
      unlockType: AircraftUnlockType.progression,
      unlockRequirement: 'Complete 757-200 under 14:30',
      layout: LevelA321xlr.aircraft,
    ),
    const Aircraft(
      id: 'boeing-767-300er',
      level: 31,
      manufacturer: 'Boeing',
      model: '767-300ER',
      description:
          'A wide-body workhorse that opened up long-haul routes for mid-size carriers.',
      imageAsset: 'assets/aircraft/767-300er.jpeg',
      typicalSeats: 248,
      targetSeconds: 900,
      unlockType: AircraftUnlockType.premium,
      priceLabel: 'Premium aircraft',
      unlockRequirement: 'Complete A321XLR under 14:45',
      layout: Level767.aircraft,
    ),
    const Aircraft(
      id: 'airbus-a330-200',
      level: 32,
      manufacturer: 'Airbus',
      model: 'A330-200',
      description:
          'A versatile wide-body that made long thin routes economically viable.',
      imageAsset: 'assets/aircraft/a330-200.jpeg',
      typicalSeats: 252,
      targetSeconds: 960,
      unlockType: AircraftUnlockType.premium,
      priceLabel: 'Premium aircraft',
      unlockRequirement: 'Complete 767-300ER under 15:00',
      layout: LevelA330_200.aircraft,
    ),
    const Aircraft(
      id: 'boeing-787-8',
      level: 33,
      manufacturer: 'Boeing',
      model: '787-8 Dreamliner',
      description:
          'A composite-built wide-body that slashed fuel burns on long-haul routes.',
      imageAsset: 'assets/aircraft/787-8.jpeg',
      typicalSeats: 252,
      targetSeconds: 960,
      unlockType: AircraftUnlockType.premium,
      priceLabel: 'Premium aircraft',
      unlockRequirement: 'Complete A330-200 under 16:00',
      layout: Level787_8.aircraft,
    ),
    const Aircraft(
      id: 'ilyushin-il-96-300',
      level: 34,
      manufacturer: 'Ilyushin',
      model: 'Il-96-300',
      description:
          "Russia's four-engine wide-body, a symbol of Soviet engineering ambition.",
      imageAsset: 'assets/aircraft/ilyushin-il-96-300.jpeg',
      typicalSeats: 252,
      targetSeconds: 990,
      unlockType: AircraftUnlockType.premium,
      priceLabel: 'Premium aircraft',
      unlockRequirement: 'Complete 787-8 Dreamliner under 16:00',
      layout: LevelIl96.aircraft,
    ),
    const Aircraft(
      id: 'airbus-a330-300',
      level: 35,
      manufacturer: 'Airbus',
      model: 'A330-300',
      description:
          'The stretched A330 that became a high-density workhorse for Asian carriers.',
      imageAsset: 'assets/aircraft/a330-300.jpeg',
      typicalSeats: 280,
      targetSeconds: 1020,
      unlockType: AircraftUnlockType.premium,
      priceLabel: 'Premium aircraft',
      unlockRequirement: 'Complete Il-96-300 under 16:30',
      layout: LevelA330_300.aircraft,
    ),
    const Aircraft(
      id: 'boeing-787-9',
      level: 36,
      manufacturer: 'Boeing',
      model: '787-9 Dreamliner',
      description:
          'A stretched Dreamliner that combined greater range with higher capacity.',
      imageAsset: 'assets/aircraft/787-9.jpeg',
      typicalSeats: 294,
      targetSeconds: 1050,
      unlockType: AircraftUnlockType.premium,
      priceLabel: 'Premium aircraft',
      unlockRequirement: 'Complete A330-300 under 17:00',
      layout: Level787_9.aircraft,
    ),
    const Aircraft(
      id: 'boeing-777-200er',
      level: 37,
      manufacturer: 'Boeing',
      model: '777-200ER',
      description:
          'The twin-jet giant that made non-stop ultra-long-haul flying routine.',
      imageAsset: 'assets/aircraft/777-200er.jpeg',
      typicalSeats: 360,
      targetSeconds: 1080,
      unlockType: AircraftUnlockType.premium,
      priceLabel: 'Premium aircraft',
      unlockRequirement: 'Complete 787-9 Dreamliner under 17:30',
      layout: Level777_200er.aircraft,
    ),
    const Aircraft(
      id: 'airbus-a350-900',
      level: 38,
      manufacturer: 'Airbus',
      model: 'A350-900',
      description:
          'A carbon-fibre wide-body engineered for efficiency on ultra-long-haul routes.',
      imageAsset: 'assets/aircraft/a350.jpeg',
      typicalSeats: 360,
      targetSeconds: 1080,
      unlockType: AircraftUnlockType.premium,
      priceLabel: 'Premium aircraft',
      layout: LevelA350_900.aircraft,
    ),
    const Aircraft(
      id: 'airbus-a350-1000',
      level: 39,
      manufacturer: 'Airbus',
      model: 'A350-1000',
      description:
          'The stretched A350 variant that extends range while adding capacity.',
      imageAsset: 'assets/aircraft/a350.jpeg',
      typicalSeats: 369,
      targetSeconds: 1170,
      unlockType: AircraftUnlockType.premium,
      priceLabel: 'Premium aircraft',
      unlockRequirement: 'Complete 777-200ER under 18:00',
      layout: LevelA350_1000.aircraft,
    ),
    const Aircraft(
      id: 'boeing-777-300er',
      level: 40,
      manufacturer: 'Boeing',
      model: '777-300ER',
      description:
          'The high-capacity stretched 777 dominating long-haul high-density routes.',
      imageAsset: 'assets/aircraft/777-300er.jpeg',
      typicalSeats: 396,
      targetSeconds: 1230,
      unlockType: AircraftUnlockType.premium,
      priceLabel: 'Premium aircraft',
      unlockRequirement: 'Complete A350-1000 under 19:30',
      layout: Level777_300er.aircraft,
    ),
    const Aircraft(
      id: 'boeing-747-8',
      level: 41,
      manufacturer: 'Boeing',
      model: '747-8 Intercontinental',
      description:
          'The stretched jumbo jet, blending iconic four-engine heritage with modern efficiency.',
      imageAsset: 'assets/aircraft/747-8.jpeg',
      typicalSeats: 468,
      targetSeconds: 1350,
      unlockType: AircraftUnlockType.premium,
      priceLabel: 'Premium aircraft',
      layout: Level747_8.aircraft,
    ),
    const Aircraft(
      id: 'airbus-a380-800',
      level: 42,
      manufacturer: 'Airbus',
      model: 'A380-800',
      description:
          'The double-deck superjumbo that redefined passenger capacity and comfort.',
      imageAsset: 'assets/aircraft/a380-800.jpeg',
      typicalSeats: 590,
      targetSeconds: 1500,
      unlockType: AircraftUnlockType.premium,
      priceLabel: 'Premium aircraft',
      layout: LevelA380.aircraft,
    ),
  ]);
}
