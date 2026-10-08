import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:trip_core/trip_core.dart';

import 'src/api/api_client.dart';
import 'src/day/day_screen.dart';

const _apiUrl = String.fromEnvironment('API_URL');
const _driverOffset = String.fromEnvironment(
  'DRIVER_UTC_OFFSET',
  defaultValue: '+05:00',
);

void main() {
  // Android emulator reaches the host machine via 10.0.2.2.
  final baseUrl = Uri.parse(
    _apiUrl.isNotEmpty
        ? _apiUrl
        : Platform.isAndroid
        ? 'http://10.0.2.2:8080'
        : 'http://localhost:8080',
  );
  final api = ApiClient(
    baseUrl: baseUrl,
    driverOffset: parseUtcOffset(_driverOffset),
  );
  runApp(ShiftDiaryApp(api: api));
}

class ShiftDiaryApp extends StatelessWidget {
  const ShiftDiaryApp({super.key, required this.api});

  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Дневник смен',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: DayScreen(api: api),
    );
  }
}
