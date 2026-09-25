import 'package:customer_app/app/router/routes.dart';
import 'package:customer_app/features/booking/booking_draft_controller.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:repositories/repositories.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// The customer's saved addresses, used to pick pickup and drop.
final savedAddressesProvider = FutureProvider.autoDispose<List<Address>>((
  ref,
) async {
  final result = await ref.watch(addressRepositoryProvider).getSavedAddresses();
  return result.fold((failure) => throw failure, (page) => page.items);
});

/// Booking step 1: choose pickup and drop from saved addresses.
class AddressSelectScreen extends ConsumerWidget {
  const AddressSelectScreen({super.key});

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    List<Address> addresses, {
    required bool isPickup,
  }) async {
    final chosen = await RaftarFeedback.showSheet<Address>(
      context,
      title: isPickup ? 'Select pickup' : 'Select drop',
      child: Column(
        children: [
          for (final address in addresses)
            ListTile(
              leading: Icon(
                isPickup
                    ? Icons.trip_origin_rounded
                    : Icons.location_on_rounded,
                color: RaftarColors.primary,
              ),
              title: Text(address.title),
              subtitle: Text(address.formattedAddress),
              onTap: () => Navigator.of(context).pop(address),
            ),
        ],
      ),
    );
    if (chosen == null) return;
    final controller = ref.read(bookingDraftControllerProvider.notifier);
    isPickup ? controller.setPickup(chosen) : controller.setDrop(chosen);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              label: 'Pickup',
              value: draft.pickup?.title,
              onTap: () => _pick(context, ref, addresses, isPickup: true),
            ),
            const SizedBox(height: RaftarSpacing.md),
            _AddressField(
              icon: Icons.location_on_rounded,
              label: 'Drop',
              value: draft.drop?.title,
              onTap: () => _pick(context, ref, addresses, isPickup: false),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(RaftarSpacing.lg),
        child: RaftarButton(
          label: 'Continue',
          onPressed: draft.hasRoute
              ? () => context.push(Routes.bookingVehicle)
              : null,
        ),
      ),
    );
  }
}

class _AddressField extends StatelessWidget {
  const _AddressField({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RaftarCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: RaftarColors.primary),
          const SizedBox(width: RaftarSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                Text(
                  value ?? 'Select ${label.toLowerCase()}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: value == null
                        ? RaftarColors.textTertiary
                        : RaftarColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: RaftarColors.textTertiary,
          ),
        ],
      ),
    );
  }
}
