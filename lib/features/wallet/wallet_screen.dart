import 'package:customer_app/session/session_controller.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repositories/repositories.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Loads the wallet through `WalletRepository` (mock-backed). Throws the
/// `Failure` on the sad path so `AsyncValueView` renders the error state.
final walletProvider = FutureProvider.autoDispose<Wallet>((ref) async {
  final ownerId = ref.watch(sessionControllerProvider).user?.id ?? 'usr_1';
  final result = await ref.watch(walletRepositoryProvider).getWallet(ownerId);
  return result.fold((failure) => throw failure, (wallet) => wallet);
});

/// Wallet tab: balance card + transaction ledger, proving the data layer
/// end-to-end (repository → fake API → model → UI) on-device.
class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: AsyncValueView<Wallet>(
        value: ref.watch(walletProvider),
        onRetry: () => ref.invalidate(walletProvider),
        data: (wallet) => ListView(
          padding: const EdgeInsets.all(RaftarSpacing.lg),
          children: [
            _BalanceCard(wallet: wallet),
            const SizedBox(height: RaftarSpacing.xxl),
            Text(
              'Recent activity',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: RaftarSpacing.md),
            if (wallet.transactions.isEmpty)
              const RaftarEmptyView(
                title: 'No transactions yet',
                icon: Icons.receipt_long_rounded,
              )
            else
              for (final txn in wallet.transactions) _TransactionTile(txn: txn),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.wallet});

  final Wallet wallet;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(RaftarSpacing.xl),
      decoration: BoxDecoration(
        color: RaftarColors.navy,
        borderRadius: BorderRadius.circular(RaftarRadii.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available balance',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: RaftarColors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: RaftarSpacing.sm),
          Text(
            '₹${wallet.balance.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              color: RaftarColors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.txn});

  final WalletTransaction txn;

  @override
  Widget build(BuildContext context) {
    final isCredit =
        txn.type == WalletTransactionType.credit ||
        txn.type == WalletTransactionType.refund ||
        txn.type == WalletTransactionType.cashback;
    final sign = isCredit ? '+' : '-';
    final color = isCredit ? RaftarColors.success : RaftarColors.textPrimary;

    return Padding(
      padding: const EdgeInsets.only(bottom: RaftarSpacing.md),
      child: RaftarCard(
        elevated: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    txn.description,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    '${txn.timestamp.day}/${txn.timestamp.month}/'
                    '${txn.timestamp.year}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Text(
              '$sign₹${txn.amount.toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
