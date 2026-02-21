import 'dart:async';
import 'package:flutter/material.dart';
import '../services/transit_service.dart';
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
  final VoidCallback onVehicleAdded;
  final Function(String) onError;

  const _AddVehicleDialog({
    required this.cityId,
    required this.transitService,
    this.template,
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
    _vehicleIdController = TextEditingController(text: t != null ? '${t.vehicleId}_copy' : '');
    _makeController = TextEditingController(text: t?.make ?? '');
    _modelController = TextEditingController(text: t?.model ?? '');
    _registrationController = TextEditingController(text: t?.registration ?? '');
    _seatedController = TextEditingController(text: t?.passengersSeated.toString() ?? '');
    _standingController = TextEditingController(text: t?.passengersStanding.toString() ?? '');
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