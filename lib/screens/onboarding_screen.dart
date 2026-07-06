import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/exchange_rate.dart';
import '../providers/currency_providers.dart';
import '../providers/preferences_providers.dart';
import '../providers/theme_providers.dart';
import '../services/theme_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/theme/theme_preview_card.dart';

/// First-run onboarding: let the user pick a theme before entering the app.
/// Shown only when `AppPreferences.onboardingComplete` is false (fresh
/// install); tapping a card applies the theme live so the screen previews
/// the choice. "Get Started" persists completion and the app boots straight
/// into the main navigation on every launch after.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final preferences = ref.watch(themePreferencesProvider);
    final allPresets = ref.watch(availablePresetsProvider);
    final currencyCode = ref.watch(displayCurrencyProvider);
    final currency = CurrencyInfo.getByCode(currencyCode);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome to Recurly',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Set up your currency and theme to get started — you can '
                'change both any time in Settings.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 20),
              _SectionLabel('Currency', theme: theme),
              const SizedBox(height: 8),
              _CurrencyTile(
                currency: currency,
                fallbackCode: currencyCode,
                onTap: () => _showCurrencyPicker(context, ref),
              ),
              const SizedBox(height: 20),
              _SectionLabel('Theme', theme: theme),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.only(bottom: 8),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.3,
                  ),
                  itemCount: allPresets.length,
                  itemBuilder: (context, index) {
                    final preset = allPresets[index];
                    final isSelected = preferences.themePresetId == preset.id;

                    return ThemePreviewCard(
                      preset: preset,
                      isSelected: isSelected,
                      onTap: () {
                        ref
                            .read(themePreferencesProvider.notifier)
                            .setThemePreset(preset.id);
                      },
                      customAccentColor: isSelected
                          ? ThemeService()
                              .parseHexColor(preferences.customAccentColorHex)
                          : null,
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                  ),
                  onPressed: () {
                    ref
                        .read(preferencesProvider.notifier)
                        .completeOnboarding();
                  },
                  child: const Text(
                    'Get Started',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Bottom-sheet currency picker, mirroring the Settings > Display currency
  /// list so onboarding and settings feel identical.
  void _showCurrencyPicker(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentCurrency = ref.read(displayCurrencyProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Select Display Currency',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: CurrencyInfo.all.length,
                    itemBuilder: (context, index) {
                      final currency = CurrencyInfo.all[index];
                      final isSelected = currency.code == currentCurrency;

                      return ListTile(
                        leading: Text(
                          currency.flag ?? '',
                          style: const TextStyle(fontSize: 24),
                        ),
                        title: Text(
                          currency.name,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text('${currency.code} • ${currency.symbol}'),
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle,
                                color: theme.colorScheme.primary,
                              )
                            : null,
                        onTap: () {
                          ref
                              .read(displayCurrencyProvider.notifier)
                              .setCurrency(currency.code);
                          Navigator.pop(context);
                          ref.read(refreshRatesProvider)();
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Small uppercase section heading used on the onboarding screen.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {required this.theme});

  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }
}

/// Tappable currency row showing the current selection; opens the picker.
class _CurrencyTile extends StatelessWidget {
  const _CurrencyTile({
    required this.currency,
    required this.fallbackCode,
    required this.onTap,
  });

  final CurrencyInfo? currency;
  final String fallbackCode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Text(
                currency?.flag ?? '💱',
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  currency != null
                      ? '${currency!.name} (${currency!.code} • '
                          '${currency!.symbol})'
                      : fallbackCode,
                  style: theme.textTheme.bodyLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
