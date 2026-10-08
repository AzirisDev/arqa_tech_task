import 'package:flutter/material.dart';
import 'package:trip_core/trip_core.dart';

import '../add_trip/add_trip_screen.dart';
import '../api/api_client.dart';
import '../format.dart';
import 'day_controller.dart';
import 'summary_card.dart';
import 'trip_tile.dart';

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
    final saved = await Navigator.of(context).push<Trip>(MaterialPageRoute(
      builder: (_) =>
          AddTripScreen(api: widget.api, initialDate: _controller.date),
    ));
    if (saved != null) _controller.select(LocalDate.of(saved.start, _offset));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            key: const Key('prev-day'),
            tooltip: 'Предыдущий день',
            icon: const Icon(Icons.chevron_left),
            onPressed: _controller.previous,
          ),
          title: TextButton.icon(
            key: const Key('pick-day'),
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text(formatDay(_controller.date)),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              key: const Key('next-day'),
              tooltip: 'Следующий день',
              icon: const Icon(Icons.chevron_right),
              onPressed: _controller.next,
            ),
          ],
        ),
        body: switch (_controller.state) {
          DayLoading() => const Center(child: CircularProgressIndicator()),
          DayError(:final message) => _ErrorView(
              message: message,
              onRetry: () => _controller.select(_controller.date),
            ),
          DayLoaded(:final data) => RefreshIndicator(
              onRefresh: _controller.refresh,
              child: _DayContent(data: data, offset: _offset),
            ),
        },
        floatingActionButton: FloatingActionButton.extended(
          key: const Key('add-trip'),
          onPressed: _addTrip,
          icon: const Icon(Icons.add),
          label: const Text('Поездка'),
        ),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96), // room for the FAB
      children: [
        SummaryCard(summary: data.summary),
        const SizedBox(height: 8),
        if (data.trips.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: Text('Нет поездок за этот день')),
          )
        else
          for (final trip in data.trips) TripTile(trip: trip, offset: offset),
      ],
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
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Повторить')),
          ],
        ),
      ),
    );
  }
}
