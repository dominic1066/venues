import 'package:flutter/material.dart';
import '../services/transit_mqtt_manager.dart';
import '../widgets/mqtt_widgets.dart';
import '../main.dart'; // For MqttConfigProvider

/// Page that demonstrates MQTT functionality for real-time transit updates
class MqttTransitPage extends StatefulWidget {
  const MqttTransitPage({super.key});

  @override
  State<MqttTransitPage> createState() => _MqttTransitPageState();
}

class _MqttTransitPageState extends State<MqttTransitPage>
    with WidgetsBindingObserver {
  TransitMqttManager? _mqttManager;
  bool _isinitialising = false;
  String? _initialisationError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialiseMqtt();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mqttManager?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle changes for MQTT connection
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _mqttManager?.shutdown();
        break;
      case AppLifecycleState.resumed:
        if (_mqttManager != null && !_mqttManager!.isConnected) {
          _reconnectMqtt();
        }
        break;
      default:
        break;
    }
  }

  Future<void> _initialiseMqtt() async {
    if (_isinitialising) return;

    setState(() {
      _isinitialising = true;
      _initialisationError = null;
    });

    try {
      final mqttConfig = MqttConfigProvider.of(context);
      _mqttManager = TransitMqttManager(
        config: mqttConfig,
        enableDiagnostics: mqttConfig.enableDiagnostics,
      );

      // initialise and connect to MQTT broker
      final success = await _mqttManager!.initialise();
      
      if (!success) {
        setState(() {
          _initialisationError = 'Failed to connect to MQTT broker';
        });
      }
    } catch (e) {
      setState(() {
        _initialisationError = 'MQTT initialisation error: $e';
      });
    } finally {
      setState(() {
        _isinitialising = false;
      });
    }
  }

  Future<void> _reconnectMqtt() async {
    if (_mqttManager == null || _isinitialising) return;

    setState(() {
      _isinitialising = true;
      _initialisationError = null;
    });

    try {
      final success = await _mqttManager!.initialise();
      if (!success) {
        setState(() {
          _initialisationError = 'Failed to reconnect to MQTT broker';
        });
      }
    } catch (e) {
      setState(() {
        _initialisationError = 'MQTT reconnection error: $e';
      });
    } finally {
      setState(() {
        _isinitialising = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Real-time Transit Updates'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isinitialising ? null : _reconnectMqtt,
            tooltip: 'Reconnect MQTT',
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 4, // New MQTT page index (now 4th position)
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.location_city),
            label: 'Venues',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_transit),
            label: 'Transit',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Analysis',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.wifi),
            label: 'Live Updates',
          ),
        ],
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacementNamed(context, '/venues');
              break;
            case 1:
              Navigator.pushReplacementNamed(context, '/transit');
              break;
            case 2:
              Navigator.pushReplacementNamed(context, '/map');
              break;
            case 3:
              Navigator.pushReplacementNamed(context, '/transit-analysis');
              break;
            case 4:
              // Already on MQTT page
              break;
          }
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_isinitialising) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Connecting to MQTT broker...',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (_initialisationError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Connection Error',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red[700],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                _initialisationError!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _initialiseMqtt,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry Connection'),
            ),
            const SizedBox(height: 16),
            _buildConnectionInfo(),
          ],
        ),
      );
    }

    if (_mqttManager == null) {
      return const Center(
        child: Text('MQTT service not available'),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const TabBar(
              tabs: [
                Tab(
                  icon: Icon(Icons.directions_transit),
                  text: 'Live Trips',
                ),
                Tab(
                  icon: Icon(Icons.my_location),
                  text: 'Positions',
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: LiveTransitUpdatesWidget(mqttManager: _mqttManager!),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TripObservationsWidget(mqttManager: _mqttManager!),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionInfo() {
    final mqttConfig = MqttConfigProvider.of(context);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Connection Settings',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.dns, size: 16),
                const SizedBox(width: 8),
                Text('Broker: ${mqttConfig.brokerHost}:${mqttConfig.brokerPort}'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.security, size: 16),
                const SizedBox(width: 8),
                Text('TLS: ${mqttConfig.useTls ? 'Enabled' : 'Disabled'}'),
              ],
            ),
            if (mqttConfig.username != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.person, size: 16),
                  const SizedBox(width: 8),
                  Text('Username: ${mqttConfig.username}'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}