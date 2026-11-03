import 'package:customer_app/app/router/routes.dart';
import 'package:customer_app/features/bookings/bookings_screen.dart';
import 'package:customer_app/session/session_controller.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:repositories/repositories.dart';
import 'package:shared_models/shared_models.dart';


/// Detailed Profile tab: complete customer profile hub with personal info editing,
/// account stats, saved places, safety tools, app preferences, support, and sign-out.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _pushNotifications = true;
  bool _smsAlerts = true;
  bool _shareLiveTrip = true;
  String _selectedLanguage = 'English';

  String _homeAddress = 'Sector 18, Noida, Uttar Pradesh';
  String _workAddress = 'Cyber City, Gurugram, Haryana';

  void _showEditProfileSheet(BuildContext context, AppUser user) {
    final nameCtrl = TextEditingController(text: user.fullName);
    final emailCtrl = TextEditingController(text: user.email ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: RaftarColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: RaftarSpacing.xl,
              right: RaftarSpacing.xl,
              top: RaftarSpacing.xl,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + RaftarSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Edit Profile',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: RaftarColors.navy,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: RaftarSpacing.sm),
                const Text(
                  'Update your personal information below.',
                  style: TextStyle(color: RaftarColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: RaftarSpacing.lg),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Full Name *',
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: RaftarSpacing.md),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    hintText: 'e.g. name@example.com',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: RaftarSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: RaftarColors.primary,
                      foregroundColor: RaftarColors.navy,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      final newName = nameCtrl.text.trim();
                      final newEmail = emailCtrl.text.trim();

                      if (newName.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Name cannot be empty.'),
                            backgroundColor: RaftarColors.error,
                          ),
                        );
                        return;
                      }

                      Navigator.of(ctx).pop();

                      // Update backend
                      final repo = ref.read(customerRepositoryProvider);
                      final result = await repo.updateProfile(
                        name: newName,
                        email: newEmail.isNotEmpty ? newEmail : null,
                      );

                      if (!mounted) return;

                      result.match(
                        (failure) {
                          // Fallback to local session update if offline
                          final updated = user.copyWith(
                            fullName: newName,
                            email: newEmail.isNotEmpty ? newEmail : user.email,
                          );
                          ref.read(sessionControllerProvider.notifier).updateUser(updated);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Profile updated locally.'),
                              backgroundColor: RaftarColors.primary,
                            ),
                          );
                        },
                        (updatedUser) {
                          ref.read(sessionControllerProvider.notifier).updateUser(updatedUser);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Profile updated successfully!'),
                              backgroundColor: RaftarColors.success,
                            ),
                          );
                        },
                      );
                    },
                    child: const Text(
                      'Save Changes',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddressDialog(String title, String currentVal, ValueChanged<String> onSave) {
    final ctrl = TextEditingController(text: currentVal);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit $title Address'),
        content: TextField(
          controller: ctrl,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'Enter complete address...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: RaftarColors.primary,
              foregroundColor: RaftarColors.navy,
            ),
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                onSave(ctrl.text.trim());
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(child: Text(content)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionControllerProvider).user;
    final bookingsAsync = ref.watch(bookingsProvider);
    final completedCount = bookingsAsync.maybeWhen(
      data: (list) => list.where((b) => b.status == BookingStatus.completed).length,
      orElse: () => 0,
    );

    final displayName = (user?.fullName.isNotEmpty ?? false) ? user!.fullName : 'Guest Customer';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'C';
    final phone = user?.phone ?? '+91 98765 43210';
    final email = (user?.email?.isNotEmpty ?? false) ? user!.email! : 'Add email address';

    return Scaffold(
      backgroundColor: RaftarColors.surfaceMuted,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: RaftarColors.surface,
        title: const Text(
          'My Profile',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          if (user != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Profile',
              onPressed: () => _showEditProfileSheet(context, user),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: RaftarSpacing.lg,
          vertical: RaftarSpacing.md,
        ),
        children: [
          // ── 1. Profile Header Card ──────────────────────────────
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(RaftarRadii.xl),
              side: const BorderSide(color: RaftarColors.border),
            ),
            color: RaftarColors.surface,
            child: Padding(
              padding: const EdgeInsets.all(RaftarSpacing.lg),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Avatar
                      Stack(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: RaftarColors.navy,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: RaftarColors.primary,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: RaftarColors.primary,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: RaftarSpacing.md),
                      // Name, Phone, Email
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    displayName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: RaftarColors.navy,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.green.shade300, width: 0.8),
                                  ),
                                  child: const Text(
                                    'VERIFIED',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              phone,
                              style: const TextStyle(
                                fontSize: 13,
                                color: RaftarColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              email,
                              style: TextStyle(
                                fontSize: 12,
                                color: (user?.email?.isNotEmpty ?? false)
                                    ? RaftarColors.textTertiary
                                    : RaftarColors.primary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: RaftarSpacing.md),
                  const Divider(height: 1, color: RaftarColors.border),
                  const SizedBox(height: RaftarSpacing.sm),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      if (user != null) _showEditProfileSheet(context, user);
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.edit_rounded, size: 15, color: RaftarColors.primary),
                          SizedBox(width: 6),
                          Text(
                            'Edit Personal Information',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: RaftarColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: RaftarSpacing.md),

          // ── 2. Account Quick Stats ──────────────────────────────
          Row(
            children: [
              Expanded(
                child: _QuickStatCard(
                  icon: Icons.local_shipping_rounded,
                  title: 'Trips Done',
                  value: '$completedCount',
                  color: RaftarColors.navy,
                ),
              ),
              const SizedBox(width: RaftarSpacing.sm),
              const Expanded(
                child: _QuickStatCard(
                  icon: Icons.star_rounded,
                  title: 'User Rating',
                  value: '4.9 ★',
                  color: Colors.amber,
                ),
              ),
              const SizedBox(width: RaftarSpacing.sm),
              const Expanded(
                child: _QuickStatCard(
                  icon: Icons.verified_user_rounded,
                  title: 'Status',
                  value: 'Active',
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: RaftarSpacing.lg),

          // ── 3. Saved Addresses / Places ─────────────────────────
          const _SectionHeader(title: 'Saved Places'),
          const SizedBox(height: RaftarSpacing.xs),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(RaftarRadii.xl),
              side: const BorderSide(color: RaftarColors.border),
            ),
            color: RaftarColors.surface,
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.home_rounded,
                  iconColor: Colors.blue,
                  title: 'Home Address',
                  subtitle: _homeAddress,
                  onTap: () => _showAddressDialog('Home', _homeAddress, (v) => setState(() => _homeAddress = v)),
                ),
                const Divider(height: 1, indent: 56, color: RaftarColors.border),
                _SettingsTile(
                  icon: Icons.work_rounded,
                  iconColor: Colors.deepOrange,
                  title: 'Work / Office',
                  subtitle: _workAddress,
                  onTap: () => _showAddressDialog('Work', _workAddress, (v) => setState(() => _workAddress = v)),
                ),
                const Divider(height: 1, indent: 56, color: RaftarColors.border),
                _SettingsTile(
                  icon: Icons.add_location_alt_rounded,
                  iconColor: RaftarColors.primary,
                  title: 'Add New Saved Place',
                  subtitle: 'Save frequent delivery and pickup points',
                  onTap: () => _showAddressDialog('New Place', '', (v) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Saved place added: $v'), backgroundColor: RaftarColors.success),
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: RaftarSpacing.lg),

          // ── 4. Safety & Emergency Toolkit ───────────────────────
          const _SectionHeader(title: 'Safety & Emergency Toolkit'),
          const SizedBox(height: RaftarSpacing.xs),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(RaftarRadii.xl),
              side: const BorderSide(color: RaftarColors.border),
            ),
            color: RaftarColors.surface,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.share_location_rounded, color: Colors.green, size: 20),
                  ),
                  title: const Text('Share Live Ride Status', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Auto-share live tracking link with emergency contacts', style: TextStyle(fontSize: 12)),
                  value: _shareLiveTrip,
                  activeThumbColor: RaftarColors.success,
                  onChanged: (v) => setState(() => _shareLiveTrip = v),
                ),
                const Divider(height: 1, indent: 56, color: RaftarColors.border),
                _SettingsTile(
                  icon: Icons.emergency_rounded,
                  iconColor: Colors.red,
                  title: 'Emergency Contacts (SOS)',
                  subtitle: 'Configure contacts alerted in emergencies',
                  onTap: () => _showInfoDialog(
                    'Emergency SOS',
                    'In case of emergency, you can trigger an instant SOS alert during any active ride. Raftar Gaddi will immediately dispatch your GPS coordinates to our 24/7 emergency response team and your designated family contacts.',
                  ),
                ),
                const Divider(height: 1, indent: 56, color: RaftarColors.border),
                _SettingsTile(
                  icon: Icons.phone_in_talk_rounded,
                  iconColor: Colors.redAccent,
                  title: '24x7 Safety Helpline',
                  subtitle: 'Toll-free emergency line: 1800-123-7238',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Dialing Safety Helpline 1800-123-7238...')),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: RaftarSpacing.lg),

          // ── 5. App Preferences & Settings ───────────────────────
          const _SectionHeader(title: 'App Preferences'),
          const SizedBox(height: RaftarSpacing.xs),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(RaftarRadii.xl),
              side: const BorderSide(color: RaftarColors.border),
            ),
            color: RaftarColors.surface,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.notifications_active_rounded, color: Colors.amber, size: 20),
                  ),
                  title: const Text('Push Notifications', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Receive real-time driver arrival & ride updates', style: TextStyle(fontSize: 12)),
                  value: _pushNotifications,
                  activeThumbColor: RaftarColors.success,
                  onChanged: (v) => setState(() => _pushNotifications = v),
                ),
                const Divider(height: 1, indent: 56, color: RaftarColors.border),
                SwitchListTile(
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.sms_rounded, color: Colors.purple, size: 20),
                  ),
                  title: const Text('SMS Delivery Alerts', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Get OTP and delivery milestones over SMS', style: TextStyle(fontSize: 12)),
                  value: _smsAlerts,
                  activeThumbColor: RaftarColors.success,
                  onChanged: (v) => setState(() => _smsAlerts = v),
                ),
                const Divider(height: 1, indent: 56, color: RaftarColors.border),
                _SettingsTile(
                  icon: Icons.language_rounded,
                  iconColor: RaftarColors.navy,
                  title: 'App Language',
                  subtitle: 'Currently set to $_selectedLanguage',
                  trailing: DropdownButton<String>(
                    value: _selectedLanguage,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 'English', child: Text('English')),
                      DropdownMenuItem(value: 'हिन्दी', child: Text('हिन्दी')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedLanguage = v);
                    },
                  ),
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: RaftarSpacing.lg),

          // ── 6. Help, Support & Policies ─────────────────────────
          const _SectionHeader(title: 'Support & Policies'),
          const SizedBox(height: RaftarSpacing.xs),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(RaftarRadii.xl),
              side: const BorderSide(color: RaftarColors.border),
            ),
            color: RaftarColors.surface,
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.headset_mic_rounded,
                  iconColor: RaftarColors.primary,
                  title: '24x7 Customer Support',
                  subtitle: 'Chat live with our support executives',
                  onTap: () => context.push(Routes.supportChat),
                ),
                const Divider(height: 1, indent: 56, color: RaftarColors.border),
                _SettingsTile(
                  icon: Icons.chat_bubble_rounded,
                  iconColor: Colors.green,
                  title: 'Chat with us on WhatsApp',
                  subtitle: 'Instant assistance for orders & billing',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Opening WhatsApp support chat at +91 98765 43210...')),
                    );
                  },
                ),
                const Divider(height: 1, indent: 56, color: RaftarColors.border),
                _SettingsTile(
                  icon: Icons.quiz_rounded,
                  iconColor: Colors.teal,
                  title: 'FAQs & Booking Guidelines',
                  subtitle: 'Learn about fares, rules, luggage limits & policies',
                  onTap: () => context.push(Routes.faq),
                ),
                const Divider(height: 1, indent: 56, color: RaftarColors.border),
                _SettingsTile(
                  icon: Icons.description_outlined,
                  iconColor: RaftarColors.textSecondary,
                  title: 'Terms of Service',
                  onTap: () => _showInfoDialog(
                    'Terms of Service',
                    'By using Raftar Gaddi, you agree to comply with all transport and freight regulations. Full terms are available at https://raftargaddi.com/terms',
                  ),
                ),
                const Divider(height: 1, indent: 56, color: RaftarColors.border),
                _SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  iconColor: RaftarColors.textSecondary,
                  title: 'Privacy Policy',
                  onTap: () => _showInfoDialog(
                    'Privacy Policy',
                    'We value your privacy. GPS location is used exclusively during active bookings for dispatch and route tracking. Full privacy policy at https://raftargaddi.com/privacy',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: RaftarSpacing.xl),

          // ── 7. Sign Out Button ──────────────────────────────────
          RaftarButton(
            label: 'Sign Out',
            variant: RaftarButtonVariant.secondary,
            icon: Icons.logout_rounded,
            onPressed: () async {
              final confirmed = await RaftarFeedback.confirm(
                context,
                title: 'Sign out?',
                message: 'You will need to sign in with your phone OTP to access your trips.',
                confirmLabel: 'Sign out',
                destructive: true,
              );
              if (confirmed) {
                await ref.read(sessionControllerProvider.notifier).signOut();
              }
            },
          ),
          const SizedBox(height: RaftarSpacing.xl),

          // ── 8. App Brand & Version Footer ───────────────────────
          const Center(
            child: Column(
              children: [
                RaftarLogo(height: 36, onNavyPanel: true),
                SizedBox(height: RaftarSpacing.xs),
                Text(
                  'Raftar Gaddi • Har Load, Hamari Zimmedaari',
                  style: TextStyle(
                    color: RaftarColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'v1.0.0+1 • Made with ❤️ in India 🇮🇳',
                  style: TextStyle(
                    color: RaftarColors.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: RaftarSpacing.xxxl),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
          color: RaftarColors.textTertiary,
        ),
      ),
    );
  }
}

class _QuickStatCard extends StatelessWidget {
  const _QuickStatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RaftarRadii.lg),
        side: const BorderSide(color: RaftarColors.border),
      ),
      color: RaftarColors.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: RaftarColors.navy,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(
                fontSize: 10,
                color: RaftarColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? iconColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (iconColor ?? RaftarColors.navy).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor ?? RaftarColors.navy, size: 18),
            ),
            const SizedBox(width: RaftarSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: RaftarColors.navy,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: RaftarColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            trailing ?? const Icon(Icons.chevron_right_rounded, size: 20, color: RaftarColors.border),
          ],
        ),
      ),
    );
  }
}
