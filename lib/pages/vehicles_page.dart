import 'dart:async';
import 'package:flutter/material.dart';
import '../services/transit_service.dart';
import '../services/external_service.dart';
import '../models/models.dart';
import '../config/api_config.dart';
import '../widgets/server_selector.dart';

class VehiclesPage extends StatefulWidget {
  const VehiclesPage({super.key});

  @override
  State<VehiclesPage> createState() => _VehiclesPageState();
}

class _VehiclesPageState extends State<VehiclesPage> {
  late TransitService _transitService;
  late ExternalService _externalService;
  final TextEditingController _searchController = TextEditingController();
  
  List<TransitCity> _cities = [];
  TransitCity? _selectedCity;
  List<Vehicle> _vehicles = [];
  String _searchQuery = '';
  
  bool _isLoadingCities = true;
  bool _isLoadingVehicles = false;
  bool _isSubmitting = false;
  String? _citiesError;
  String? _vehiclesError;
  String? _submitError;
  String? _submitMessage;
  ApiServer? _currentServer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final server = ApiConfig.of(context).server;
    if (_currentServer != server) {
      _currentServer = server;
      _transitService = TransitService(
        server: server,
        enableDiagnostics: true,
      );
      _externalService = ExternalService(
        server: server,
        enableDiagnostics: true,
      );
      _loadCities();
    }
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
          _loadVehicles();
        }
      });
    } catch (e) {
      setState(() {
        _citiesError = e.toString();
        _isLoadingCities = false;
      });
    }
  }

  Future<void> _loadVehicles() async {
    if (_selectedCity == null) return;

    setState(() {
      _isLoadingVehicles = true;
      _vehiclesError = null;
    });

    try {
      final vehicles = await _transitService.getCityVehicles(_selectedCity!.id);
      setState(() {
        _vehicles = vehicles;
        _isLoadingVehicles = false;
      });
    } catch (e) {
      setState(() {
        _vehiclesError = e.toString();
        _isLoadingVehicles = false;
      });
    }
  }

  void _onCityChanged(TransitCity? city) {
    if (city != null && city != _selectedCity) {
      setState(() {
        _selectedCity = city;
        _vehicles = [];
      });
      _loadVehicles();
    }
  }

  Future<void> _showUnmatchedVehiclesDialog() async {
    if (_selectedCity == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _UnmatchedVehiclesDialog(
        cityId: _selectedCity!.id,
        cityName: _selectedCity!.name,
        transitService: _transitService,
        externalService: _externalService,
        onVehicleAdded: () {
          _loadVehicles();
          setState(() {
            _submitMessage = 'Vehicle added successfully!';
            _submitError = null;
          });
          Timer(const Duration(seconds: 3), () {
            if (mounted) setState(() => _submitMessage = null);
          });
        },
      ),
    );
  }

  void _showAddVehicleDialog({Vehicle? template}) {
    if (_selectedCity == null) return;

    showDialog(
      context: context,
      builder: (context) => _AddVehicleDialog(
        cityId: _selectedCity!.id,
        transitService: _transitService,
        template: template,
        onVehicleAdded: () {
          _loadVehicles();
          setState(() {
            _submitMessage = 'Vehicle added successfully!';
            _submitError = null;
          });
          // Clear message after 3 seconds
          Timer(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _submitMessage = null;
              });
            }
          });
        },
        onError: (error) {
          setState(() {
            _submitError = error;
            _submitMessage = null;
          });
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.blue,
            ),
            child: Text(
              'Venues App',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () => Navigator.pushReplacementNamed(context, '/'),
          ),
          ListTile(
            leading: const Icon(Icons.map),
            title: const Text('Map'),
            onTap: () => Navigator.pushReplacementNamed(context, '/map'),
          ),
          ListTile(
            leading: const Icon(Icons.analytics),
            title: const Text('Transit Analysis'),
            onTap: () => Navigator.pushReplacementNamed(context, '/transit-analysis'),
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Occupancy Transitions'),
            onTap: () => Navigator.pushReplacementNamed(context, '/occupancy-transitions'),
          ),
          ListTile(
            leading: const Icon(Icons.directions_bus),
            title: const Text('Vehicles'),
            selected: true,
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Route Configurations'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.pushReplacementNamed(context, '/route-configs');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoadingCities) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading cities...'),
          ],
        ),
      );
    }

    if (_citiesError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error loading cities: $_citiesError'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadCities,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // City selector and status messages
        _buildControls(),
        // Vehicle list
        Expanded(child: _buildVehicleList()),
      ],
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // City selector
          Row(
            children: [
              const Icon(Icons.location_city),
              const SizedBox(width: 8),
              const Text('City:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<TransitCity>(
                  value: _selectedCity,
                  isExpanded: true,
                  items: _cities.map((city) {
                    return DropdownMenuItem<TransitCity>(
                      value: city,
                      child: Text(city.name),
                    );
                  }).toList(),
                  onChanged: _onCityChanged,
                ),
              ),
            ],
          ),
          // Search bar
          if (_vehicles.isNotEmpty) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search Vehicle ID',
                hintText: 'Type to filter...',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ],
          // Status messages
          if (_submitMessage != null)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_submitMessage!)),
                ],
              ),
            ),
          if (_submitError != null)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_submitError!)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVehicleList() {
    if (_selectedCity == null) {
      return const Center(
        child: Text('Please select a city to view vehicles.'),
      );
    }

    if (_isLoadingVehicles) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading vehicles...'),
          ],
        ),
      );
    }

    if (_vehiclesError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error loading vehicles: $_vehiclesError'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadVehicles,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final filteredVehicles = _vehicles.where((vehicle) {
      if (_searchQuery.isEmpty) return true;
      return vehicle.vehicleId.toLowerCase().contains(_searchQuery);
    }).toList();

    if (filteredVehicles.isEmpty) {
      if (_vehicles.isNotEmpty) {
        return const Center(
          child: Text('No vehicles found matching your search.'),
        );
      }
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_bus, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No vehicles found for this city.'),
            SizedBox(height: 8),
            Text('Tap the + button to add a vehicle.'),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredVehicles.length,
      itemBuilder: (context, index) {
        final vehicle = filteredVehicles[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.directions_bus, color: Colors.blue),
                title: Text(vehicle.vehicleId),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (vehicle.make != null && vehicle.model != null)
                      Text('${vehicle.make} ${vehicle.model} Reg: ${vehicle.registration ?? 'N/A'}'),
                    Text('Capacity: ${vehicle.passengersTotal} passengers. Seated: ${vehicle.passengersSeated}, Standing: ${vehicle.passengersStanding}'),
                  ],
                ),
                isThreeLine: true,
                trailing: TextButton.icon(
                  onPressed: () => _showAddVehicleDialog(template: vehicle),
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Clone'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicles'),
        actions: [
          if (_selectedCity != null)
            IconButton(
              icon: const Icon(Icons.search_off),
              tooltip: 'Show Unmatched Vehicles',
              onPressed: _showUnmatchedVehiclesDialog,
            ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _buildBody(),
      floatingActionButton: _selectedCity != null
          ? FloatingActionButton(
              onPressed: _showAddVehicleDialog,
              tooltip: 'Add Vehicle',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class _AddVehicleDialog extends StatefulWidget {
  final int cityId;
  final TransitService transitService;
  final Vehicle? template;
  final String? initialVehicleId;
  final String? initialMake;
  final String? initialModel;
  final String? initialRegistration;
  final int? initialSeated;
  final int? initialStanding;
  final VoidCallback onVehicleAdded;
  final Function(String) onError;

  const _AddVehicleDialog({
    required this.cityId,
    required this.transitService,
    this.template,
    this.initialVehicleId,
    this.initialMake,
    this.initialModel,
    this.initialRegistration,
    this.initialSeated,
    this.initialStanding,
    required this.onVehicleAdded,
    required this.onError,
  });

  @override
  State<_AddVehicleDialog> createState() => _AddVehicleDialogState();
}

class _AddVehicleDialogState extends State<_AddVehicleDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _vehicleIdController;
  late final TextEditingController _makeController;
  late final TextEditingController _modelController;
  late final TextEditingController _registrationController;
  late final TextEditingController _seatedController;
  late final TextEditingController _standingController;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    _vehicleIdController = TextEditingController(
      text: widget.initialVehicleId ?? (t != null ? '${t.vehicleId}_copy' : ''),
    );
    _makeController = TextEditingController(text: widget.initialMake ?? t?.make ?? '');
    _modelController = TextEditingController(text: widget.initialModel ?? t?.model ?? '');
    _registrationController = TextEditingController(
      text: widget.initialRegistration ?? t?.registration ?? '',
    );
    _seatedController = TextEditingController(
      text: widget.initialSeated?.toString() ?? t?.passengersSeated.toString() ?? '',
    );
    _standingController = TextEditingController(
      text: widget.initialStanding?.toString() ?? t?.passengersStanding.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _vehicleIdController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _registrationController.dispose();
    _seatedController.dispose();
    _standingController.dispose();
    super.dispose();
  }

  void _calculateTotal() {
    final seated = int.tryParse(_seatedController.text) ?? 0;
    final standing = int.tryParse(_standingController.text) ?? 0;
    // Auto-update total whenever seated or standing changes
    setState(() {
      // This will trigger a rebuild but total is calculated in submit
    });
  }

  Future<void> _submitVehicle() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final seated = int.parse(_seatedController.text);
      final standing = int.parse(_standingController.text);
      final total = seated + standing;

      final vehicle = Vehicle(
        cityId: widget.cityId,
        vehicleId: _vehicleIdController.text.trim(),
        passengersSeated: seated,
        passengersStanding: standing,
        passengersTotal: total,
        make: _makeController.text.trim().isNotEmpty ? _makeController.text.trim() : null,
        model: _modelController.text.trim().isNotEmpty ? _modelController.text.trim() : null,
        registration: _registrationController.text.trim().isNotEmpty ? _registrationController.text.trim() : null,
      );

      final success = await widget.transitService.submitVehicleData(vehicle);
      
      if (success) {
        widget.onVehicleAdded();
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        widget.onError('Failed to submit vehicle data');
      }
    } catch (e) {
      widget.onError(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Vehicle'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _vehicleIdController,
                decoration: const InputDecoration(
                  labelText: 'Vehicle ID *',
                  hintText: 'e.g., V123, BUS001',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vehicle ID is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _makeController,
                decoration: const InputDecoration(
                  labelText: 'Make',
                  hintText: 'e.g., Mercedes, Volvo',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _modelController,
                decoration: const InputDecoration(
                  labelText: 'Model',
                  hintText: 'e.g., Citaro, 7900',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _registrationController,
                decoration: const InputDecoration(
                  labelText: 'Registration',
                  hintText: 'e.g., ABC123, XYZ789',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _seatedController,
                decoration: const InputDecoration(
                  labelText: 'Seated Passengers *',
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => _calculateTotal(),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Seated capacity is required';
                  }
                  final number = int.tryParse(value);
                  if (number == null || number < 0) {
                    return 'Enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _standingController,
                decoration: const InputDecoration(
                  labelText: 'Standing Passengers *',
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => _calculateTotal(),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Standing capacity is required';
                  }
                  final number = int.tryParse(value);
                  if (number == null || number < 0) {
                    return 'Enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Show calculated total
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Capacity:'),
                    Text(
                      '${(int.tryParse(_seatedController.text) ?? 0) + (int.tryParse(_standingController.text) ?? 0)} passengers',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
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
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitVehicle,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add Vehicle'),
        ),
      ],
    );
  }
}

class _UnmatchedVehiclesDialog extends StatefulWidget {
  final int cityId;
  final String cityName;
  final TransitService transitService;
  final ExternalService externalService;
  final VoidCallback onVehicleAdded;

  const _UnmatchedVehiclesDialog({
    required this.cityId,
    required this.cityName,
    required this.transitService,
    required this.externalService,
    required this.onVehicleAdded,
  });

  @override
  State<_UnmatchedVehiclesDialog> createState() => _UnmatchedVehiclesDialogState();
}

class _UnmatchedVehiclesDialogState extends State<_UnmatchedVehiclesDialog> {
  List<UnmatchedVehicle>? _vehicles;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final vehicles = await widget.transitService.getUnmatchedVehicles(widget.cityId);
      if (mounted) {
        setState(() {
          _vehicles = vehicles;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Unmatched Vehicles – ${widget.cityName}'),
      content: SizedBox(
        width: double.maxFinite,
        child: _buildContent(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error, color: Colors.red, size: 48),
          const SizedBox(height: 8),
          Text(_error!),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: _load, child: const Text('Retry')),
        ],
      );
    }

    if (_vehicles == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_vehicles!.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No unmatched vehicles found.'),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_vehicles!.length} unmatched vehicle${_vehicles!.length == 1 ? '' : 's'}',
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _vehicles!.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final vehicleId = _vehicles![index].vehicleId;
              return ListTile(
                leading: const Icon(Icons.directions_bus_outlined, size: 18, color: Colors.orange),
                title: Text(vehicleId),
                trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => _BusAustraliaResultDialog(
                    cityId: widget.cityId,
                    vehicleId: vehicleId,
                    externalService: widget.externalService,
                    transitService: widget.transitService,
                    onVehicleAdded: widget.onVehicleAdded,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BusAustraliaResultDialog extends StatefulWidget {
  final int cityId;
  final String vehicleId;
  final ExternalService externalService;
  final TransitService transitService;
  final VoidCallback onVehicleAdded;

  const _BusAustraliaResultDialog({
    required this.cityId,
    required this.vehicleId,
    required this.externalService,
    required this.transitService,
    required this.onVehicleAdded,
  });

  @override
  State<_BusAustraliaResultDialog> createState() => _BusAustraliaResultDialogState();
}

class _BusAustraliaResultDialogState extends State<_BusAustraliaResultDialog> {
  BusAustraliaSearchResponse? _response;
  String? _error;

  Future<void> _onResultSelected(BuildContext context, BusAustraliaResult result) async {
    TransitVehicleSeatingCode? seatingCode;

    if (result.seatingCodes != null && result.seatingCodes!.isNotEmpty) {
      seatingCode = await widget.transitService.getTransitVehicleSeatingCode(result.seatingCodes!);

      if (!mounted) return;

      if (seatingCode == null) {
        // Not in the database — ask user to add it
        seatingCode = await showDialog<TransitVehicleSeatingCode>(
          context: context,
          builder: (_) => _AddSeatingCodeDialog(
            seatingCode: result.seatingCodes!,
            transitService: widget.transitService,
          ),
        );
        if (!mounted || seatingCode == null) return; // user skipped
      }
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => _AddVehicleDialog(
        cityId: widget.cityId,
        transitService: widget.transitService,
        initialVehicleId: widget.vehicleId,
        initialModel: result.chassis,
        initialRegistration: result.registration,
        initialSeated: seatingCode?.passengersSeated,
        initialStanding: seatingCode?.passengersStanding,
        onVehicleAdded: widget.onVehicleAdded,
        onError: (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e), backgroundColor: Colors.red),
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _response = null;
      _error = null;
    });
    try {
      final result = await widget.externalService.busAustraliaSearch(widget.cityId, widget.vehicleId);
      if (mounted) setState(() => _response = result);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Bus Australia – ${widget.vehicleId}'),
      content: SizedBox(
        width: double.maxFinite,
        child: _buildContent(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error, color: Colors.red, size: 48),
          const SizedBox(height: 8),
          Text(_error!),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: _load, child: const Text('Retry')),
        ],
      );
    }

    if (_response == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_response!.results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('No records found on Bus Australia for this vehicle.'),
            const SizedBox(height: 16),
            TextButton.icon(
              icon: const Icon(Icons.help_outline),
              label: const Text('Add Vehicle as Unknown?'),
              onPressed: () => _addAsUnknown(context),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._response!.results.map((r) => _ResultCard(
                result: r,
                onTap: () => _onResultSelected(context, r),
              )),
          const Divider(),
          TextButton.icon(
            icon: const Icon(Icons.help_outline),
            label: const Text('Add Vehicle as Unknown?'),
            onPressed: () => _addAsUnknown(context),
          ),
        ],
      ),
    );
  }

  void _addAsUnknown(BuildContext context) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (_) => _AddVehicleDialog(
        cityId: widget.cityId,
        transitService: widget.transitService,
        initialVehicleId: widget.vehicleId,
        initialModel: 'UNKNOWN',
        initialRegistration: 'UNKNOWN',
        initialSeated: 35,
        initialStanding: 25,
        onVehicleAdded: widget.onVehicleAdded,
        onError: (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e), backgroundColor: Colors.red),
          );
        },
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final BusAustraliaResult result;
  final VoidCallback? onTap;

  const _ResultCard({required this.result, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (result.operator != null)
                  _Row(label: 'Operator', value: result.operator!),
                if (result.chassis != null)
                  _Row(label: 'Chassis', value: result.chassis!),
                if (result.registration != null)
                  _Row(label: 'Registration', value: result.registration!),
                if (result.seatingCodes != null)
                  _Row(label: 'Seating', value: result.seatingCodes!),
              ],
            ),
          ),
          if (onTap != null)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 4),
                child: TextButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.add_circle_outline, size: 16),
                  label: const Text('Add as Vehicle'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;

  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

class _AddSeatingCodeDialog extends StatefulWidget {
  final String seatingCode;
  final TransitService transitService;

  const _AddSeatingCodeDialog({
    required this.seatingCode,
    required this.transitService,
  });

  @override
  State<_AddSeatingCodeDialog> createState() => _AddSeatingCodeDialogState();
}

class _AddSeatingCodeDialogState extends State<_AddSeatingCodeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _seatedController = TextEditingController();
  final _standingController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _seatedController.dispose();
    _standingController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final code = TransitVehicleSeatingCode(
        seatingCode: widget.seatingCode,
        passengersSeated: int.parse(_seatedController.text),
        passengersStanding: int.parse(_standingController.text),
      );
      await widget.transitService.submitTransitVehicleSeatingCode(code);
      if (mounted) Navigator.pop(context, code);
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Seating Code'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Seating code "${widget.seatingCode}" is not in the database.',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              const Text(
                'Enter the passenger capacities to add it before continuing.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextFormField(
                readOnly: true,
                initialValue: widget.seatingCode,
                decoration: const InputDecoration(
                  labelText: 'Seating Code',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _seatedController,
                decoration: const InputDecoration(
                  labelText: 'Seated Passengers *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (int.tryParse(v) == null || int.parse(v) < 0) return 'Enter a valid number';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _standingController,
                decoration: const InputDecoration(
                  labelText: 'Standing Passengers *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (int.tryParse(v) == null || int.parse(v) < 0) return 'Enter a valid number';
                  return null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Skip'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add & Continue'),
        ),
      ],
    );
  }
}