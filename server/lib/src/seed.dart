import 'dart:convert';

import 'package:trip_core/trip_core.dart';

import 'trip_repository.dart';

class SeedReport {
  const SeedReport({required this.imported, required this.skipped});

  final int imported;

  /// One human-readable reason per skipped entry.
  final List<String> skipped;
}

/// Imports trips from [jsonText] (a JSON array) when [repo] is empty.
///
/// Returns null when the repository already has data. Invalid entries are
/// skipped and reported, not fatal. Throws [FormatException] when the top
/// level is not an array.
SeedReport? seedIfEmpty(TripRepository repo, String jsonText) {
  if (repo.count() > 0) return null;

  final decoded = jsonDecode(jsonText);
  if (decoded is! List) {
    throw const FormatException('Seed file must contain a JSON array of trips');
  }

  var imported = 0;
  final skipped = <String>[];
  for (final (index, entry) in decoded.indexed) {
    if (entry is! Map<String, Object?>) {
      skipped.add('#$index: not an object');
      continue;
    }
    switch (validateTrip(entry)) {
      case InvalidTrip(:final errors):
        skipped.add('#$index (${entry['id']}): $errors');
      case ValidTrip(:final trip):
        if (repo.insert(trip).outcome == InsertOutcome.created) {
          imported++;
        } else {
          skipped.add('#$index (${trip.id}): duplicate id');
        }
    }
  }
  return SeedReport(imported: imported, skipped: skipped);
}
