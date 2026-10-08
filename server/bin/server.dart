import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shift_diary_server/shift_diary_server.dart';
import 'package:trip_core/trip_core.dart';

Future<void> main() async {
  final env = Platform.environment;
  final port = int.parse(env['PORT'] ?? '8080');
  final offset = parseUtcOffset(env['DRIVER_UTC_OFFSET'] ?? '+05:00');
  // Defaults resolve next to this package, not the working directory.
  final dbPath =
      env['DB_PATH'] ??
      Platform.script.resolve('../data/trips.db').toFilePath();
  final seedPath =
      env['SEED_PATH'] ??
      Platform.script.resolve('../data/trips.json').toFilePath();

  final repo = TripRepository.open(dbPath, driverOffset: offset);

  final seedFile = File(seedPath);
  if (seedFile.existsSync()) {
    try {
      final report = seedIfEmpty(repo, seedFile.readAsStringSync());
      if (report != null) {
        stdout.writeln('Seeded ${report.imported} trips from $seedPath');
        for (final reason in report.skipped) {
          stderr.writeln('  skipped $reason');
        }
      }
    } on FormatException catch (error) {
      stderr.writeln('Seed file $seedPath ignored: ${error.message}');
    }
  } else {
    stderr.writeln('No seed file at $seedPath; starting with existing data');
  }

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(buildApi(repo));
  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  stdout.writeln(
    'Shift diary API on http://localhost:${server.port} '
    '(driver offset ${formatUtcOffset(offset)}, db $dbPath)',
  );

  ProcessSignal.sigint.watch().first.then((_) async {
    await server.close();
    repo.close();
    exit(0);
  });
}
