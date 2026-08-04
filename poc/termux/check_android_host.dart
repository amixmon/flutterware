import 'dart:ffi';
import 'dart:io';

Future<void> main() async {
  stdout.writeln('Dart ${Platform.version}');
  stdout.writeln('operatingSystem=${Platform.operatingSystem}');
  stdout.writeln('operatingSystemVersion=${Platform.operatingSystemVersion}');
  stdout.writeln('localHostname=${Platform.localHostname}');
  stdout.writeln('numberOfProcessors=${Platform.numberOfProcessors}');
  stdout.writeln('abi=${Abi.current()}');
  stdout.writeln('resolvedExecutable=${Platform.resolvedExecutable}');
  stdout.writeln('executable=${Platform.executable}');
  stdout.writeln('cwd=${Directory.current.path}');
  stdout.writeln('HOME=${Platform.environment['HOME']}');
  stdout.writeln('TMPDIR=${Platform.environment['TMPDIR']}');
  stdout.writeln('PUB_CACHE=${Platform.environment['PUB_CACHE']}');

  final result = await Process.run(
    '/system/bin/sh',
    const ['-c', 'printf process-ok; id'],
    environment: Platform.environment,
    workingDirectory: Directory.current.path,
  );
  stdout.writeln('process.exitCode=${result.exitCode}');
  stdout.writeln('process.stdout=${result.stdout.toString().trim()}');
  stdout.writeln('process.stderr=${result.stderr.toString().trim()}');
}
