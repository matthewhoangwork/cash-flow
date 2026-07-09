import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/wallet.dart';
import '../providers/wallets_provider.dart';
import '../theme/app_theme.dart';

class ManageWalletsScreen extends ConsumerWidget {
  const ManageWalletsScreen({super.key});

  void _openForm(BuildContext context, {Wallet? wallet}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _WalletFormSheet(wallet: wallet),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Wallet wallet) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${wallet.name}"?'),
        content: const Text(
          'If this wallet has transactions, it will be archived so those '
          'transactions keep showing its name, but it will no longer be '
          'available for new transactions. Otherwise it is removed permanently.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await ref.read(walletsProvider.notifier).deleteWallet(wallet.id);
    if (!context.mounted) return;
    final message = switch (result) {
      DeleteWalletResult.deleted => 'Wallet deleted.',
      DeleteWalletResult.archived => 'Wallet archived — its transactions still show its name.',
      DeleteWalletResult.blockedIsDefault =>
        'Set another wallet as default before deleting this one.',
      DeleteWalletResult.blockedLastWallet => 'You need at least one wallet.',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallets = ref.watch(activeWalletsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage wallets')),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: wallets.length,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 20, endIndent: 20),
        itemBuilder: (context, index) {
          final wallet = wallets[index];
          return ListTile(
            onTap: () => ref.read(walletsProvider.notifier).setDefaultWallet(wallet.id),
            leading: Icon(
              wallet.isDefault ? Icons.radio_button_checked : Icons.radio_button_off,
              color: wallet.isDefault ? AppColors.ink : AppColors.muted,
            ),
            title: Text(wallet.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: wallet.isDefault ? const Text('Default') : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: AppColors.muted),
                  tooltip: 'Rename',
                  onPressed: () => _openForm(context, wallet: wallet),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.muted),
                  tooltip: 'Delete',
                  onPressed: () => _delete(context, ref, wallet),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(context),
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
      await notifier.updateWallet(widget.wallet!.id, name: _nameController.text.trim());
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
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Enter a name' : null,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _save,
              child: Text(_isEditing ? 'Save changes' : 'Add wallet'),
            ),
          ],
        ),
      ),
    );
  }
}
