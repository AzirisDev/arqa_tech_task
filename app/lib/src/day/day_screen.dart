import 'package:flutter/material.dart';
import 'package:trip_core/trip_core.dart';

import '../add_trip/add_trip_screen.dart';
import '../api/api_client.dart';
import '../format.dart';
import '../theme/app_theme.dart';
import 'day_controller.dart';
import 'summary_card.dart';
import 'trip_card.dart';

class DayScreen extends StatefulWidget {
  const DayScreen({super.key, required this.api, this.today});

  final ApiClient api;

  /// Clock for tests; defaults to the current driver-local date.
  final LocalDate Function()? today;

  @override
  State<DayScreen> createState() => _DayScreenState();
}

class _DayScreenState extends State<DayScreen> {
  late final DayController _controller;

  Duration get _offset => widget.api.driverOffset;

  @override
  void initState() {
    super.initState();
    _controller = DayController(
      api: widget.api,
      today: widget.today ?? () => LocalDate.of(DateTime.now(), _offset),
    );
    _controller.init();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final current = _controller.date;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(current.year, current.month, current.day),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      _controller.select(LocalDate(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _addTrip() async {
    final saved = await Navigator.of(context).push<Trip>(
      MaterialPageRoute(
        builder: (_) =>
            AddTripScreen(api: widget.api, initialDate: _controller.date),
      ),
    );
    if (!mounted) return;
    if (saved != null) {
      _controller.select(LocalDate.of(saved.start, _offset));
    } else {
      _controller.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                date: _controller.date,
                onPrevious: _controller.previous,
                onNext: _controller.next,
                onPickDate: _pickDate,
              ),
              Expanded(
                child: switch (_controller.state) {
                  DayLoading() => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  DayError(:final message) => _ErrorView(
                    message: message,
                    onRetry: () => _controller.select(_controller.date),
                  ),
                  DayLoaded(:final data) => RefreshIndicator(
                    onRefresh: _controller.refresh,
                    child: _DayContent(data: data, offset: _offset),
                  ),
                },
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          key: const Key('add-trip'),
          tooltip: 'Добавить поездку',
          onPressed: _addTrip,
          child: const Icon(Icons.add, size: 28),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.date,
    required this.onPrevious,
    required this.onNext,
    required this.onPickDate,
  });

  final LocalDate date;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Дневник смен',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _SquareIconButton(
                key: const Key('prev-day'),
                icon: Icons.chevron_left,
                tooltip: 'Предыдущий день',
                onPressed: onPrevious,
              ),
              Expanded(
                child: TextButton(
                  key: const Key('pick-day'),
                  onPressed: onPickDate,
                  child: Text(
                    formatDayLong(date),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              _SquareIconButton(
                key: const Key('next-day'),
                icon: Icons.chevron_right,
                tooltip: 'Следующий день',
                onPressed: onNext,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SquareIconButton extends StatelessWidget {
  const _SquareIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.outlined(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        fixedSize: const Size(44, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: Theme.of(context).colorScheme.outline),
      ),
    );
  }
}

class _DayContent extends StatelessWidget {
  const _DayContent({required this.data, required this.offset});

  final DayData data;
  final Duration offset;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 104), // room for the FAB
      children: [
        SummaryCard(summary: data.summary),
        const SizedBox(height: 24),
        Text(
          'Поездки за день',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        if (data.trips.isEmpty)
          const _EmptyDay()
        else
          for (final trip in data.trips)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TripCard(trip: trip, offset: offset),
            ),
      ],
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        child: Column(
          children: [
            Icon(Icons.directions_car_outlined, size: 32, color: colors.muted),
            const SizedBox(height: 8),
            Text('Нет поездок за этот день', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Нажмите +, чтобы добавить',
              style: theme.textTheme.bodySmall?.copyWith(color: colors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: AppColors.of(context).muted,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Повторить')),
          ],
        ),
      ),
    );
  }
}
