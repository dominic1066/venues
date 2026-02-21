import 'package:flutter/material.dart';
import '../services/transit_service.dart';
import '../config/api_config.dart';

class ServerSelector extends StatelessWidget {
  const ServerSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final currentServer = ApiConfig.of(context).server;
    final provider = ApiConfigProviderState.of(context);

    return PopupMenuButton<ApiServer>(
      icon: Icon(
        Icons.dns,
        color: currentServer == ApiServer.localhost 
            ? Colors.green 
            : Colors.orange,
      ),
      tooltip: 'API Server: ${_getServerName(currentServer)}',
      onSelected: (ApiServer server) {
        provider.setServer(server);
        // Show snackbar to confirm
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Switched to ${_getServerName(server)}'),
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'Reload',
              onPressed: () {
                // Trigger page reload by navigating to same route
                Navigator.pushReplacementNamed(
                  context,
                  ModalRoute.of(context)?.settings.name ?? '/transit',
                );
              },
            ),
          ),
        );
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: ApiServer.localhost,
          child: Row(
            children: [
              Icon(
                Icons.computer,
                color: currentServer == ApiServer.localhost
                    ? Colors.green
                    : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                'Localhost',
                style: TextStyle(
                  fontWeight: currentServer == ApiServer.localhost
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
              const SizedBox(width: 8),
              if (currentServer == ApiServer.localhost)
                const Icon(Icons.check, color: Colors.green, size: 16),
            ],
          ),
        ),
        PopupMenuItem(
          value: ApiServer.ngrok,
          child: Row(
            children: [
              Icon(
                Icons.cloud,
                color: currentServer == ApiServer.ngrok
                    ? Colors.orange
                    : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                'Ngrok',
                style: TextStyle(
                  fontWeight: currentServer == ApiServer.ngrok
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
              const SizedBox(width: 8),
              if (currentServer == ApiServer.ngrok)
                const Icon(Icons.check, color: Colors.orange, size: 16),
            ],
          ),
        ),
      ],
    );
  }

  String _getServerName(ApiServer server) {
    switch (server) {
      case ApiServer.localhost:
        return 'Localhost';
      case ApiServer.ngrok:
        return 'Ngrok';
    }
  }
}
