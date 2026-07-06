import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bottom-nav tab indexes.
const int homeTabIndex = 0;
const int analyticsTabIndex = 1;
const int settingsTabIndex = 2;

/// Currently visible bottom-nav tab. Screens live inside an IndexedStack
/// (state is preserved across switches), so widgets that play an entrance
/// animation watch this to replay it when their tab becomes visible.
final selectedTabProvider = StateProvider<int>((ref) => homeTabIndex);
