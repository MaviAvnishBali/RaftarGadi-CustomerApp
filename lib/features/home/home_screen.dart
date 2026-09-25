import 'package:customer_app/app/router/routes.dart';
import 'package:customer_app/session/session_controller.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_models/shared_models.dart';

/// The customer home tab. Phase 4a wires the layout and the vehicle picker off
/// real `VehicleType` metadata; the booking flow it launches arrives in 4c.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionControllerProvider).user;
    final firstName = user?.fullName.split(' ').first ?? 'there';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, $firstName',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              'Where are we moving today?',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(RaftarSpacing.lg),
        children: [
          RaftarCard(
            onTap: () => context.push(Routes.bookingAddress),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, color: RaftarColors.primary),
                const SizedBox(width: RaftarSpacing.md),
                Expanded(
                  child: Text(
                    'Enter pickup & drop',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: RaftarColors.textTertiary,
                  size: 20,
                ),
              ],
            ),
          ),
          const SizedBox(height: RaftarSpacing.xxl),
          Text(
            'Choose a vehicle',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: RaftarSpacing.md),
          SizedBox(
            height: 178,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: VehicleType.values.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: RaftarSpacing.md),
              itemBuilder: (context, index) =>
                  _VehicleCard(type: VehicleType.values[index]),
            ),
          ),
          const SizedBox(height: RaftarSpacing.xxl),
          RaftarButton(
            label: 'Book now',
            icon: Icons.local_shipping_rounded,
            onPressed: () => context.push(Routes.bookingAddress),
          ),
        ],
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.type});

  final VehicleType type;

  static const _icons = {
    VehicleType.bike: Icons.two_wheeler_rounded,
    VehicleType.auto: Icons.electric_rickshaw_rounded,
    VehicleType.miniTruck: Icons.local_shipping_rounded,
    VehicleType.truck: Icons.fire_truck_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: RaftarCard(
        onTap: () {},
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(_icons[type], color: RaftarColors.primary, size: 32),
            const SizedBox(height: RaftarSpacing.sm),
            Text(type.label, style: Theme.of(context).textTheme.titleSmall),
            Text(
              'Up to ${type.capacityKg} kg',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'from ₹${type.baseFare.toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: RaftarColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
