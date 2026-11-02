import 'package:flutter/material.dart';

/// Emoji choices for custom categories, written as `\u{…}` escapes on
/// purpose: the literal characters were once stripped from this file by a
/// tool, leaving 80 blank tiles that all looked selected (BUG-16).
@visibleForTesting
const List<String> kCategoryEmojis = [
  // Entertainment
  '\u{1F3AC}', '\u{1F3B5}', '\u{1F3AE}', '\u{1F4FA}', '\u{1F3A7}', '\u{1F3A4}', '\u{1F3AD}', '\u{1F37F}',
  // Technology
  '\u{1F4BB}', '\u{1F4F1}', '\u{2601}\u{FE0F}', '\u{1F5A5}\u{FE0F}', '\u{2328}\u{FE0F}', '\u{1F50C}', '\u{1F916}', '\u{1F6F0}\u{FE0F}',
  // Finance
  '\u{1F4B0}', '\u{1F4B3}', '\u{1F3E6}', '\u{1F4C8}', '\u{1F4B5}', '\u{1FA99}', '\u{1F9FE}', '\u{1F4BC}',
  // Health & Fitness
  '\u{2764}\u{FE0F}', '\u{1F4AA}', '\u{1F3CB}\u{FE0F}', '\u{1F9D8}', '\u{1F3C3}', '\u{1F48A}', '\u{1FA7A}', '\u{1F6B4}',
  // Food & Drink
  '\u{1F354}', '\u{1F355}', '\u{2615}', '\u{1F363}', '\u{1F957}', '\u{1F377}', '\u{1F37A}', '\u{1F6D2}',
  // Shopping
  '\u{1F6CD}\u{FE0F}', '\u{1F455}', '\u{1F45F}', '\u{1F4E6}', '\u{1F381}', '\u{1F484}', '\u{231A}', '\u{1F576}\u{FE0F}',
  // Travel
  '\u{2708}\u{FE0F}', '\u{1F697}', '\u{1F3E8}', '\u{1F686}', '\u{1F5FA}\u{FE0F}', '\u{26FD}', '\u{1F695}', '\u{1F9F3}',
  // Education
  '\u{1F4DA}', '\u{1F393}', '\u{270F}\u{FE0F}', '\u{1F9E0}', '\u{1F4DD}', '\u{1F52C}', '\u{1F30D}', '\u{1F5E3}\u{FE0F}',
  // Utilities
  '\u{26A1}', '\u{1F4A1}', '\u{1F4A7}', '\u{1F525}', '\u{1F4F6}', '\u{1F3E0}', '\u{1F527}', '\u{1F5D1}\u{FE0F}',
  // General
  '\u{2B50}', '\u{1F4CC}', '\u{1F514}', '\u{1F512}', '\u{1F436}', '\u{1F476}', '\u{1F331}', '\u{2728}',
];

/// Bottom sheet for picking icons (emoji or Material icons)
class IconPickerSheet extends StatefulWidget {
  const IconPickerSheet({
    super.key,
    this.initialIcon,
    this.initialIsEmoji = true,
    required this.onIconSelected,
  });

  final String? initialIcon;
  final bool initialIsEmoji;
  final void Function(String icon, bool isEmoji) onIconSelected;

  @override
  State<IconPickerSheet> createState() => _IconPickerSheetState();
}

class _IconPickerSheetState extends State<IconPickerSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedIcon;
  bool _isEmoji = true;

  // Common emojis for categories (see [kCategoryEmojis]).
  static const List<String> _emojis = kCategoryEmojis;


  // Common Material icons for categories
  static const List<IconData> _materialIcons = [
    Icons.movie_outlined,
    Icons.music_note_outlined,
    Icons.games_outlined,
    Icons.sports_esports_outlined,
    Icons.smart_display_outlined,
    Icons.podcasts_outlined,
    Icons.headphones_outlined,
    Icons.tv_outlined,
    Icons.laptop_outlined,
    Icons.phone_android_outlined,
    Icons.cloud_outlined,
    Icons.code_outlined,
    Icons.storage_outlined,
    Icons.memory_outlined,
    Icons.wifi_outlined,
    Icons.bluetooth_outlined,
    Icons.account_balance_outlined,
    Icons.credit_card_outlined,
    Icons.savings_outlined,
    Icons.attach_money_outlined,
    Icons.trending_up_outlined,
    Icons.receipt_long_outlined,
    Icons.payment_outlined,
    Icons.currency_exchange_outlined,
    Icons.fitness_center_outlined,
    Icons.monitor_heart_outlined,
    Icons.self_improvement_outlined,
    Icons.spa_outlined,
    Icons.medical_services_outlined,
    Icons.local_hospital_outlined,
    Icons.restaurant_outlined,
    Icons.fastfood_outlined,
    Icons.local_cafe_outlined,
    Icons.local_bar_outlined,
    Icons.cake_outlined,
    Icons.bakery_dining_outlined,
    Icons.local_pizza_outlined,
    Icons.ramen_dining_outlined,
    Icons.shopping_bag_outlined,
    Icons.shopping_cart_outlined,
    Icons.storefront_outlined,
    Icons.local_mall_outlined,
    Icons.redeem_outlined,
    Icons.card_giftcard_outlined,
    Icons.flight_outlined,
    Icons.hotel_outlined,
    Icons.directions_car_outlined,
    Icons.train_outlined,
    Icons.directions_bike_outlined,
    Icons.directions_boat_outlined,
    Icons.map_outlined,
    Icons.explore_outlined,
    Icons.school_outlined,
    Icons.menu_book_outlined,
    Icons.auto_stories_outlined,
    Icons.science_outlined,
    Icons.calculate_outlined,
    Icons.translate_outlined,
    Icons.architecture_outlined,
    Icons.draw_outlined,
    Icons.flash_on_outlined,
    Icons.water_drop_outlined,
    Icons.thermostat_outlined,
    Icons.local_gas_station_outlined,
    Icons.home_outlined,
    Icons.apartment_outlined,
    Icons.settings_outlined,
    Icons.build_outlined,
    Icons.work_outlined,
    Icons.business_outlined,
    Icons.groups_outlined,
    Icons.family_restroom_outlined,
    Icons.pets_outlined,
    Icons.child_care_outlined,
    Icons.favorite_outlined,
    Icons.star_outlined,
    Icons.category_outlined,
    Icons.folder_outlined,
    Icons.label_outlined,
    Icons.bookmark_outlined,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialIsEmoji ? 0 : 1,
    );
    _selectedIcon = widget.initialIcon;
    _isEmoji = widget.initialIsEmoji;

    _tabController.addListener(() {
      setState(() {
        _isEmoji = _tabController.index == 0;
        _selectedIcon = null;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Choose Icon',
                  style: theme.textTheme.headlineSmall,
                ),
                if (_selectedIcon != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _isEmoji
                        ? Text(_selectedIcon!, style: const TextStyle(fontSize: 24))
                        : Icon(
                            IconData(
                              int.parse(_selectedIcon!),
                              fontFamily: 'MaterialIcons',
                            ),
                            size: 24,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Tab bar
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Emoji'),
              Tab(text: 'Icons'),
            ],
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Emoji grid
                _buildEmojiGrid(theme),
                // Material icons grid
                _buildIconsGrid(theme),
              ],
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: _selectedIcon != null
                        ? () {
                            widget.onIconSelected(_selectedIcon!, _isEmoji);
                            Navigator.pop(context);
                          }
                        : null,
                    child: const Text('Select'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiGrid(ThemeData theme) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _emojis.length,
      itemBuilder: (context, index) {
        final emoji = _emojis[index];
        final isSelected = _isEmoji && _selectedIcon == emoji;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedIcon = emoji;
              _isEmoji = true;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIconsGrid(ThemeData theme) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _materialIcons.length,
      itemBuilder: (context, index) {
        final icon = _materialIcons[index];
        final iconCodePoint = icon.codePoint.toString();
        final isSelected = !_isEmoji && _selectedIcon == iconCodePoint;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedIcon = iconCodePoint;
              _isEmoji = false;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              size: 28,
              color: isSelected
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        );
      },
    );
  }
}
