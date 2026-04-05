import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/transit_service.dart';
import '../models/models.dart';
import '../config/api_config.dart';
import '../widgets/server_selector.dart';

class RouteConfigsPage extends StatefulWidget {
  const RouteConfigsPage({super.key});

  @override
  State<RouteConfigsPage> createState() => _RouteConfigsPageState();
}

class _RouteConfigsPageState extends State<RouteConfigsPage> {
  late TransitService _transitService;
  ApiServer? _currentServer;

  List<TransitCity> _cities = [];
  TransitCity? _selectedCity;
  List<RouteConfig> _configs = [];

  bool _isLoadingCities = true;
  bool _isLoadingConfigs = false;
  String? _citiesError;
  String? _configsError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final server = ApiConfig.of(context).server;
    if (_currentServer != server) {
      _currentServer = server;
      _transitService = TransitService(server: server, enableDiagnostics: true);
      _loadCities();
    }
  }

  @override
  void dispose() {
    _transitService.dispose();
    super.dispose();
  }

  Future<void> _loadCities() async {
    setState(() {
      _isLoadingCities = true;
      _citiesError = null;
    });
    try {
      final cities = await _transitService.getTransitCities();
      setState(() {
        _cities = cities;
        _isLoadingCities = false;
        if (cities.isNotEmpty && _selectedCity == null) {
          _selectedCity = cities.first;
          _loadConfigs();
        }
      });
    } catch (e) {
      setState(() {
        _citiesError = e.toString();
        _isLoadingCities = false;
      });
    }
  }

  Future<void> _loadConfigs() async {
    if (_selectedCity == null) return;
    setState(() {
      _isLoadingConfigs = true;
      _configsError = null;
    });
    try {
      final configs = await _transitService.getRouteConfigs(_selectedCity!.id);
      setState(() {
        _configs = configs;
        _isLoadingConfigs = false;
      });
    } catch (e) {
      setState(() {
        _configsError = e.toString();
        _isLoadingConfigs = false;
      });
    }
  }

  void _onCityChanged(TransitCity? city) {
    if (city != null && city != _selectedCity) {
      setState(() {
        _selectedCity = city;
        _configs = [];
      });
      _loadConfigs();
    }
  }

  void _showEditDialog({RouteConfig? existing}) {
    if (_selectedCity == null) return;
    showDialog(
      context: context,
      builder: (_) => _RouteConfigDialog(
        cityId: _selectedCity!.id,
        transitService: _transitService,
        existing: existing,
        onSaved: _loadConfigs,
        onError: (msg) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(msg), backgroundColor: Colors.red),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Configurations'),
        actions: [
          const ServerSelector(),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadConfigs,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Route Config',
            onPressed: _selectedCity != null ? () => _showEditDialog() : null,
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCitySelector(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildCitySelector() {
    if (_isLoadingCities) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: LinearProgressIndicator(),
      );
    }
    if (_citiesError != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Error loading cities: $_citiesError',
            style: const TextStyle(color: Colors.red)),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: DropdownButtonFormField<TransitCity>(
        value: _selectedCity,
        decoration: const InputDecoration(
          labelText: 'City',
          border: OutlineInputBorder(),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        items: _cities
            .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
            .toList(),
        onChanged: _onCityChanged,
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoadingConfigs) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_configsError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 8),
            Text(_configsError!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              onPressed: _loadConfigs,
            ),
          ],
        ),
      );
    }
    if (_selectedCity == null) {
      return const Center(child: Text('Select a city to view route configurations.'));
    }
    if (_configs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.route, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No route configurations found.'),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Route Config'),
              onPressed: () => _showEditDialog(),
            ),
          ],
        ),
      );
    }
    return _buildTable();
  }

  Widget _buildTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(16),
        child: DataTable(
          columnSpacing: 24,
          headingRowColor: WidgetStateProperty.all(
              Theme.of(context).colorScheme.surfaceContainerHighest),
          columns: const [
            DataColumn(label: Text('Route ID')),
            DataColumn(label: Text('Legs'), numeric: true),
            DataColumn(label: Text('Term. District'), numeric: true),
            DataColumn(label: Text('Direction'), numeric: true),
            DataColumn(label: Text('In Error Calc')),
            DataColumn(label: Text('')),
          ],
          rows: _configs.map((cfg) {
            return DataRow(
              cells: [
                DataCell(Text(cfg.routeId)),
                DataCell(Text('${cfg.legs}')),
                DataCell(Text('${cfg.terminatingDistrict}')),
                DataCell(Text('${cfg.direction}')),
                DataCell(
                  Icon(
                    cfg.includeInErrorCalculation
                        ? Icons.check_circle
                        : Icons.cancel,
                    color: cfg.includeInErrorCalculation
                        ? Colors.green
                        : Colors.grey,
                    size: 20,
                  ),
                ),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    tooltip: 'Edit',
                    onPressed: () => _showEditDialog(existing: cfg),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Drawer _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.deepPurple),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.analytics, color: Colors.white, size: 48),
                SizedBox(height: 16),
                Text('Venues & Transit',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
                Text('Management App',
                    style: TextStyle(color: Colors.white70, fontSize: 16)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.business),
            title: const Text('Venues'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/venues');
            },
          ),
          ListTile(
            leading: const Icon(Icons.train),
            title: const Text('Transit'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/transit');
            },
          ),
          ListTile(
            leading: const Icon(Icons.map),
            title: const Text('Map'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/map');
            },
          ),
          ListTile(
            leading: const Icon(Icons.analytics),
            title: const Text('Transit Analysis'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/transit-analysis');
            },
          ),
          ListTile(
            leading: const Icon(Icons.route),
            title: const Text('View Single Trip'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/view-single-trip');
            },
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Occupancy Transitions'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/occupancy-transitions');
            },
          ),
          ListTile(
            leading: const Icon(Icons.directions_bus),
            title: const Text('Vehicles'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/vehicles');
            },
          ),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Route Configurations'),
            selected: true,
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.wifi),
            title: const Text('Live Updates'),
            subtitle: const Text('MQTT Real-time'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/mqtt-transit');
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add / Edit dialog
// ---------------------------------------------------------------------------

class _RouteConfigDialog extends StatefulWidget {
  final int cityId;
  final TransitService transitService;
  final RouteConfig? existing;
  final VoidCallback onSaved;
  final Function(String) onError;

  const _RouteConfigDialog({
    required this.cityId,
    required this.transitService,
    this.existing,
    required this.onSaved,
    required this.onError,
  });

  @override
  State<_RouteConfigDialog> createState() => _RouteConfigDialogState();
}

class _RouteConfigDialogState extends State<_RouteConfigDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _routeIdController;
  late final TextEditingController _legsController;
  late final TextEditingController _terminatingDistrictController;
  late final TextEditingController _directionController;
  late bool _includeInErrorCalculation;
  bool _isSubmitting = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _routeIdController = TextEditingController(text: e?.routeId ?? '');
    _legsController = TextEditingController(text: e != null ? '${e.legs}' : '');
    _terminatingDistrictController =
        TextEditingController(text: e != null ? '${e.terminatingDistrict}' : '');
    _directionController = TextEditingController(text: e != null ? '${e.direction}' : '');
    _includeInErrorCalculation = e?.includeInErrorCalculation ?? true;
  }

  @override
  void dispose() {
    _routeIdController.dispose();
    _legsController.dispose();
    _terminatingDistrictController.dispose();
    _directionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final config = RouteConfig(
        cityId: widget.cityId,
        routeId: _routeIdController.text.trim(),
        legs: int.parse(_legsController.text),
        terminatingDistrict: int.parse(_terminatingDistrictController.text),
        includeInErrorCalculation: _includeInErrorCalculation,
        direction: int.parse(_directionController.text)
      );
      await widget.transitService.submitRouteConfig(config);
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      widget.onError(e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing
          ? 'Edit Route Config – ${widget.existing!.routeId}'
          : 'Add Route Config'),
      content: SizedBox(
        width: 340,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _routeIdController,
                decoration: const InputDecoration(
                  labelText: 'Route ID *',
                  hintText: 'e.g., 10, 301X',
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Route ID is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _legsController,
                decoration: const InputDecoration(
                  labelText: 'Legs *',
                  hintText: 'Number of legs (e.g., 2)',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Legs is required';
                  final n = int.tryParse(v);
                  if (n == null || n < 1) return 'Must be a positive integer';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _directionController,
                decoration: const InputDecoration(
                  labelText: 'Direction *',
                  hintText: 'Direction (e.g., 0, 1)',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Direction is required';
                  final n = int.tryParse(v);
                  if (n == null || n < 0 || n > 1) return 'Must be 0 or 1';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _terminatingDistrictController,
                decoration: const InputDecoration(
                  labelText: 'Terminating District *',
                  hintText: 'District ID (e.g., 0)',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Terminating District is required';
                  if (int.tryParse(v) == null) return 'Must be an integer';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Include in Error Calculation'),
                value: _includeInErrorCalculation,
                onChanged: (v) => setState(() => _includeInErrorCalculation = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(_isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
