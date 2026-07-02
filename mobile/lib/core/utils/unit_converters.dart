// Metric is canonical everywhere in the backend (cm, kg) — these only convert
// for imperial-unit display/input, mirroring the web onboarding wizard's
// lib/lib/utils/units.ts (see docs/21-onboarding-user-details-plan.md).

const double _cmPerInch = 2.54;
const double _kgPerLb = 0.45359237;

typedef FeetInches = ({int feet, int inches});

FeetInches cmToFeetInches(double cm) {
  final totalInches = cm / _cmPerInch;
  var feet = totalInches ~/ 12;
  var inches = (totalInches - feet * 12).round();
  if (inches == 12) {
    feet += 1;
    inches = 0;
  }
  return (feet: feet, inches: inches);
}

double feetInchesToCm(int feet, int inches) {
  return (((feet * 12) + inches) * _cmPerInch * 10).round() / 10;
}

double kgToLb(double kg) => (kg / _kgPerLb * 10).round() / 10;

double lbToKg(double lb) => (lb * _kgPerLb * 10).round() / 10;
