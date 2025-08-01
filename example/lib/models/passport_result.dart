import 'dart:convert';

class PassportDataResult {
  final Map<String, String> dataGroups;
  final String efSod;

  PassportDataResult({
    required this.dataGroups,
    required this.efSod,
  });

  Map<String, dynamic> toJson() => {
    'data_groups': dataGroups,
    'EF_SOD': efSod,
  };

  String toJsonString() => jsonEncode(toJson());
}