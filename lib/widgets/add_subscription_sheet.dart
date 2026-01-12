import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/enums.dart';
import '../models/subscription.dart';
import '../models/subscription_template.dart';
import '../providers/subscription_providers.dart';
import '../providers/template_providers.dart';
import '../utils/constants.dart';

class AddSubscriptionSheet extends ConsumerStatefulWidget { // Null for add, populated for edit

  const AddSubscriptionSheet({
    super.key,
    this.subscription,
  });
  final Subscription? subscription;

  @override
  ConsumerState<AddSubscriptionSheet> createState() => _AddSubscriptionSheetState();
}

class _AddSubscriptionSheetState extends ConsumerState<AddSubscriptionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();

  BillingCycle _selectedBillingCycle = BillingCycle.monthly;
  SubscriptionCategory _selectedCategory = SubscriptionCategory.entertainment;
  DateTime _firstBillDate = DateTime.now();
  bool _isLoading = false;
  bool _showTemplates = true;
  String? _logoUrl;
  String? _templateColor;

  bool get _isEditMode => widget.subscription != null;

  @override
  void initState() {
    super.initState();
    // Populate form if editing
    if (_isEditMode) {
      final sub = widget.subscription!;
      _nameController.text = sub.name;
      _priceController.text = sub.price.toString();
      _selectedBillingCycle = sub.billingCycle;
      _selectedCategory = sub.category;
      _firstBillDate = sub.firstBillDate;
      _logoUrl = sub.logoUrl;
      _templateColor = sub.color;
      _showTemplates = false; // Don't show templates when editing
    }
  }


  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);

    // Listen to selected template (only when adding new)
    if (!_isEditMode) {
      ref.listen<SubscriptionTemplate?>(selectedTemplateProvider, (previous, next) {
        if (next != null) {
          setState(() {
            _nameController.text = next.name;
            _selectedCategory = next.category;
            _selectedBillingCycle = next.defaultBillingCycle;
            // Don't pre-fill price - let user enter their plan price
            _priceController.clear();
            _logoUrl = next.logoUrl;
            _templateColor = next.color;
            _showTemplates = false;
          });
        }
      });
    }

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: mediaQuery.viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  Text(
                    _isEditMode ? 'Edit Subscription' : 'Add Subscription',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Template Picker Section (only show when adding new)
                  if (!_isEditMode && _showTemplates) ...[
                    _buildTemplateSection(context, theme),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(child: Divider(color: theme.colorScheme.outline.withValues(alpha: 0.3))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Or create custom',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: theme.colorScheme.outline.withValues(alpha: 0.3))),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Toggle back to templates button
                  if (!_isEditMode && !_showTemplates) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _showTemplates = true;
                          _nameController.clear();
                          _priceController.clear();
                          _logoUrl = null;
                          _templateColor = null;
                          ref.read(selectedTemplateProvider.notifier).state = null;
                        });
                      },
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Choose from templates'),
                    ),
                    const SizedBox(height: 16),
                  ],

                // Service Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Service Name',
                    hintText: 'e.g., Netflix, Spotify',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  textCapitalization: TextCapitalization.words,
                  maxLength: 50,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a service name';
                    }
                    if (value.trim().length < 2) {
                      return 'Name must be at least 2 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppConstants.spacing16),

                // Price
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(
                    labelText: 'Price',
                    hintText: '0.00',
                    prefixIcon: Icon(Icons.attach_money),
                    prefixText: '\$',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a price';
                    }
                    final price = double.tryParse(value);
                    if (price == null) {
                      return 'Please enter a valid number';
                    }
                    if (price <= 0) {
                      return 'Price must be greater than 0';
                    }
                    if (price > 9999.99) {
                      return 'Price seems too high';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppConstants.spacing16),

                // Billing Cycle
                DropdownButtonFormField<BillingCycle>(
                  value: _selectedBillingCycle,
                  decoration: const InputDecoration(
                    labelText: 'Billing Cycle',
                    prefixIcon: Icon(Icons.sync),
                  ),
                  items: BillingCycle.values.map((cycle) {
                    return DropdownMenuItem(
                      value: cycle,
                      child: Text(cycle.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedBillingCycle = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: AppConstants.spacing16),

                // Category
                DropdownButtonFormField<SubscriptionCategory>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: SubscriptionCategory.values.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Row(
                        children: [
                          Text(category.icon),
                          const SizedBox(width: 8),
                          Text(category.displayName),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedCategory = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: AppConstants.spacing16),

                // First Bill Date
                InkWell(
                  onTap: () => _selectDate(context),
                  borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Start Date',
                      helperText: 'When did this subscription start?',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      DateFormat('MMM dd, yyyy').format(_firstBillDate),
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.spacing32),

                // Save Button
                FilledButton(
                  onPressed: _isLoading ? null : _saveSubscription,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppConstants.spacing16,
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('SAVE'),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Show date picker
  Future<void> _selectDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _firstBillDate.isAfter(now) ? now : _firstBillDate,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 30)),
      helpText: 'When did this subscription start?',
    );

    if (picked != null) {
      setState(() {
        _firstBillDate = picked;
      });
    }
  }

  /// Save subscription (create or update)
  Future<void> _saveSubscription() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final subscription = Subscription(
        id: _isEditMode ? widget.subscription!.id : const Uuid().v4(),
        name: _nameController.text.trim(),
        price: double.parse(_priceController.text.trim()),
        currency: 'USD',
        billingCycle: _selectedBillingCycle,
        firstBillDate: _firstBillDate,
        category: _selectedCategory,
        logoUrl: _logoUrl, // Add logo from template
        color: _templateColor, // Add color from template
        createdAt: _isEditMode ? widget.subscription!.createdAt : DateTime.now(),
      );

      if (_isEditMode) {
        await ref.read(subscriptionProvider.notifier).updateSubscription(subscription);
      } else {
        await ref.read(subscriptionProvider.notifier).addSubscription(subscription);
      }

      // Clear template selection
      ref.read(selectedTemplateProvider.notifier).state = null;

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditMode
                  ? '${subscription.name} updated successfully!'
                  : '${subscription.name} added successfully!',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Build template section with categories
  Widget _buildTemplateSection(BuildContext context, ThemeData theme) {
    final templates = ref.watch(allTemplatesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Popular Services',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),

        // Show templates by category
        ...templates.entries.map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
                child: Text(
                  '${entry.key.icon} ${entry.key.displayName}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: entry.value.length,
                  itemBuilder: (context, index) {
                    final template = entry.value[index];
                    return _buildTemplateChip(context, theme, template);
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          );
        }),
      ],
    );
  }

  /// Build individual template chip
  Widget _buildTemplateChip(BuildContext context, ThemeData theme, SubscriptionTemplate template) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: () {
          ref.read(selectedTemplateProvider.notifier).state = template;
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 70,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Image.asset(
                      template.logoUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.image_not_supported,
                          size: 24,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // Name
              Text(
                template.name,
                style: theme.textTheme.labelSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
