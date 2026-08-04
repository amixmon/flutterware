import 'dart:ffi';
import 'dart:io';

Future<void> main() async {
  stdout.writeln('FLUTTWARE_DART_SOURCE_OK');
  stdout.writeln('version=${Platform.version}');
  stdout.writeln('operatingSystem=${Platform.operatingSystem}');
  stdout.writeln('abi=${Abi.current()}');
  stdout.writeln('resolvedExecutable=${Platform.resolvedExecutable}');
  stdout.writeln('cwd=${Directory.current.path}');
  stdout.writeln('HOME=${Platform.environment['HOME']}');
  stdout.writeln('TMPDIR=${Platform.environment['TMPDIR']}');
  stdout.writeln('PUB_CACHE=${Platform.environment['PUB_CACHE']}');

  final child = await Process.run(
    '/system/bin/sh',
    const ['-c', 'printf FLUTTWARE_DART_CHILD_PROCESS_OK'],
    environment: Platform.environment,
    workingDirectory: Directory.current.path,
  );
  stdout.writeln('child.exitCode=${child.exitCode}');
  stdout.writeln('child.stdout=${child.stdout}');

  await File('dart-source-proof.txt').writeAsString(
    'FLUTTWARE_DART_FILE_WRITE_OK\n',
  );
}
