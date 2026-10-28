import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:handicraft_app/data/business_database.dart';
import 'package:handicraft_app/screens/business_home_screen.dart';
import 'package:handicraft_app/screens/business_records_screen.dart';
import 'package:handicraft_app/screens/detection_screen.dart';
import 'package:handicraft_app/screens/inventory_screen.dart';
import 'package:handicraft_app/screens/sales_screen.dart';

class BusinessApp extends StatefulWidget {
  const BusinessApp({
    super.key,
    this.repository,
    this.cameras = const [],
  });

  final BusinessRepository? repository;
  final List<CameraDescription> cameras;

  @override
  State<BusinessApp> createState() => _BusinessAppState();
}

class _BusinessAppState extends State<BusinessApp> {
  BusinessRepository? _repository;
  List<Sale> _sales = [];
  List<PermitRecord> _permits = [];
  List<InventoryStock> _inventory = [];
  BusinessProfile _profile = BusinessProfile.empty();
  bool _loading = true;
  String? _error;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _openDatabase();
  }

  Future<void> _openDatabase() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repository =
          widget.repository ?? await SqliteBusinessDatabase.open();
      final sales = await repository.getSales();
      final permits = await repository.getPermits();
      final inventory = await repository.getInventory();
      final profile = await repository.getProfile();
      if (!mounted) return;
      setState(() {
        _repository = repository;
        _sales = sales;
        _permits = permits;
        _inventory = inventory;
        _profile = profile;
        _loading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Could not open business records: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _error = 'Could not open the business database: $error';
          _loading = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    final repository = _repository;
    if (repository == null) return;
    try {
      final sales = await repository.getSales();
      final permits = await repository.getPermits();
      final inventory = await repository.getInventory();
      final profile = await repository.getProfile();
      if (!mounted) return;
      setState(() {
        _sales = sales;
        _permits = permits;
        _inventory = inventory;
        _profile = profile;
      });
    } catch (error, stackTrace) {
      debugPrint('Could not refresh business records: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not refresh records: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _repository == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.storage_rounded, size: 48),
                const SizedBox(height: 16),
                Text(
                  _error ?? 'Database unavailable',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _openDatabase,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final repository = _repository!;
    final pages = [
      BusinessHomeScreen(
        profile: _profile,
        sales: _sales,
        permits: _permits,
        onRefresh: _refresh,
        onOpenTab: (index) => setState(() => _selectedIndex = index),
      ),
      SalesScreen(
        repository: repository,
        sales: _sales,
        inventory: _inventory,
        onChanged: _refresh,
        onOpenInventory: () => setState(() => _selectedIndex = 3),
      ),
      BusinessRecordsScreen(
        repository: repository,
        profile: _profile,
        permits: _permits,
        onChanged: _refresh,
      ),
      InventoryScreen(
        repository: repository,
        inventory: _inventory,
        onChanged: _refresh,
      ),
      DetectionScreen(
        cameras: widget.cameras,
        repository: repository,
        onInventoryChanged: _refresh,
      ),
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale_rounded),
            label: 'Sales',
          ),
          NavigationDestination(
            icon: Icon(Icons.business_outlined),
            selectedIcon: Icon(Icons.business_rounded),
            label: 'Records',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded),
            label: 'Inventory',
          ),
          NavigationDestination(
            icon: Icon(Icons.center_focus_weak_rounded),
            selectedIcon: Icon(Icons.center_focus_strong_rounded),
            label: 'Detect',
          ),
        ],
      ),
    );
  }
}
