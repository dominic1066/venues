/// Configuration class for MQTT broker settings
class MqttConfig {
  final String brokerHost;
  final int brokerPort;
  final String? username;
  final String? password;
  final bool useTls;
  final bool enableDiagnostics;

  const MqttConfig({
    this.brokerHost = 'bwb-slow',
    this.brokerPort = 1883,
    this.username,
    this.password,
    this.useTls = false,
    this.enableDiagnostics = false,
  });

  /// Create configuration for local development
  factory MqttConfig.local({
    int port = 1883,
    bool enableDiagnostics = true,
  }) {
    return MqttConfig(
      brokerHost: 'bwb-slow',
      brokerPort: port,
      enableDiagnostics: enableDiagnostics,
    );
  }

  /// Create configuration for production broker
  factory MqttConfig.production({
    required String host,
    int port = 1883,
    String? username,
    String? password,
    bool useTls = true,
    bool enableDiagnostics = false,
  }) {
    return MqttConfig(
      brokerHost: host,
      brokerPort: port,
      username: username,
      password: password,
      useTls: useTls,
      enableDiagnostics: enableDiagnostics,
    );
  }

  /// Create configuration for Eclipse Mosquitto test broker
  factory MqttConfig.mosquittoTest({
    bool enableDiagnostics = true,
  }) {
    return MqttConfig(
      brokerHost: 'test.mosquitto.org',
      brokerPort: 1883,
      enableDiagnostics: enableDiagnostics,
    );
  }

  /// Create configuration for HiveMQ public broker
  factory MqttConfig.hivemqPublic({
    bool enableDiagnostics = true,
  }) {
    return MqttConfig(
      brokerHost: 'broker.hivemq.com',
      brokerPort: 1883,
      enableDiagnostics: enableDiagnostics,
    );
  }

  @override
  String toString() {
    return 'MqttConfig(host: $brokerHost:$brokerPort, tls: $useTls, auth: ${username != null})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MqttConfig &&
        other.brokerHost == brokerHost &&
        other.brokerPort == brokerPort &&
        other.username == username &&
        other.password == password &&
        other.useTls == useTls;
  }

  @override
  int get hashCode => Object.hash(brokerHost, brokerPort, username, password, useTls);
}