import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtdapp/helpers/mrz_data.dart';

class DataGroupConfig {
  final dynamic tag;
  final String name;
  final double progressIncrement;
  final Future<DataGroup> Function(Document) readFunction;

  DataGroupConfig({
    required this.tag,
    required this.name,
    required this.progressIncrement,
    required this.readFunction,
  });
}