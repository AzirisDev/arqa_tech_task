import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:trip_core/trip_core.dart';
import 'package:uuid/uuid.dart';

import '../api/api_client.dart';
import '../format.dart';

class AddTripScreen extends StatefulWidget {
  const AddTripScreen({
    super.key,
    required this.api,
    required this.initialDate,
    this.newId,
  });

  final ApiClient api;
  final LocalDate initialDate;

  /// Trip id generator; defaults to UUID v4. Injected in tests.
  final String Function()? newId;

  @override
  State<AddTripScreen> createState() => _AddTripScreenState();
}

class _AddTripScreenState extends State<AddTripScreen> {
  static const _fieldKeys = {
    'start',
    'end',
    'amount',
    'commission',
    'payment',
  };
  static final _clock = RegExp(r'^(\d{1,2}):(\d{2})$');

  // Generated once per screen. Every retry re-sends the same id, so a request
  // that reached the server before the connection dropped is not saved twice.
  late final String _tripId = widget.newId?.call() ?? const Uuid().v4();

  late LocalDate _date = widget.initialDate;
  bool _endsNextDay = false;
  PaymentMethod? _payment;
  final _startTime = TextEditingController();
  final _endTime = TextEditingController();
  final _amount = TextEditingController();
  final _commission = TextEditingController();

  Map<String, String> _errors = const {};
  String? _failure;
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [_startTime, _endTime, _amount, _commission]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// ISO-8601 timestamp in the driver offset, or null when [clock] is not
  /// `ЧЧ:ММ` — `validateTrip` then reports the field.
  String? _timestamp(LocalDate date, String clock) {
    final match = _clock.firstMatch(clock.trim());
    if (match == null) return null;
    final hour = match[1]!.padLeft(2, '0');
    return '${date}T$hour:${match[2]}:00'
        '${formatUtcOffset(widget.api.driverOffset)}';
  }

  Map<String, Object?> _toJson() => {
        'id': _tripId,
        'start': _timestamp(_date, _startTime.text),
        'end': _timestamp(_endsNextDay ? _date.addDays(1) : _date, _endTime.text),
        'amount': int.tryParse(_amount.text.trim()),
        'commission': int.tryParse(_commission.text.trim()),
        'payment': _payment?.name,
      };

  Future<void> _submit() async {
    switch (validateTrip(_toJson())) {
      case InvalidTrip(:final errors):
        setState(() {
          _errors = errors;
          _failure = null;
        });
      case ValidTrip(:final trip):
        await _save(trip);
    }
  }

  Future<void> _save(Trip trip) async {
    setState(() {
      _errors = const {};
      _failure = null;
      _saving = true;
    });
    try {
      final saved = await widget.api.saveTrip(trip);
      if (mounted) Navigator.of(context).pop(saved);
    } on ValidationFailure catch (failure) {
      if (mounted) setState(() => _errors = failure.errors);
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => _failure = failure.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_date.year, _date.month, _date.day),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _date = LocalDate(picked.year, picked.month, picked.day));
    }
  }

  Widget _clockField(Key key, TextEditingController controller, String label,
          String? error) =>
      TextField(
        key: key,
        controller: controller,
        enabled: !_saving,
        keyboardType: TextInputType.datetime,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9:]'))],
        decoration: InputDecoration(
          labelText: label,
          hintText: 'ЧЧ:ММ',
          errorText: error,
          errorMaxLines: 2,
        ),
      );

  Widget _moneyField(Key key, TextEditingController controller, String label,
          String? error) =>
      TextField(
        key: key,
        controller: controller,
        enabled: !_saving,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(labelText: label, errorText: error),
      );

  @override
  Widget build(BuildContext context) {
    final errorStyle = TextStyle(color: Theme.of(context).colorScheme.error);
    // Errors without a form field (e.g. `id` or `_` from the server).
    final banner = [
      ?_failure,
      for (final entry in _errors.entries)
        if (!_fieldKeys.contains(entry.key)) entry.value,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Новая поездка')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const Key('date'),
              onPressed: _saving ? null : _pickDate,
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text(formatDay(_date)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _clockField(const Key('start-time'), _startTime,
                    'Начало', _errors['start']),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _clockField(const Key('end-time'), _endTime,
                    'Окончание', _errors['end']),
              ),
            ],
          ),
          SwitchListTile(
            key: const Key('ends-next-day'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Закончилась на следующий день'),
            value: _endsNextDay,
            onChanged:
                _saving ? null : (value) => setState(() => _endsNextDay = value),
          ),
          _moneyField(
              const Key('amount'), _amount, 'Сумма, ₸', _errors['amount']),
          const SizedBox(height: 12),
          _moneyField(const Key('commission'), _commission, 'Комиссия, ₸',
              _errors['commission']),
          const SizedBox(height: 16),
          SegmentedButton<PaymentMethod>(
            segments: const [
              ButtonSegment(
                value: PaymentMethod.cash,
                label: Text('Наличные'),
                icon: Icon(Icons.payments_outlined),
              ),
              ButtonSegment(
                value: PaymentMethod.card,
                label: Text('Карта'),
                icon: Icon(Icons.credit_card),
              ),
            ],
            selected: {?_payment},
            emptySelectionAllowed: true,
            onSelectionChanged: _saving
                ? null
                : (selection) => setState(() =>
                    _payment = selection.isEmpty ? null : selection.first),
          ),
          if (_errors['payment'] case final error?)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(error, style: errorStyle),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final message in banner)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(message, style: errorStyle),
                ),
              FilledButton(
                key: const Key('submit'),
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_failure == null ? 'Сохранить' : 'Повторить'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
