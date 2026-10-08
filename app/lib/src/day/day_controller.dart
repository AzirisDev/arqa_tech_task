import 'package:flutter/foundation.dart';
import 'package:trip_core/trip_core.dart';

import '../api/api_client.dart';

sealed class DayState {
  const DayState();
}

class DayLoading extends DayState {
  const DayLoading();
}

class DayLoaded extends DayState {
  const DayLoaded(this.data);

  final DayData data;
}

class DayError extends DayState {
  const DayError(this.message);

  final String message;
}

/// Selected day and its loading state.
class DayController extends ChangeNotifier {
  DayController({required ApiClient api, required LocalDate Function() today})
    : _api = api,
      _today = today,
      _date = today();

  final ApiClient _api;
  final LocalDate Function() _today;

  LocalDate _date;
  DayState _state = const DayLoading();
  int _generation = 0;
  bool _disposed = false;

  LocalDate get date => _date;
  DayState get state => _state;

  /// Opens the most recent day that has trips, or today when there are none
  /// (or the list cannot be fetched).
  Future<void> init() async {
    final generation = _generation;
    LocalDate initial;
    try {
      final days = await _api.fetchDays();
      initial = days.isEmpty ? _today() : days.last;
    } on ApiFailure {
      initial = _today();
    }
    // The user picked a day while the list was loading: keep their choice.
    if (_disposed || generation != _generation) return;
    await select(initial);
  }

  Future<void> select(LocalDate date) => _load(date, showLoading: true);

  Future<void> previous() => select(_date.addDays(-1));

  Future<void> next() => select(_date.addDays(1));

  /// Reloads the current day; old content stays visible (pull-to-refresh).
  Future<void> refresh() => _load(_date, showLoading: false);

  Future<void> _load(LocalDate date, {required bool showLoading}) async {
    final generation = ++_generation;
    _date = date;
    if (showLoading) _state = const DayLoading();
    _notify();

    DayState result;
    try {
      result = DayLoaded(await _api.fetchDay(date));
    } on ApiFailure catch (failure) {
      result = DayError(failure.message);
    }
    // A newer request started meanwhile: its result wins, drop this one.
    if (_disposed || generation != _generation) return;
    _state = result;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
