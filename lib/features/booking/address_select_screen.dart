import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:customer_app/app/router/routes.dart';
import 'package:customer_app/features/booking/booking_draft_controller.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_android/geolocator_android.dart';
import 'package:go_router/go_router.dart';
import 'package:repositories/repositories.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_widgets/shared_widgets.dart';

const List<Address> delhiNcrPresets = [
  Address(
    id: 'preset_cp',
    label: AddressLabel.other,
    title: 'Connaught Place',
    formattedAddress: 'Inner Circle, Connaught Place, New Delhi, 110001',
    location: GeoPoint(latitude: 28.6315, longitude: 77.2167),
  ),
  Address(
    id: 'preset_kb',
    label: AddressLabel.other,
    title: 'Karol Bagh Market',
    formattedAddress: 'Ajmal Khan Road, Karol Bagh, New Delhi, 110005',
    location: GeoPoint(latitude: 28.6515, longitude: 77.1906),
  ),
  Address(
    id: 'preset_cybercity',
    label: AddressLabel.work,
    title: 'DLF Cyber City',
    formattedAddress: 'DLF Cyber City, Sector 24, Gurugram, Haryana 122002',
    location: GeoPoint(latitude: 28.4950, longitude: 77.0895),
  ),
  Address(
    id: 'preset_noida18',
    label: AddressLabel.other,
    title: 'Noida Sector 18',
    formattedAddress: 'Sector 18 Commercial Market, Noida, Uttar Pradesh 201301',
    location: GeoPoint(latitude: 28.5700, longitude: 77.3200),
  ),
  Address(
    id: 'preset_nehruplace',
    label: AddressLabel.work,
    title: 'Nehru Place',
    formattedAddress: 'Nehru Place Commercial Complex, New Delhi 110019',
    location: GeoPoint(latitude: 28.5494, longitude: 77.2528),
  ),
  Address(
    id: 'preset_saket',
    label: AddressLabel.other,
    title: 'Saket District Centre',
    formattedAddress: 'Press Enclave Road, Saket, New Delhi 110017',
    location: GeoPoint(latitude: 28.5284, longitude: 77.2185),
  ),
  Address(
    id: 'preset_gurugram_sec49',
    label: AddressLabel.other,
    title: 'Sector 49, Gurugram',
    formattedAddress: 'Sohna Road, Sector 49, Gurugram, Haryana 122018',
    location: GeoPoint(latitude: 28.4142, longitude: 77.0439),
  ),
];

final savedAddressesProvider = FutureProvider.autoDispose<List<Address>>((
  ref,
) async {
  final result = await ref.watch(addressRepositoryProvider).getSavedAddresses();
  return result.fold((failure) => <Address>[], (page) => page.items);
});

/// Reverse-geocodes GPS coordinates into a user-friendly [Address].
Future<Address> createAddressFromPosition(Position position) async {
  String title = 'Current Location';
  String formattedAddress =
      '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';

  try {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 4);
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?lat=${position.latitude}&lon=${position.longitude}&format=json',
    );
    final request = await client.getUrl(url).timeout(const Duration(seconds: 4));
    request.headers.set('User-Agent', 'RaftarGadi-Flutter/1.0 (support@raftargadi.com)');
    final response = await request.close().timeout(const Duration(seconds: 4));
    if (response.statusCode == 200) {
      final responseBody = await response.transform(utf8.decoder).join();
      final Map<String, dynamic> data = jsonDecode(responseBody) as Map<String, dynamic>;
      final displayName = data['display_name'] as String?;
      if (displayName != null && displayName.isNotEmpty) {
        formattedAddress = displayName;
        final addressDetails = data['address'] as Map<String, dynamic>?;
        if (addressDetails != null) {
          final road = addressDetails['road'] as String?;
          final suburb = addressDetails['suburb'] as String? ?? addressDetails['neighbourhood'] as String?;
          final city = addressDetails['city'] as String? ?? addressDetails['town'] as String? ?? addressDetails['village'] as String?;

          if (road != null && suburb != null) {
            title = '$road, $suburb';
          } else if (suburb != null && city != null) {
            title = '$suburb, $city';
          } else if (road != null) {
            title = road;
          } else if (suburb != null) {
            title = suburb;
          } else if (city != null) {
            title = city;
          } else {
            final parts = displayName.split(',');
            if (parts.isNotEmpty) {
              title = parts.first.trim();
            }
          }
        } else {
          final parts = displayName.split(',');
          if (parts.isNotEmpty) {
            title = parts.first.trim();
          }
        }
      }
    }
  } catch (_) {
    // Reverse geocode failed or timed out; fall back to coordinates
  }

  return Address(
    id: 'current_loc_${DateTime.now().millisecondsSinceEpoch}',
    label: AddressLabel.other,
    title: title,
    formattedAddress: formattedAddress,
    location: GeoPoint(latitude: position.latitude, longitude: position.longitude),
  );
}

/// Requests GPS permission and acquires the user's current location.
Future<Address?> getCurrentLocationAddress(BuildContext context) async {
  try {
    if (Platform.isAndroid) {
      GeolocatorAndroid.registerWith();
    }
    debugPrint('[GPS] Checking location services...');
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[GPS] Location service disabled');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location services are disabled. Please turn on GPS.'),
            backgroundColor: RaftarColors.error,
          ),
        );
      }
      return null;
    }

    var permission = await Geolocator.checkPermission();
    debugPrint('[GPS] Initial permission: $permission');
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      debugPrint('[GPS] After request: $permission');
      if (permission == LocationPermission.denied) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission is required to detect your current location.'),
              backgroundColor: RaftarColors.error,
            ),
          );
        }
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('[GPS] Permission denied forever');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions are permanently denied. Please allow them in app settings.'),
            backgroundColor: RaftarColors.error,
          ),
        );
      }
      return null;
    }

    debugPrint('[GPS] Getting position...');
    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      debugPrint('[GPS] Current position: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      debugPrint('[GPS] getCurrentPosition error: $e, checking lastKnown...');
      position = await Geolocator.getLastKnownPosition();
      debugPrint('[GPS] Last known position: $position');
    }

    if (position == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not determine current location. Please try again.'),
            backgroundColor: RaftarColors.error,
          ),
        );
      }
      return null;
    }

    debugPrint('[GPS] Reverse geocoding position...');
    final address = await createAddressFromPosition(position);
    debugPrint('[GPS] Resolved address: ${address.title}');
    return address;
  } catch (e, stack) {
    debugPrint('[GPS] Unhandled error: $e\n$stack');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting location: $e'),
          backgroundColor: RaftarColors.error,
        ),
      );
    }
    return null;
  }
}

class AddressSelectScreen extends ConsumerStatefulWidget {
  const AddressSelectScreen({super.key});

  @override
  ConsumerState<AddressSelectScreen> createState() => _AddressSelectScreenState();
}

class _AddressSelectScreenState extends ConsumerState<AddressSelectScreen> {
  bool _isLocatingPickup = false;

  Future<void> _useCurrentLocationForPickup() async {
    setState(() => _isLocatingPickup = true);
    try {
      final address = await getCurrentLocationAddress(context);
      if (!mounted) return;
      if (address != null) {
        ref.read(bookingDraftControllerProvider.notifier).setPickup(address);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pickup set to current location: ${address.title}'),
            backgroundColor: RaftarColors.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocatingPickup = false);
    }
  }

  Future<void> _pick(
    BuildContext context,
    List<Address> addresses, {
    required bool isPickup,
  }) async {
    final chosen = await showModalBottomSheet<Address>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddressSearchSheet(
        title: isPickup ? 'Select Pickup Location' : 'Select Drop Location',
        savedAddresses: addresses,
        isPickup: isPickup,
      ),
    );
    if (chosen == null) return;
    final controller = ref.read(bookingDraftControllerProvider.notifier);
    isPickup ? controller.setPickup(chosen) : controller.setDrop(chosen);
  }

  void _applyQuickRoute(Address pickup, Address drop) {
    final controller = ref.read(bookingDraftControllerProvider.notifier);
    controller.setPickup(pickup);
    controller.setDrop(drop);
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(bookingDraftControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Where to?')),
      body: AsyncValueView<List<Address>>(
        value: ref.watch(savedAddressesProvider),
        onRetry: () => ref.invalidate(savedAddressesProvider),
        data: (addresses) => ListView(
          padding: const EdgeInsets.all(RaftarSpacing.lg),
          children: [
            _AddressField(
              icon: Icons.trip_origin_rounded,
              iconColor: RaftarColors.primary,
              label: 'Pickup Location',
              value: draft.pickup?.title,
              address: draft.pickup?.formattedAddress,
              onTap: () => _pick(context, addresses, isPickup: true),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: RaftarSpacing.sm),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _isLocatingPickup ? null : _useCurrentLocationForPickup,
                  icon: _isLocatingPickup
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: RaftarColors.primary,
                          ),
                        )
                      : const Icon(
                          Icons.my_location_rounded,
                          size: 16,
                          color: RaftarColors.primary,
                        ),
                  label: Text(
                    _isLocatingPickup ? 'Locating...' : 'Use My Current Location',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: RaftarColors.primary,
                    ),
                  ),
                ),
              ),
            ),
            _AddressField(
              icon: Icons.location_on_rounded,
              iconColor: RaftarColors.error,
              label: 'Drop Location',
              value: draft.drop?.title,
              address: draft.drop?.formattedAddress,
              onTap: () => _pick(context, addresses, isPickup: false),
            ),
            const SizedBox(height: RaftarSpacing.xl),
            Row(
              children: [
                const Icon(Icons.flash_on_rounded, size: 18, color: RaftarColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Popular 1-Tap Routes (Delhi-NCR)',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: RaftarSpacing.sm),
            _buildRouteCard(
              context,
              title: 'Connaught Place ➔ DLF Cyber City',
              subtitle: '14.5 km • Approx 35 mins',
              pickup: delhiNcrPresets[0],
              drop: delhiNcrPresets[2],
            ),
            const SizedBox(height: RaftarSpacing.sm),
            _buildRouteCard(
              context,
              title: 'Karol Bagh ➔ Noida Sector 18',
              subtitle: '18.2 km • Approx 40 mins',
              pickup: delhiNcrPresets[1],
              drop: delhiNcrPresets[3],
            ),
            const SizedBox(height: RaftarSpacing.sm),
            _buildRouteCard(
              context,
              title: 'Nehru Place ➔ Saket District Centre',
              subtitle: '6.4 km • Approx 15 mins',
              pickup: delhiNcrPresets[4],
              drop: delhiNcrPresets[5],
            ),
            const SizedBox(height: RaftarSpacing.sm),
            _buildRouteCard(
              context,
              title: 'Sector 49 ➔ DLF Cyber City (Gurugram)',
              subtitle: '9.2 km • Approx 20 mins',
              pickup: delhiNcrPresets[6],
              drop: delhiNcrPresets[2],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(RaftarSpacing.lg),
          child: RaftarButton(
            label: 'Continue to Vehicle Selection',
            onPressed: draft.hasRoute
                ? () => context.push(Routes.bookingVehicle)
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildRouteCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Address pickup,
    required Address drop,
  }) {
    return InkWell(
      onTap: () {
        _applyQuickRoute(pickup, drop);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Route selected: $title'),
            duration: const Duration(seconds: 2),
            backgroundColor: RaftarColors.primary,
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: RaftarColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: RaftarColors.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.route_rounded, size: 20, color: RaftarColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: RaftarColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: RaftarColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _AddressField extends StatelessWidget {
  const _AddressField({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.address,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String? value;
  final String? address;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RaftarCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: RaftarSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                Text(
                  value ?? 'Select ${label.toLowerCase()}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: value == null
                        ? RaftarColors.textTertiary
                        : RaftarColors.textPrimary,
                  ),
                ),
                if (address != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    address!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: RaftarColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.search_rounded,
            color: RaftarColors.primary,
          ),
        ],
      ),
    );
  }
}

class _AddressSearchSheet extends StatefulWidget {
  const _AddressSearchSheet({
    required this.title,
    required this.savedAddresses,
    required this.isPickup,
  });

  final String title;
  final List<Address> savedAddresses;
  final bool isPickup;

  @override
  State<_AddressSearchSheet> createState() => _AddressSearchSheetState();
}

class _AddressSearchSheetState extends State<_AddressSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isSearching = false;
  bool _isLocating = false;
  List<Address> _searchResults = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleUseCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      final address = await getCurrentLocationAddress(context);
      if (!mounted) return;
      if (address != null) {
        Navigator.of(context).pop(address);
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 350), () {
      _executeSearch(query);
    });
  }

  Future<void> _executeSearch(String query) async {
    setState(() => _isSearching = true);
    try {
      final client = HttpClient();
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5&countrycodes=in',
      );
      final request = await client.getUrl(url);
      request.headers.set('User-Agent', 'RaftarGadi-Flutter/1.0 (support@raftargadi.com)');
      final response = await request.close();
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final List<dynamic> data = jsonDecode(responseBody) as List<dynamic>;
        final results = <Address>[];
        for (final item in data) {
          final lat = double.tryParse(item['lat']?.toString() ?? '');
          final lon = double.tryParse(item['lon']?.toString() ?? '');
          if (lat != null && lon != null) {
            final displayName = item['display_name'] as String? ?? '';
            final parts = displayName.split(',');
            final title = parts.isNotEmpty ? parts.first.trim() : 'Location';
            results.add(
              Address(
                id: 'osm_${item['place_id']}',
                label: AddressLabel.other,
                title: title,
                formattedAddress: displayName,
                location: GeoPoint(latitude: lat, longitude: lon),
              ),
            );
          }
        }
        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
        }
      } else {
        if (mounted) setState(() => _isSearching = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  widget.isPickup ? Icons.trip_origin_rounded : Icons.location_on_rounded,
                  color: widget.isPickup ? RaftarColors.primary : RaftarColors.error,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              autofocus: false,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search city, landmark, or street in India...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                Card(
                  elevation: 0,
                  color: RaftarColors.primaryContainer.withValues(alpha: 0.45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: RaftarColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: RaftarColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: _isLocating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.my_location_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                    ),
                    title: Text(
                      _isLocating ? 'Detecting current location...' : 'Use Current Location',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: RaftarColors.primary,
                      ),
                    ),
                    subtitle: Text(
                      _isLocating
                          ? 'Acquiring GPS fix & reverse geocoding...'
                          : 'Using device GPS',
                      style: const TextStyle(
                        fontSize: 11,
                        color: RaftarColors.textSecondary,
                      ),
                    ),
                    trailing: _isLocating
                        ? null
                        : const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: RaftarColors.primary,
                          ),
                    onTap: _isLocating ? null : _handleUseCurrentLocation,
                  ),
                ),
                if (_searchResults.isNotEmpty) ...[
                  const Text(
                    'Search Results',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: RaftarColors.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final address in _searchResults) _buildTile(address, Icons.search_rounded),
                  const Divider(height: 24),
                ],
                const Text(
                  'Popular Delhi-NCR Hubs',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: RaftarColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                for (final address in delhiNcrPresets)
                  _buildTile(address, Icons.location_city_rounded),
                if (widget.savedAddresses.isNotEmpty) ...[
                  const Divider(height: 24),
                  const Text(
                    'Saved Addresses',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: RaftarColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final address in widget.savedAddresses)
                    _buildTile(address, Icons.bookmark_rounded),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(Address address, IconData icon) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: RaftarColors.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: RaftarColors.primary),
      ),
      title: Text(
        address.title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      subtitle: Text(
        address.formattedAddress,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11, color: RaftarColors.textSecondary),
      ),
      onTap: () => Navigator.of(context).pop(address),
    );
  }
}
