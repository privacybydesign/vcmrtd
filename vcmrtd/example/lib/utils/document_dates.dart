/// Driving licence dates are stored as ddMMyyyy strings; parses one into a
/// [DateTime], or null if it isn't a valid date in that format.
DateTime? parseDrivingLicenceDate(String date) {
  if (date.length != 8) return null;
  final day = int.tryParse(date.substring(0, 2));
  final month = int.tryParse(date.substring(2, 4));
  final year = int.tryParse(date.substring(4, 8));
  if (day == null || month == null || year == null) return null;
  return DateTime(year, month, day);
}
