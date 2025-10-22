import '../custom/custom_logger_extension.dart';

class MRZHelper {
  static List<String>? getFinalListToParse(List<String> ableToScanTextList) {
    if (ableToScanTextList.isEmpty) {
      return null;
    }

    // Check for driver's license (starts with D1, D2, or DL)
    String firstLine = ableToScanTextList.first;
    if (firstLine.length >= 2) {
      String firstTwoChars = firstLine.substring(0, 2);
      List<String> driverLicenseTypes = ['D1', 'D2', 'DL'];
      if (driverLicenseTypes.contains(firstTwoChars)) {
        "Driver's License MRZ detected".logInfo();
        return [...ableToScanTextList];
      }
    }

    // Check for passport/visa (requires at least 2 lines)
    if (ableToScanTextList.length < 2) {
      // minimum length of passport MRZ format is 2 lines
      return null;
    }
    int lineLength = ableToScanTextList.first.length;
    for (var e in ableToScanTextList) {
      if (e.length != lineLength) {
        return null;
      }
      // to make sure that all lines are the same in length
    }
    List<String> firstLineChars = ableToScanTextList.first.split('');
    List<String> supportedDocTypes = [
      'P',
      'V',
    ]; // you can add more doc types like A,C,I are also supported
    String fChar = firstLineChars[0];
    if (supportedDocTypes.contains(fChar)) {
      'Passport or Visa MRZ detected'.logInfo();
      return [...ableToScanTextList];
    }
    return null;
  }

  static String testTextLine(String text) {
    String res = text.replaceAll(' ', '');
    List<String> list = res.split('');

    // to check if the text belongs to any MRZ format or not
    if (list.length != 44 && list.length != 30 && list.length != 36) {
      return '';
    }

    for (int i = 0; i < list.length; i++) {
      if (RegExp(r'^[A-Za-z0-9_.]+$').hasMatch(list[i])) {
        list[i] = list[i].toUpperCase();
        // to ensure that every letter is uppercase
      }
      if (double.tryParse(list[i]) == null && !(RegExp(r'^[A-Za-z0-9_.]+$').hasMatch(list[i]))) {
        list[i] = '<';
        // sometimes < sign not recognized well
      }
    }
    String result = list.join('');
    return result;
  }
}
