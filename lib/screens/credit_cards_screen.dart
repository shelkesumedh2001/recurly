import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/credit_card.dart';
import '../models/exchange_rate.dart';
import '../providers/credit_card_providers.dart';
import '../providers/currency_providers.dart';
import '../widgets/app_toast.dart';

/// Manage tracked credit cards: statement cutoff day, payment due day,
/// and which subscriptions land on the current statement.
class CreditCardsScreen extends ConsumerWidget {
  const CreditCardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(creditCardsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Credit Cards')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCardSheet(context, ref),
        icon: const Icon(Icons.add_card),
        label: const Text('Add card'),
      ),
      body: cards.isEmpty
          ? _buildEmptyState(context)
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: cards.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _CardTile(card: cards[index]),
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.credit_card_outlined,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No cards yet',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Add a credit card with its statement cutoff and payment due '
              'days, then assign subscriptions to it to see what lands on '
              'each statement.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardTile extends ConsumerWidget {
  const _CardTile({required this.card});

  final CreditCardInfo card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d');
    final statementSubs = ref.watch(cardStatementSubsProvider(card.id));
    final statementTotal = ref.watch(cardStatementTotalProvider(card.id));
    final displayCurrency = ref.watch(displayCurrencyProvider);
    final symbol =
        CurrencyInfo.getByCode(displayCurrency)?.symbol ?? displayCurrency;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showCardSheet(context, ref, card: card),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.credit_card, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      card.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete card',
                    onPressed: () => _confirmDelete(context, ref),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Next payment due ${dateFormat.format(card.nextDueDate)}'
                ' • Statement closes ${dateFormat.format(card.nextCutoffDate)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                statementSubs.isEmpty
                    ? 'No renewals on this statement'
                    : '${statementSubs.length} '
                        '${statementSubs.length == 1 ? 'renewal' : 'renewals'}'
                        ' this statement · '
                        '$symbol${statementTotal.toStringAsFixed(2)}'
                        ' — due ${dateFormat.format(card.currentStatementDueDate)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${card.name}?'),
        content: const Text(
          'Subscriptions assigned to this card will keep working — they '
          'just lose the card assignment.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(creditCardsProvider.notifier).deleteCard(card.id);
    showAppToast('${card.name} deleted');
  }
}

/// Add/edit bottom sheet. Pass [card] to edit.
Future<void> _showCardSheet(
  BuildContext context,
  WidgetRef ref, {
  CreditCardInfo? card,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _CardFormSheet(card: card),
    ),
  );
}

class _CardFormSheet extends ConsumerStatefulWidget {
  const _CardFormSheet({this.card});

  final CreditCardInfo? card;

  @override
  ConsumerState<_CardFormSheet> createState() => _CardFormSheetState();
}

class _CardFormSheetState extends ConsumerState<_CardFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late int _cutoffDay;
  late int _dueDay;

  bool get _isEditing => widget.card != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.card?.name ?? '');
    _cutoffDay = widget.card?.cutoffDay ?? 15;
    _dueDay = widget.card?.dueDay ?? 5;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final notifier = ref.read(creditCardsProvider.notifier);
    final name = _nameController.text.trim();

    if (_isEditing) {
      await notifier.updateCard(
        widget.card!.copyWith(
          name: name,
          cutoffDay: _cutoffDay,
          dueDay: _dueDay,
        ),
      );
    } else {
      await notifier.addCard(
        name: name,
        cutoffDay: _cutoffDay,
        dueDay: _dueDay,
      );
    }
    if (mounted) Navigator.pop(context);
    showAppToast(_isEditing ? 'Card updated' : '$name added');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditing ? 'Edit card' : 'Add card',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Card name',
                hintText: 'e.g. HDFC Regalia',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter a card name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _DayDropdown(
                    label: 'Statement day',
                    value: _cutoffDay,
                    onChanged: (v) => setState(() => _cutoffDay = v),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _DayDropdown(
                    label: 'Due day',
                    value: _dueDay,
                    onChanged: (v) => setState(() => _dueDay = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Statement day is when the statement closes; due day is when '
              'the payment is due. Days past a month\'s end (e.g. 31) roll '
              'back to its last day.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: Text(_isEditing ? 'Save' : 'Add card'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayDropdown extends StatelessWidget {
  const _DayDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (var day = 1; day <= 31; day++)
          DropdownMenuItem(value: day, child: Text('$day')),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
