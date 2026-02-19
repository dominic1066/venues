import 'package:flutter/material.dart';
import 'pages/venues_page.dart';
import 'pages/transit_page.dart';
import 'pages/map_page.dart';
import 'pages/mqtt_transit_page.dart';
import 'pages/transit_analysis_page.dart';
import 'pages/view_single_trip_page.dart';
import 'pages/occupancy_transitions_page.dart';
import 'pages/vehicles_page.dart';
import 'services/transit_service.dart';
import 'config/api_config.dart';
import 'config/mqtt_config.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ApiConfigProvider(
      initialServer: ApiServer.localhost,
      child: MqttConfigProvider(
        config: MqttConfig.local(enableDiagnostics: true),
        child: MaterialApp(
          title: 'Venues & Transit Management',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            useMaterial3: true,
          ),
          initialRoute: '/venues',
          routes: {
            '/venues': (context) => const VenuesPage(),
            '/transit': (context) => const TransitPage(),
            '/map': (context) => const MapPage(),
            '/mqtt-transit': (context) => const MqttTransitPage(),
            '/transit-analysis': (context) => const TransitAnalysisPage(),
            '/view-single-trip': (context) => const ViewSingleTripPage(),
            '/occupancy-transitions': (context) => const OccupancyTransitionsPage(),
            '/vehicles': (context) => const VehiclesPage(),
          },
        ),
      ),
    );
  }
}

/// Provider for MQTT configuration
class MqttConfigProvider extends InheritedWidget {
  final MqttConfig config;

  const MqttConfigProvider({
    super.key,
    required this.config,
    required super.child,
  });

  static MqttConfig of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<MqttConfigProvider>();
    return provider?.config ?? MqttConfig.local();
  }

  @override
  bool updateShouldNotify(MqttConfigProvider oldWidget) {
    return config != oldWidget.config;
  }
}