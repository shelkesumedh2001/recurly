import 'package:flutter/material.dart';

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

  // Common emojis for categories
  static const List<String> _emojis = [
    // Entertainment
    '', '', '', '', '', '', '', '',
    // Technology
    '', '', '', '', '', '', '', '',
    // Finance
    '', '', '', '', '', '', '', '',
    // Health & Fitness
    '', '', '', '‍♂️', '', '', '', '',
    // Food & Drink
    '', '', '', '', '', '', '', '',
    // Shopping
    '', '', '', '', '', '', '', '',
    // Travel
    '', '', '', '', '', '', '', '',
    // Education
    '', '', '', '', '', '', '', '',
    // Utilities
    '', '', '', '', '', '', '', '',
    // General
    '', '', '', '', '', '', '', '',
  ];

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
