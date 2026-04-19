/// Display helpers for profile height. Canonical storage remains centimeters.
String formatHeightForDisplay(int? heightCm, {required bool useImperial}) {
  if (heightCm == null) {
    return '—';
  }
  if (!useImperial) {
    return '$heightCm cm';
  }
  return formatCmAsFeetInches(heightCm);
}

/// Rounds to the nearest inch, then formats as feet and inches (e.g. 5'9").
String formatCmAsFeetInches(int cm) {
  final totalInches = (cm / 2.54).round().clamp(1, 120);
  final feet = totalInches ~/ 12;
  final inches = totalInches % 12;
  return "$feet'$inches\"";
}

/// Same rounding as [formatCmAsFeetInches], split into parts for editing.
({int feet, int inches}) cmToFeetInchParts(int cm) {
  final totalInches = (cm / 2.54).round().clamp(1, 120);
  return (feet: totalInches ~/ 12, inches: totalInches % 12);
}

/// Whole feet and inches (inches 0–11); returns rounded centimeters.
int? feetInchPartsToCm(int feet, int inches) {
  if (inches < 0 || inches > 11 || feet < 0) {
    return null;
  }
  final totalInches = feet * 12 + inches;
  return (totalInches * 2.54).round();
}
