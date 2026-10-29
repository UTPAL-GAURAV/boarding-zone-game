/// Bundled manufacturer marks used on fleet cards.
abstract final class ManufacturerBrandAssets {
  static const _logos = <String, String>{
    'Airbus': 'assets/manufacturers/airbus.png',
    'ATR': 'assets/manufacturers/atr.png',
    'Antonov': 'assets/manufacturers/antonov.png',
    'Boeing': 'assets/manufacturers/boeing.png',
    'Bombardier': 'assets/manufacturers/bombardier.png',
    'Cessna': 'assets/manufacturers/cessna.png',
    'De Havilland Canada': 'assets/manufacturers/de_havilland.png',
    'Embraer': 'assets/manufacturers/embraer.png',
    'Saab': 'assets/manufacturers/saab.png',
    'Sukhoi': 'assets/manufacturers/sukhoi.png',
    'Tupolev': 'assets/manufacturers/tupolev.png',
  };

  static String? logoFor(String manufacturer) => _logos[manufacturer];

  static String monogramFor(String manufacturer) => switch (manufacturer) {
    'COMAC' => 'COMAC',
    'Ilyushin' => 'IL',
    'De Havilland Canada' => 'DHC',
    _ => manufacturer.substring(0, 1).toUpperCase(),
  };
}
