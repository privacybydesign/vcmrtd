import 'package:vcmrtd/vcmrtd.dart';

class DataGroupConfig {
  final dynamic tag;
  final String name;
  final bool mandatory;
  final double progressStage;
  final Future<DataGroup> Function(Passport, MrtdData) readFunction;

  DataGroupConfig({
    required this.tag,
    required this.name,
    required this.progressStage,
    required this.readFunction,
    required this.mandatory,
  });
}
