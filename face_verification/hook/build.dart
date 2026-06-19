import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    final builder = CBuilder.library(
      name: 'faceframe',
      assetName: 'src/ffi/face_frame_buffer.dart',
      sources: ['lib/src/ffi/native/face_frame_buffer.cpp'],
      flags: ['-std=c++17'],
    );
    await builder.run(
      input: input,
      output: output,
      logger: Logger('')..onRecord.listen((record) => print(record.message)),
    );
  });
}
