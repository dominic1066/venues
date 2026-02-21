import 'package:flutter/material.dart';
import '../services/transit_service.dart';

class ApiConfig extends InheritedWidget {
  final ApiServer server;
  final ValueNotifier<ApiServer> serverNotifier;

  ApiConfig({
    super.key,
    required this.server,
    required super.child,
  }) : serverNotifier = ValueNotifier(server);

  static ApiConfig of(BuildContext context) {
    final config = context.dependOnInheritedWidgetOfExactType<ApiConfig>();
    assert(config != null, 'No ApiConfig found in context');
    return config!;
  }

  static ApiConfig? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ApiConfig>();
  }

  @override
  bool updateShouldNotify(ApiConfig oldWidget) {
    return server != oldWidget.server;
  }
}

class ApiConfigProvider extends StatefulWidget {
  final ApiServer initialServer;
  final Widget child;

  const ApiConfigProvider({
    super.key,
    this.initialServer = ApiServer.localhost,
    required this.child,
  });

  @override
  State<ApiConfigProvider> createState() => ApiConfigProviderState();
}

class ApiConfigProviderState extends State<ApiConfigProvider> {
  late ApiServer _currentServer;

  @override
  void initState() {
    super.initState();
    _currentServer = widget.initialServer;
  }

  void setServer(ApiServer server) {
    if (_currentServer != server) {
      setState(() {
        _currentServer = server;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ApiConfig(
      server: _currentServer,
      child: widget.child,
    );
  }

  static ApiConfigProviderState of(BuildContext context) {
    final provider = context.findAncestorStateOfType<ApiConfigProviderState>();
    assert(provider != null, 'No ApiConfigProvider found in context');
    return provider!;
  }

  static ApiConfigProviderState? maybeOf(BuildContext context) {
    return context.findAncestorStateOfType<ApiConfigProviderState>();
  }
}
