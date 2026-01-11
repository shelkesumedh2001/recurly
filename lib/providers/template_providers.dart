import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subscription_template.dart';
import '../utils/template_constants.dart';

/// Provider for selected template (null when creating from scratch)
final selectedTemplateProvider = StateProvider<SubscriptionTemplate?>((ref) => null);

/// Provider for template search query
final templateSearchQueryProvider = StateProvider<String>((ref) => '');

/// Provider for all templates
final allTemplatesProvider = Provider<Map<TemplateCategory, List<SubscriptionTemplate>>>((ref) {
  return TemplateConstants.getAllTemplates();
});

/// Provider for filtered templates based on search
final filteredTemplatesProvider = Provider<List<SubscriptionTemplate>>((ref) {
  final query = ref.watch(templateSearchQueryProvider);
  return TemplateConstants.searchTemplates(query);
});
