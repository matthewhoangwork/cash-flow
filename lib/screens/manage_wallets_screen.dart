import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/wallet.dart';
import '../providers/summary_providers.dart';
import '../providers/wallets_provider.dart';
import '../theme/app_theme.dart';
import '../utils/currency_format.dart';
import '../widgets/adaptive.dart';
import '../widgets/glass.dart';
import 'wallet_detail_screen.dart';

class ManageWalletsScreen extends ConsumerStatefulWidget {
  const ManageWalletsScreen({super.key});

  @override
  ConsumerState<ManageWalletsScreen> createState() => _ManageWalletsScreenState();
}

class _ManageWalletsScreenState extends ConsumerState<ManageWalletsScreen> {
  bool _selecting = false;
  final Set<String> _selectedIds = {};

  void _cancelSelection() {
    setState(() {
      _selecting = false;
      _selectedIds.clear();
    });
  }

  void _openForm({Wallet? wallet}) {
    showAdaptiveModalBottomSheet(
      context: context,
      builder: (_) => _WalletFormSheet(wallet: wallet),
    );
  }

  Future<void> _delete(Wallet wallet) async {
    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: Text('Delete "${wallet.name}"?'),
        content: const Text(
          'If this wallet has transactions, it will be archived so those '
          'transactions keep showing its name, but it will no longer be '
          'available for new transactions. Otherwise it is removed permanently.',
        ),
        actions: [
          adaptiveDialogAction(
            context: context,
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          adaptiveDialogAction(
            context: context,
            onPressed: () => Navigator.pop(context, true),
            isDestructive: true,
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await ref
        .read(walletsProvider.notifier)
        .deleteWallet(wallet.id);
    if (!mounted) return;
    final message = switch (result) {
      DeleteWalletResult.deleted => 'Wallet deleted.',
      DeleteWalletResult.archived =>
        'Wallet archived — its transactions still show its name.',
      DeleteWalletResult.blockedIsDefault =>
        'Set another wallet as default before deleting this one.',
      DeleteWalletResult.blockedLastWallet => 'You need at least one wallet.',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmBulkDelete() async {
    final count = _selectedIds.length;
    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: Text('Delete $count wallet${count == 1 ? '' : 's'}?'),
        content: const Text(
          'Wallets still holding transactions are archived instead of '
          'removed; the default wallet and your last remaining wallet are '
          'always kept.',
        ),
        actions: [
          adaptiveDialogAction(
            context: context,
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          adaptiveDialogAction(
            context: context,
            onPressed: () => Navigator.pop(context, true),
            isDestructive: true,
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final results = await ref
        .read(walletsProvider.notifier)
        .deleteWallets(_selectedIds);
    if (!mounted) return;
    _cancelSelection();

    final deleted = results.where((r) => r == DeleteWalletResult.deleted).length;
    final archived = results.where((r) => r == DeleteWalletResult.archived).length;
    final skipped = results.length - deleted - archived;
    final parts = [
      if (deleted > 0) '$deleted deleted',
      if (archived > 0) '$archived archived',
      if (skipped > 0) '$skipped skipped',
    ];
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(parts.join(', '))));
  }

  @override
  Widget build(BuildContext context) {
    final wallets = ref.watch(activeWalletsProvider);
    final isApple = isApplePlatform(context);

    return AdaptiveSliverScaffold(
      title: 'Wallets',
      largeTitle: false,
      actions: [
        SelectionToggleAction(
          selecting: _selecting,
          onPressed: () {
            if (_selecting) {
              _cancelSelection();
            } else {
              setState(() => _selecting = true);
            }
          },
        ),
      ],
      bottomBar: _selecting
          ? SelectionBar(
              count: _selectedIds.length,
              onCancel: _cancelSelection,
              onDelete: _selectedIds.isEmpty ? null : _confirmBulkDelete,
            )
          : null,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.only(top: 8, bottom: 96),
          sliver: SliverList.separated(
            itemCount: wallets.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, indent: 20, endIndent: 20),
            itemBuilder: (context, index) {
              final wallet = wallets[index];
              final balance = ref.watch(walletBalanceProvider(wallet.id));
              final planned = ref.watch(walletPlannedOutstandingProvider(wallet.id));
              final selected = _selectedIds.contains(wallet.id);
              return ListTile(
                onTap: _selecting
                    ? () => setState(() {
                        if (!_selectedIds.remove(wallet.id)) {
                          _selectedIds.add(wallet.id);
                        }
                      })
                    : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => WalletDetailScreen(walletId: wallet.id),
                        ),
                      ),
                leading: _selecting
                    ? Icon(
                        selected
                            ? (isApple
                                  ? CupertinoIcons.checkmark_circle_fill
                                  : Icons.check_circle)
                            : (isApple
                                  ? CupertinoIcons.circle
                                  : Icons.radio_button_unchecked),
                        color: selected ? AppColors.ink : AppColors.muted,
                      )
                    : Icon(
                        wallet.isDefault
                            ? (isApple
                                  ? CupertinoIcons.creditcard_fill
                                  : Icons.account_balance_wallet)
                            : (isApple
                                  ? CupertinoIcons.creditcard
                                  : Icons.account_balance_wallet_outlined),
                        color: wallet.isDefault ? AppColors.ink : AppColors.muted,
                      ),
                title: Text(
                  wallet.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: wallet.isDefault ? const Text('Default') : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          compactVnd(balance),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (planned != 0)
                          Text(
                            'planned ${compactVnd(planned)}',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                    if (!_selecting) ...[
                      const SizedBox(width: 4),
                      AdaptiveMenuButton(
                        tooltip: 'Wallet actions',
                        items: [
                          if (!wallet.isDefault)
                            AdaptiveMenuItem(
                              label: 'Set as default',
                              onSelected: () => ref
                                  .read(walletsProvider.notifier)
                                  .setDefaultWallet(wallet.id),
                            ),
                          AdaptiveMenuItem(
                            label: 'Rename',
                            onSelected: () => _openForm(wallet: wallet),
                          ),
                          AdaptiveMenuItem(
                            label: 'Delete',
                            isDestructive: true,
                            onSelected: () => _delete(wallet),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _WalletFormSheet extends ConsumerStatefulWidget {
  const _WalletFormSheet({this.wallet});

  final Wallet? wallet;

  @override
  ConsumerState<_WalletFormSheet> createState() => _WalletFormSheetState();
}

class _WalletFormSheetState extends ConsumerState<_WalletFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;

  bool get _isEditing => widget.wallet != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.wallet?.name ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(walletsProvider.notifier);
    if (_isEditing) {
      await notifier.updateWallet(
        widget.wallet!.id,
        name: _nameController.text.trim(),
      );
    } else {
      await notifier.addWallet(_nameController.text.trim());
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditing ? 'Rename wallet' : 'New wallet',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              textCapitalization: TextCapitalization.words,
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Enter a name'
                  : null,
            ),
            const SizedBox(height: 24),
            AdaptivePrimaryButton(
              onPressed: _save,
              child: Text(_isEditing ? 'Save changes' : 'Add wallet'),
            ),
          ],
        ),
      ),
    );
  }
}
