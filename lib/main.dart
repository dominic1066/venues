import 'package:flutter/material.dart';
import 'pages/venues_page.dart';
import 'pages/transit_page.dart';
import 'pages/map_page.dart';
import 'services/transit_service.dart';
import 'config/api_config.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ApiConfigProvider(
      initialServer: ApiServer.localhost,
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
        },
      ),
    );
  }
}