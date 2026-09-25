import 'package:customer_app/session/session_controller.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Profile tab: the signed-in user's details and sign-out. Settings, saved
/// addresses, language, and dark mode land in a later customer sub-phase.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionControllerProvider).user;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(RaftarSpacing.lg),
        children: [
          RaftarCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: RaftarColors.primaryContainer,
                  child: Text(
                    (user?.fullName.isNotEmpty ?? false)
                        ? user!.fullName[0]
                        : '?',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: RaftarColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: RaftarSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.fullName ?? 'Guest',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        user?.phone ?? '',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: RaftarSpacing.xxl),
          RaftarButton(
            label: 'Sign out',
            variant: RaftarButtonVariant.secondary,
            icon: Icons.logout_rounded,
            onPressed: () async {
              final confirmed = await RaftarFeedback.confirm(
                context,
                title: 'Sign out?',
                message: 'You will need to sign in again to book a move.',
                confirmLabel: 'Sign out',
                destructive: true,
              );
              if (confirmed) {
                await ref.read(sessionControllerProvider.notifier).signOut();
              }
            },
          ),
        ],
      ),
    );
  }
}
