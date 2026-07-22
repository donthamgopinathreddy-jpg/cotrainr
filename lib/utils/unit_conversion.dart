/// Shared body-metric unit conversions (storage stays metric: cm / kg).
class UnitConversion {
  UnitConversion._();

  static const double cmPerInch = 2.54;
  static const double kgPerLb = 0.45359237;

  static double cmToInches(double cm) => cm / cmPerInch;
  static double inchesToCm(double inches) => inches * cmPerInch;

  static (int feet, int inches) cmToFeetInches(double cm) {
    final total = cmToInches(cm).round().clamp(0, 120);
    return (total ~/ 12, total % 12);
  }

  static double feetInchesToCm(int feet, int inches) =>
      inchesToCm((feet * 12 + inches).toDouble());

  static double kgToLbs(double kg) => kg / kgPerLb;
  static double lbsToKg(double lbs) => lbs * kgPerLb;
}
