import 'dart:async';

import 'package:core/core.dart';
import 'package:customer_app/app/router/routes.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:repositories/repositories.dart';

class TripTrackingScreen extends ConsumerStatefulWidget {
  const TripTrackingScreen({required this.bookingId, super.key});

  final String bookingId;

  @override
  ConsumerState<TripTrackingScreen> createState() => _TripTrackingScreenState();
}

class _TripTrackingScreenState extends ConsumerState<TripTrackingScreen> {
  final MapController _mapController = MapController();
  Timer? _pollTimer;
  StreamSubscription<Map<String, dynamic>>? _locationSub;
  StreamSubscription<Map<String, dynamic>>? _statusSub;

  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _trackingData;

  @override
  void initState() {
    super.initState();
    _fetchTracking(isInitial: true);
    _setupWebSocket();
    // Poll for live driver location updates every 4 seconds as fallback
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _fetchTracking();
    });
  }

  void _setupWebSocket() {
    final socket = ref.read(socketServiceProvider);
    socket.connect(token: ref.read(apiClientProvider).authToken);
    socket.joinBooking(widget.bookingId);

    _locationSub = socket.watchDriverLocation(widget.bookingId).listen((data) {
      if (!mounted) return;
      final lat = (data['latitude'] as num?)?.toDouble();
      final lng = (data['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null && _trackingData != null) {
        setState(() {
          _trackingData = {
            ..._trackingData!,
            'liveLocation': {
              'latitude': lat,
              'longitude': lng,
              'heading': data['heading'] ?? 0,
              'speed': data['speed'] ?? 0,
              'updatedAt': DateTime.now().toIso8601String(),
            },
          };
        });
      }
    });

    _statusSub = socket.watchBookingStatus(widget.bookingId).listen((data) {
      if (!mounted) return;
      final newStatus = data['status'] as String?;
      if (newStatus != null && _trackingData != null) {
        setState(() {
          _trackingData = {
            ..._trackingData!,
            'status': newStatus,
          };
        });
        _fetchTracking();
      }
    });
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _statusSub?.cancel();
    _pollTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _fetchTracking({bool isInitial = false}) async {
    if (isInitial) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    final result = await ref
        .read(bookingRepositoryProvider)
        .getBookingTracking(widget.bookingId);

    if (!mounted) return;

    result.match(
      (failure) {
        if (isInitial) {
          setState(() {
            _isLoading = false;
            _errorMessage = failure.message;
          });
        }
      },
      (data) {
        setState(() {
          _trackingData = data;
          _isLoading = false;
          _errorMessage = null;
        });

        final status = data['status'] as String? ?? '';
        final isCompleted = status == 'TRIP_COMPLETED' || status == 'COMPLETED' || status == 'CANCELLED';
        if (isCompleted) {
          _pollTimer?.cancel();
          _pollTimer = null;
        }

        // Center map on initial load (only for active trips where map is rendered)
        if (isInitial && !isCompleted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            try {
              final liveLoc = data['liveLocation'] as Map<String, dynamic>?;
              final pickup = data['pickup'] as Map<String, dynamic>?;
              final targetLat = (liveLoc?['latitude'] ?? pickup?['lat'] ?? 28.6139) as num;
              final targetLng = (liveLoc?['longitude'] ?? pickup?['lng'] ?? 77.2090) as num;
              _mapController.move(LatLng(targetLat.toDouble(), targetLng.toDouble()), 13.5);
            } catch (_) {
              // Ignore if map controller is not yet attached
            }
          });
        }
      },
    );
  }

  void _recenterMap() {
    try {
      final liveLoc = _trackingData?['liveLocation'] as Map<String, dynamic>?;
      final pickup = _trackingData?['pickup'] as Map<String, dynamic>?;

      final lat = (liveLoc?['latitude'] ?? pickup?['lat'] ?? 28.6139) as num;
      final lng = (liveLoc?['longitude'] ?? pickup?['lng'] ?? 77.2090) as num;
      _mapController.move(LatLng(lat.toDouble(), lng.toDouble()), 14.5);
    } catch (_) {
      // Ignore if map controller is not yet attached
    }
  }

  Future<void> _cancelSearch() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Delivery Search?'),
        content: const Text(
          'Are you sure you want to stop searching for a delivery partner? No cancellation fee will be charged.',
        ),
        actions: [
          TextButton(
            child: const Text('Keep Searching'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: RaftarColors.error),
            child: const Text('Cancel Search', style: TextStyle(color: Colors.white)),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final repo = ref.read(bookingRepositoryProvider);
    final result = await repo.cancelBooking(
      widget.bookingId,
      reason: 'Cancelled by customer',
    );

    if (!mounted) return;

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure.message),
            backgroundColor: RaftarColors.error,
          ),
        );
      },
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Delivery request cancelled.'),
            backgroundColor: RaftarColors.navy,
          ),
        );
        setState(() {
          if (_trackingData != null) {
            _trackingData = {
              ..._trackingData!,
              'status': 'CANCELLED',
              'cancellationReason': 'Cancelled by customer',
            };
          }
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _trackingData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Live Trip Tracking')),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: RaftarSpacing.md),
              Text('Locating your driver...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null && _trackingData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Live Trip Tracking')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(RaftarSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_off_rounded, size: 48, color: RaftarColors.textTertiary),
                const SizedBox(height: RaftarSpacing.md),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: RaftarColors.textSecondary),
                ),
                const SizedBox(height: RaftarSpacing.lg),
                ElevatedButton.icon(
                  onPressed: () => _fetchTracking(isInitial: true),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final bookingNumber = _trackingData?['bookingNumber'] ?? '#ORD';
    final status = _trackingData?['status'] as String? ?? 'REQUESTED';
    final isCompleted = status == 'TRIP_COMPLETED' || status == 'COMPLETED';

    // ─── STRICT MAP SUPPRESSION: Never render FlutterMap for completed rides ───
    if (isCompleted) {
      return Scaffold(
        backgroundColor: RaftarColors.surfaceMuted,
        appBar: AppBar(
          title: const Text('Delivery Summary'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(Routes.home);
              }
            },
          ),
        ),
        body: _CompletedDeliverySummaryView(
          bookingId: widget.bookingId,
          trackingData: _trackingData!,
        ),
      );
    }

    final isCancelled = status == 'CANCELLED';
    if (isCancelled) {
      return Scaffold(
        backgroundColor: RaftarColors.surfaceMuted,
        appBar: AppBar(
          title: const Text('Search Ended'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(Routes.home);
              }
            },
          ),
        ),
        body: _CancelledDeliverySummaryView(
          bookingId: widget.bookingId,
          trackingData: _trackingData!,
        ),
      );
    }

    final pickup = _trackingData?['pickup'] as Map<String, dynamic>?;
    final drop = _trackingData?['drop'] as Map<String, dynamic>?;
    final driver = _trackingData?['driver'] as Map<String, dynamic>?;
    final vehicle = driver?['vehicle'] as Map<String, dynamic>?;
    final liveLocation = _trackingData?['liveLocation'] as Map<String, dynamic>?;

    final pickupLat = (pickup?['lat'] as num?)?.toDouble() ?? 28.6315;
    final pickupLng = (pickup?['lng'] as num?)?.toDouble() ?? 77.2167;
    final dropLat = (drop?['lat'] as num?)?.toDouble() ?? 28.5700;
    final dropLng = (drop?['lng'] as num?)?.toDouble() ?? 77.3200;

    final driverLat = (liveLocation?['latitude'] as num?)?.toDouble();
    final driverLng = (liveLocation?['longitude'] as num?)?.toDouble();

    final pickupPoint = LatLng(pickupLat, pickupLng);
    final dropPoint = LatLng(dropLat, dropLng);
    final driverPoint = driverLat != null && driverLng != null ? LatLng(driverLat, driverLng) : null;

    final is2Wheeler = (vehicle?['type'] as String?)?.contains('2-Wheeler') ?? true;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Fullscreen Interactive Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: driverPoint ?? pickupPoint,
              initialZoom: 13.5,
              minZoom: 5.0,
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.raftargaddi.customer',
              ),
              // Route Polyline
              if (driverPoint != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [pickupPoint, driverPoint, dropPoint],
                      strokeWidth: 4.0,
                      color: RaftarColors.primary,
                      borderStrokeWidth: 2.0,
                      borderColor: Colors.white,
                    ),
                  ],
                ),
              // Map Markers
              MarkerLayer(
                markers: [
                  // Pickup Marker
                  Marker(
                    point: pickupPoint,
                    width: 44,
                    height: 44,
                    child: _buildLocationPin(
                      icon: Icons.storefront_rounded,
                      color: RaftarColors.success,
                      label: 'Pickup',
                    ),
                  ),
                  // Drop Marker
                  Marker(
                    point: dropPoint,
                    width: 44,
                    height: 44,
                    child: _buildLocationPin(
                      icon: Icons.flag_rounded,
                      color: RaftarColors.error,
                      label: 'Drop',
                    ),
                  ),
                  // Driver Live Marker
                  if (driverPoint != null)
                    Marker(
                      point: driverPoint,
                      width: 52,
                      height: 52,
                      child: _buildDriverMarker(is2Wheeler: is2Wheeler),
                    ),
                ],
              ),
            ],
          ),

          // 2. Top Header with Back button & Status
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: RaftarSpacing.md, vertical: RaftarSpacing.sm),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: RaftarColors.navy),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: RaftarSpacing.sm),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: RaftarSpacing.md, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: RaftarColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Order $bookingNumber',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: RaftarColors.navy),
                                ),
                                Text(
                                  _getStatusLabel(status),
                                  style: const TextStyle(fontSize: 11, color: RaftarColors.textSecondary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.headset_mic_rounded, color: RaftarColors.primary, size: 22),
                            tooltip: 'Live Support Chat',
                            onPressed: () => context.push('${Routes.supportChat}?bookingId=${widget.bookingId}'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Recenter GPS Button
          Positioned(
            right: RaftarSpacing.md,
            bottom: 310 + MediaQuery.of(context).padding.bottom,
            child: FloatingActionButton.small(
              backgroundColor: Colors.white,
              foregroundColor: RaftarColors.primary,
              onPressed: _recenterMap,
              tooltip: 'Recenter on Driver',
              child: const Icon(Icons.my_location_rounded),
            ),
          ),

          // 4. Floating Bottom Delivery Sheet
          Positioned(
            left: RaftarSpacing.md,
            right: RaftarSpacing.md,
            bottom: RaftarSpacing.lg + MediaQuery.of(context).padding.bottom,
            child: _buildBottomDeliverySheet(
              status: status,
              driver: driver,
              vehicle: vehicle,
              pickupAddress: pickup?['address'] ?? 'Pickup Address',
              dropAddress: drop?['address'] ?? 'Drop Address',
              fare: _trackingData?['finalFare'] ?? _trackingData?['estimatedFare'] ?? 180,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationPin({
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildDriverMarker({required bool is2Wheeler}) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: RaftarColors.primary.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: RaftarColors.primary,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: RaftarColors.primary.withValues(alpha: 0.5),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            is2Wheeler ? Icons.two_wheeler_rounded : Icons.local_shipping_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomDeliverySheet({
    required String status,
    required Map<String, dynamic>? driver,
    required Map<String, dynamic>? vehicle,
    required String pickupAddress,
    required String dropAddress,
    required dynamic fare,
  }) {
    final driverName = driver?['name'] ?? 'Driver Assigned';
    final driverPhone = driver?['phone'] ?? '+91 99999 99999';
    final regNo = vehicle?['registrationNumber'] ?? 'DL12AD2026';
    final model = vehicle?['model'] ?? '2-Wheeler';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(RaftarSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Milestone Status Progress Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: RaftarColors.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.near_me_rounded, size: 16, color: RaftarColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getStatusHeadline(status),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: RaftarColors.primary,
                    ),
                  ),
                ),
                Text(
                  '₹$fare',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: RaftarColors.success,
                  ),
                ),
              ],
            ),
          ),
          if (status == 'DRIVER_ARRIVING' || status == 'DRIVER_ARRIVED') ...[
            const SizedBox(height: RaftarSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFB300), width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.security_rounded, color: Color(0xFFE65100), size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Start Trip Verification OTP',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE65100),
                          ),
                        ),
                        const Text(
                          'Share this 4-digit code with your driver:',
                          style: TextStyle(fontSize: 10, color: RaftarColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE65100),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_trackingData?['startOtp'] ?? '1234'}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: RaftarSpacing.md),

          // Driver & Vehicle Details
          if (driver != null)
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: RaftarColors.navy,
                  child: const Icon(Icons.person, color: Colors.white, size: 22),
                ),
                const SizedBox(width: RaftarSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            driverName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: RaftarColors.navy),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.star_rate_rounded, size: 14, color: Color(0xFFF57F17)),
                          const Text('5.0', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Text(
                        '$regNo • $model',
                        style: const TextStyle(fontSize: 12, color: RaftarColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: const Color(0xFFE8F5E9)),
                  icon: const Icon(Icons.phone, color: RaftarColors.success),
                  tooltip: 'Call Driver',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Calling driver: $driverPhone')),
                    );
                  },
                ),
              ],
            )
          else
            Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(RaftarColors.primary),
                  ),
                ),
                const SizedBox(width: RaftarSpacing.sm),
                const Expanded(
                  child: Text(
                    'Assigning nearest available delivery partner...',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: RaftarColors.primary,
                    ),
                  ),
                ),
              ],
            ),

          const Divider(height: RaftarSpacing.lg),

          // Addresses
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.circle, size: 10, color: RaftarColors.success),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pickupAddress,
                  style: const TextStyle(fontSize: 11, color: RaftarColors.navy),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, size: 12, color: RaftarColors.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dropAddress,
                  style: const TextStyle(fontSize: 11, color: RaftarColors.navy),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          if (status == 'REQUESTED' || status == 'SEARCHING_DRIVER') ...[
            const SizedBox(height: RaftarSpacing.md),
            OutlinedButton.icon(
              icon: const Icon(Icons.close_rounded, size: 16, color: RaftarColors.error),
              label: const Text(
                'Cancel Search',
                style: TextStyle(
                  color: RaftarColors.error,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: RaftarColors.error, width: 1.2),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _cancelSearch,
            ),
          ],
        ],
      ),
    );
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'DRIVER_ASSIGNED':
      case 'DRIVER_ARRIVING':
        return 'Driver is heading to pickup';
      case 'DRIVER_ARRIVED':
        return 'Driver reached pickup';
      case 'TRIP_STARTED':
        return 'In transit to drop location';
      case 'TRIP_COMPLETED':
        return 'Delivery completed';
      default:
        return 'Searching for driver nearby';
    }
  }

  String _getStatusHeadline(String status) {
    switch (status) {
      case 'DRIVER_ASSIGNED':
      case 'DRIVER_ARRIVING':
        return 'Driver is on the way to pickup';
      case 'DRIVER_ARRIVED':
        return 'Driver has arrived at pickup location';
      case 'TRIP_STARTED':
        return 'Parcel in transit to destination';
      case 'TRIP_COMPLETED':
        return 'Delivered successfully!';
      default:
        return 'Matching nearby delivery partner...';
    }
  }
}

class _CompletedDeliverySummaryView extends ConsumerStatefulWidget {
  const _CompletedDeliverySummaryView({
    required this.bookingId,
    required this.trackingData,
  });

  final String bookingId;
  final Map<String, dynamic> trackingData;

  @override
  ConsumerState<_CompletedDeliverySummaryView> createState() =>
      _CompletedDeliverySummaryViewState();
}

class _CompletedDeliverySummaryViewState
    extends ConsumerState<_CompletedDeliverySummaryView> {
  int _selectedRating = 0;
  bool _isSubmittingRating = false;
  bool _hasRated = false;

  @override
  void initState() {
    super.initState();
    _checkExistingRating();
  }

  Future<void> _checkExistingRating() async {
    final result = await ref
        .read(bookingRepositoryProvider)
        .getBookingRating(widget.bookingId);
    result.match(
      (_) {},
      (data) {
        if (data != null && data['rating'] != null && mounted) {
          setState(() {
            _hasRated = true;
            _selectedRating = (data['rating'] as num).toInt();
          });
        }
      },
    );
  }

  Future<void> _submitRating(int rating) async {
    if (_hasRated || _isSubmittingRating) return;
    setState(() {
      _selectedRating = rating;
      _isSubmittingRating = true;
    });

    final result = await ref.read(bookingRepositoryProvider).rateBooking(
          bookingId: widget.bookingId,
          rating: rating,
        );

    if (!mounted) return;
    setState(() => _isSubmittingRating = false);

    result.match(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure.message),
            backgroundColor: RaftarColors.error,
          ),
        );
      },
      (_) {
        setState(() => _hasRated = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for rating your delivery partner!'),
            backgroundColor: RaftarColors.success,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookingNumber = widget.trackingData['bookingNumber'] ?? '#ORD';
    final pickup = widget.trackingData['pickup'] as Map<String, dynamic>?;
    final drop = widget.trackingData['drop'] as Map<String, dynamic>?;
    final driver = widget.trackingData['driver'] as Map<String, dynamic>?;
    final vehicle = driver?['vehicle'] as Map<String, dynamic>?;
    final fare = widget.trackingData['finalFare'] ??
        widget.trackingData['estimatedFare'] ??
        180;
    final pkgType = widget.trackingData['packageType'] ?? 'Commercial Goods';
    final weight = widget.trackingData['packageWeightKg'];
    final vehicleType = vehicle?['type'] ?? 'Cargo Vehicle';
    final regNo = vehicle?['registrationNumber'] ?? 'DL12AD2026';
    final driverName = driver?['name'] ?? 'Raftar Partner';

    final pickupAddress = pickup?['address'] ?? 'Pickup Location';
    final dropAddress = drop?['address'] ?? 'Delivery Destination';

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(RaftarSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Success Hero Banner
            Container(
              padding: const EdgeInsets.symmetric(
                vertical: RaftarSpacing.xl,
                horizontal: RaftarSpacing.md,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: RaftarColors.success.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: RaftarColors.success,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: RaftarSpacing.md),
                  const Text(
                    'Delivered Successfully! 🎉',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: RaftarColors.navy,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Your parcel has reached its destination safely',
                    style: TextStyle(
                      fontSize: 12,
                      color: RaftarColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: RaftarSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: RaftarColors.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Order $bookingNumber • COMPLETED',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: RaftarColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: RaftarSpacing.md),

            // 2. Route & Address Summary Card
            Container(
              padding: const EdgeInsets.all(RaftarSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Route Summary',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: RaftarColors.navy,
                    ),
                  ),
                  const SizedBox(height: RaftarSpacing.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.circle,
                        size: 14,
                        color: RaftarColors.success,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PICKUP',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: RaftarColors.textSecondary,
                              ),
                            ),
                            Text(
                              pickupAddress,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: RaftarColors.navy,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Container(
                      width: 2,
                      height: 24,
                      color: RaftarColors.border,
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 16,
                        color: RaftarColors.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'DROP',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: RaftarColors.textSecondary,
                              ),
                            ),
                            Text(
                              dropAddress,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: RaftarColors.navy,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: RaftarSpacing.md),

            // 3. Package & Vehicle Info Card
            Container(
              padding: const EdgeInsets.all(RaftarSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Goods Category',
                          style: TextStyle(
                            fontSize: 10,
                            color: RaftarColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          pkgType,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: RaftarColors.navy,
                          ),
                        ),
                        if (weight != null)
                          Text(
                            '$weight kg payload',
                            style: const TextStyle(
                              fontSize: 11,
                              color: RaftarColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 36,
                    color: RaftarColors.border,
                  ),
                  const SizedBox(width: RaftarSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Vehicle Type',
                          style: TextStyle(
                            fontSize: 10,
                            color: RaftarColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          vehicleType,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: RaftarColors.navy,
                          ),
                        ),
                        Text(
                          regNo,
                          style: const TextStyle(
                            fontSize: 11,
                            color: RaftarColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: RaftarSpacing.md),

            // 4. Fare & Payment Receipt Card
            Container(
              padding: const EdgeInsets.all(RaftarSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Payment Receipt',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: RaftarColors.navy,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 12,
                              color: RaftarColors.success,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'PAID',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: RaftarColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: RaftarSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Fare Paid',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: RaftarColors.navy,
                        ),
                      ),
                      Text(
                        '₹$fare',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: RaftarColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Inclusive of all tolls, service fees, and taxes',
                    style: TextStyle(
                      fontSize: 10,
                      color: RaftarColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: RaftarSpacing.md),

            // 5. Driver Details & Rating Card
            Container(
              padding: const EdgeInsets.all(RaftarSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: RaftarColors.navy,
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: RaftarSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              driverName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: RaftarColors.navy,
                              ),
                            ),
                            Text(
                              '$regNo • $vehicleType',
                              style: const TextStyle(
                                fontSize: 11,
                                color: RaftarColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: RaftarSpacing.lg),
                  Text(
                    _hasRated
                        ? 'You rated this delivery $_selectedRating/5 ⭐'
                        : 'Rate your delivery experience',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _hasRated
                          ? RaftarColors.success
                          : RaftarColors.navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_isSubmittingRating)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final starNumber = index + 1;
                        final isFilled = starNumber <= _selectedRating;
                        return IconButton(
                          iconSize: 32,
                          icon: Icon(
                            isFilled
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: isFilled
                                ? const Color(0xFFFFB300)
                                : Colors.grey.shade400,
                          ),
                          onPressed: _hasRated
                              ? null
                              : () => _submitRating(starNumber),
                        );
                      }),
                    ),
                ],
              ),
            ),
            const SizedBox(height: RaftarSpacing.lg),

            // 6. Primary Action: Book Another Delivery
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: RaftarColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              onPressed: () {
                context.go(Routes.home);
              },
              child: const Text(
                'Book Another Delivery',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: RaftarSpacing.sm),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: RaftarColors.primary,
                side: const BorderSide(color: RaftarColors.primary),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.support_agent_rounded, size: 20),
              label: const Text(
                'Need Help with this Order? Chat Support',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              onPressed: () {
                context.push('${Routes.supportChat}?bookingId=${widget.bookingId}');
              },
            ),
            const SizedBox(height: RaftarSpacing.md),
          ],
        ),
      ),
    );
  }
}

class _CancelledDeliverySummaryView extends StatelessWidget {
  const _CancelledDeliverySummaryView({
    required this.bookingId,
    required this.trackingData,
  });

  final String bookingId;
  final Map<String, dynamic> trackingData;

  @override
  Widget build(BuildContext context) {
    final bookingNumber = trackingData['bookingNumber'] ?? '#ORD';
    final reason = trackingData['cancellationReason'] ??
        trackingData['cancelReason'] ??
        'No delivery partner available in your pickup area. Please retry.';
    final pickup = trackingData['pickup'] as Map<String, dynamic>?;
    final drop = trackingData['drop'] as Map<String, dynamic>?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(RaftarSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(RaftarSpacing.xl),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: RaftarColors.error.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.timer_off_rounded,
                    color: RaftarColors.error,
                    size: 36,
                  ),
                ),
                const SizedBox(height: RaftarSpacing.md),
                const Text(
                  'Search Timed Out / Cancelled',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: RaftarColors.navy,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: RaftarSpacing.xs),
                Text(
                  'Order $bookingNumber',
                  style: const TextStyle(
                    fontSize: 13,
                    color: RaftarColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: RaftarSpacing.md),
                Container(
                  padding: const EdgeInsets.all(RaftarSpacing.md),
                  decoration: BoxDecoration(
                    color: RaftarColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: RaftarColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: RaftarColors.error, size: 20),
                      const SizedBox(width: RaftarSpacing.sm),
                      Expanded(
                        child: Text(
                          reason.toString(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: RaftarColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: RaftarSpacing.lg),
          // Route Details
          Container(
            padding: const EdgeInsets.all(RaftarSpacing.lg),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: RaftarColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Trip Route',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const Divider(height: RaftarSpacing.md),
                Row(
                  children: [
                    const Icon(Icons.circle, color: Colors.blue, size: 10),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pickup?['address'] ?? 'Pickup Location',
                        style: const TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.red, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        drop?['address'] ?? 'Drop Location',
                        style: const TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: RaftarSpacing.xl),
          // Action Buttons
          ElevatedButton.icon(
            icon: const Icon(Icons.replay_rounded),
            label: const Text('Book Another Delivery', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: RaftarColors.primary,
              foregroundColor: RaftarColors.navy,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => context.go(Routes.home),
          ),
          const SizedBox(height: RaftarSpacing.sm),
          OutlinedButton.icon(
            icon: const Icon(Icons.headset_mic_rounded, size: 18),
            label: const Text('Need Help? Live Support Chat'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => context.push('${Routes.supportChat}?bookingId=$bookingId'),
          ),
        ],
      ),
    );
  }
}
