import 'package:flutter/material.dart';
import 'package:trip_core/trip_core.dart';
import 'package:uuid/uuid.dart';

import '../api/api_client.dart';
import '../format.dart';
import '../theme/app_theme.dart';
import 'clock_input.dart';
import 'money_input.dart';

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
  static const _fieldKeys = {'start', 'end', 'amount', 'commission', 'payment'};

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
  bool _conflict = false;

  @override
  void dispose() {
    for (final controller in [_startTime, _endTime, _amount, _commission]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// ISO-8601 timestamp in the driver offset, or null when [clock] is not a
  /// valid time — `validateTrip` then reports the field.
  String? _timestamp(LocalDate date, String clock) {
    final time = formatClockInput(clock);
    if (time == null) return null;
    return '${date}T$time:00${formatUtcOffset(widget.api.driverOffset)}';
  }

  Map<String, Object?> _toJson() => {
    'id': _tripId,
    'start': _timestamp(_date, _startTime.text),
    'end': _timestamp(_endsNextDay ? _date.addDays(1) : _date, _endTime.text),
    'amount': parseMoneyInput(_amount.text),
    'commission': parseMoneyInput(_commission.text),
    'payment': _payment?.name,
  };

  /// Drops the errors an edit may have made stale; they are re-checked on submit.
  void _clearErrors(List<String> keys) {
    if (!keys.any(_errors.containsKey)) return;
    setState(
      () => _errors = {
        for (final entry in _errors.entries)
          if (!keys.contains(entry.key)) entry.key: entry.value,
      },
    );
  }

  /// Shows a valid time as `HH:MM` once the driver leaves the field.
  void _normalizeClock(TextEditingController controller) {
    final normalized = formatClockInput(controller.text);
    if (normalized != null && normalized != controller.text) {
      controller.text = normalized;
    }
  }

  void _unfocus() => FocusManager.instance.primaryFocus?.unfocus();

  void _selectPayment(PaymentMethod payment) {
    setState(() => _payment = payment);
    _clearErrors(['payment']);
  }

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
      _conflict = false;
      _saving = true;
    });
    try {
      final saved = await widget.api.saveTrip(trip);
      if (mounted) Navigator.of(context).pop(saved);
    } on ValidationFailure catch (failure) {
      if (mounted) setState(() => _errors = failure.errors);
    } on ConflictFailure catch (failure) {
      if (mounted) {
        setState(() {
          _failure = failure.message;
          _conflict = true;
        });
      }
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
      _clearErrors(['start', 'end']);
    }
  }

  Widget _clockField(
    Key key,
    TextEditingController controller,
    String? error,
    List<String> clears,
  ) => Focus(
    skipTraversal: true,
    onFocusChange: (hasFocus) {
      if (!hasFocus) _normalizeClock(controller);
    },
    child: TextField(
      key: key,
      controller: controller,
      enabled: !_saving,
      keyboardType: TextInputType.number,
      onChanged: (_) => _clearErrors(clears),
      onTapOutside: (_) => _unfocus(),
      inputFormatters: const [ClockInputFormatter()],
      decoration: InputDecoration(
        hintText: 'ЧЧ:ММ',
        prefixIcon: const Icon(Icons.schedule),
        errorText: error,
        errorMaxLines: 2,
      ),
    ),
  );

  Widget _moneyField(
    Key key,
    TextEditingController controller,
    String? error,
    List<String> clears, {
    TextStyle? style,
  }) => TextField(
    key: key,
    controller: controller,
    enabled: !_saving,
    keyboardType: TextInputType.number,
    style: style,
    onChanged: (_) => _clearErrors(clears),
    onTapOutside: (_) => _unfocus(),
    inputFormatters: const [MoneyInputFormatter()],
    decoration: InputDecoration(
      hintText: '0',
      errorText: error,
      errorMaxLines: 2,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorStyle = TextStyle(color: theme.colorScheme.error);
    final fieldErrorStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.error,
    );
    // Errors without a form field (e.g. `id` or `_` from the server).
    final banner = [
      ?_failure,
      for (final entry in _errors.entries)
        if (!_fieldKeys.contains(entry.key)) entry.value,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Новая поездка')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _FieldLabel('Сумма (₸)'),
                  _moneyField(
                    const Key('amount'),
                    _amount,
                    _errors['amount'],
                    ['amount', 'commission'],
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const _FieldLabel('Способ оплаты'),
                  _PaymentToggle(
                    selected: _payment,
                    onSelected: _saving ? null : _selectPayment,
                  ),
                  if (_errors['payment'] case final error?)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Text(error, style: fieldErrorStyle),
                    ),
                  const SizedBox(height: 20),
                  const _FieldLabel('Дата'),
                  Ink(
                    decoration: BoxDecoration(
                      color: AppColors.of(context).inputFill,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      key: const Key('date'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: _saving ? null : _pickDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          filled: false,
                          prefixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                        isEmpty: false,
                        child: Text(
                          formatDayLong(_date),
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const _FieldLabel('Время начала'),
                  _clockField(
                    const Key('start-time'),
                    _startTime,
                    _errors['start'],
                    ['start', 'end'],
                  ),
                  const SizedBox(height: 16),
                  const _FieldLabel('Время окончания'),
                  _clockField(const Key('end-time'), _endTime, _errors['end'], [
                    'end',
                  ]),
                  SwitchListTile(
                    key: const Key('ends-next-day'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Закончилась на следующий день'),
                    value: _endsNextDay,
                    onChanged: _saving
                        ? null
                        : (value) {
                            setState(() => _endsNextDay = value);
                            _clearErrors(['end']);
                          },
                  ),
                  const SizedBox(height: 4),
                  const _FieldLabel('Комиссия (₸)'),
                  _moneyField(
                    const Key('commission'),
                    _commission,
                    _errors['commission'],
                    ['commission'],
                  ),
                ],
              ),
            ),
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
                onPressed: _saving
                    ? null
                    : _conflict
                    ? () => Navigator.of(context).pop()
                    : _submit,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _conflict
                            ? 'ЗАКРЫТЬ'
                            : _failure == null
                            ? 'СОХРАНИТЬ ПОЕЗДКУ'
                            : 'ПОВТОРИТЬ',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: AppColors.of(context).muted),
      ),
    );
  }
}

/// Pill toggle «Карта» / «Наличные»; nothing is selected until the driver
/// picks one.
class _PaymentToggle extends StatelessWidget {
  const _PaymentToggle({required this.selected, required this.onSelected});

  final PaymentMethod? selected;
  final ValueChanged<PaymentMethod>? onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final select = onSelected;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.inputFill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        children: [
          _PaymentOption(
            label: 'Карта',
            icon: Icons.credit_card,
            color: colors.card,
            selected: selected == PaymentMethod.card,
            onTap: select == null ? null : () => select(PaymentMethod.card),
          ),
          _PaymentOption(
            label: 'Наличные',
            icon: Icons.payments_outlined,
            color: colors.cash,
            selected: selected == PaymentMethod.cash,
            onTap: select == null ? null : () => select(PaymentMethod.cash),
          ),
        ],
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final foreground = selected ? colors.onAccent : colors.muted;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? color : Colors.transparent,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: foreground),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
