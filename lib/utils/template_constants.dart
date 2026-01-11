import '../models/subscription_template.dart';
import '../models/enums.dart';

/// Predefined subscription templates
class TemplateConstants {
  // Logo paths for local assets
  static const String _logoPath = 'assets/images/logos';

  // STREAMING TEMPLATES
  static const netflixTemplate = SubscriptionTemplate(
    id: 'netflix',
    name: 'Netflix',
    logoUrl: '$_logoPath/netflix.png',
    category: SubscriptionCategory.entertainment,
    color: '#E50914',
    recommendedPrice: null, // User enters their plan price
    defaultBillingCycle: BillingCycle.monthly,
    description: 'Streaming service',
  );

  static const spotifyTemplate = SubscriptionTemplate(
    id: 'spotify',
    name: 'Spotify',
    logoUrl: '$_logoPath/spotify.png',
    category: SubscriptionCategory.entertainment,
    color: '#1DB954',
    recommendedPrice: null,
    defaultBillingCycle: BillingCycle.monthly,
    description: 'Music streaming',
  );

  static const youtubePremiumTemplate = SubscriptionTemplate(
    id: 'youtube_premium',
    name: 'YouTube Premium',
    logoUrl: '$_logoPath/youtube_premium.png',
    category: SubscriptionCategory.entertainment,
    color: '#FF0000',
    recommendedPrice: null,
    defaultBillingCycle: BillingCycle.monthly,
    description: 'Ad-free videos',
  );

  static const disneyPlusTemplate = SubscriptionTemplate(
    id: 'disney_plus',
    name: 'Disney+',
    logoUrl: '$_logoPath/disney_plus.png',
    category: SubscriptionCategory.entertainment,
    color: '#113CCF',
    recommendedPrice: null,
    defaultBillingCycle: BillingCycle.monthly,
    description: 'Disney streaming',
  );

  static const amazonPrimeTemplate = SubscriptionTemplate(
    id: 'amazon_prime',
    name: 'Amazon Prime',
    logoUrl: '$_logoPath/amazon_prime.png',
    category: SubscriptionCategory.entertainment,
    color: '#FF9900',
    recommendedPrice: null,
    defaultBillingCycle: BillingCycle.monthly,
    description: 'Prime benefits',
  );

  static const appleMusicTemplate = SubscriptionTemplate(
    id: 'apple_music',
    name: 'Apple Music',
    logoUrl: '$_logoPath/apple_music.png',
    category: SubscriptionCategory.entertainment,
    color: '#FA243C',
    recommendedPrice: null,
    defaultBillingCycle: BillingCycle.monthly,
    description: 'Music streaming',
  );

  static const huluTemplate = SubscriptionTemplate(
    id: 'hulu',
    name: 'Hulu',
    logoUrl: '$_logoPath/hulu.png',
    category: SubscriptionCategory.entertainment,
    color: '#1CE783',
    recommendedPrice: null,
    defaultBillingCycle: BillingCycle.monthly,
    description: 'TV & movies',
  );

  // PRODUCTIVITY TEMPLATES
  static const microsoft365Template = SubscriptionTemplate(
    id: 'microsoft_365',
    name: 'Microsoft 365',
    logoUrl: '$_logoPath/microsoft_365.png',
    category: SubscriptionCategory.productivity,
    color: '#D83B01',
    recommendedPrice: null,
    defaultBillingCycle: BillingCycle.monthly,
    description: 'Office suite',
  );

  static const googleWorkspaceTemplate = SubscriptionTemplate(
    id: 'google_workspace',
    name: 'Google Workspace',
    logoUrl: '$_logoPath/google_workspace.png',
    category: SubscriptionCategory.productivity,
    color: '#4285F4',
    recommendedPrice: null,
    defaultBillingCycle: BillingCycle.monthly,
    description: 'Business tools',
  );

  static const notionTemplate = SubscriptionTemplate(
    id: 'notion',
    name: 'Notion',
    logoUrl: '$_logoPath/notion.png',
    category: SubscriptionCategory.productivity,
    color: '#000000',
    recommendedPrice: null,
    defaultBillingCycle: BillingCycle.monthly,
    description: 'Workspace',
  );

  static const chatgptPlusTemplate = SubscriptionTemplate(
    id: 'chatgpt_plus',
    name: 'ChatGPT Plus',
    logoUrl: '$_logoPath/chatgpt_plus.png',
    category: SubscriptionCategory.productivity,
    color: '#10A37F',
    recommendedPrice: null,
    defaultBillingCycle: BillingCycle.monthly,
    description: 'AI assistant',
  );

  static const githubTemplate = SubscriptionTemplate(
    id: 'github',
    name: 'GitHub',
    logoUrl: '$_logoPath/github.png',
    category: SubscriptionCategory.productivity,
    color: '#181717',
    recommendedPrice: null,
    defaultBillingCycle: BillingCycle.monthly,
    description: 'Code hosting',
  );

  static const adobeCreativeCloudTemplate = SubscriptionTemplate(
    id: 'adobe_creative_cloud',
    name: 'Adobe Creative Cloud',
    logoUrl: '$_logoPath/adobe_creative_cloud.png',
    category: SubscriptionCategory.productivity,
    color: '#FF0000',
    recommendedPrice: null,
    defaultBillingCycle: BillingCycle.monthly,
    description: 'Creative suite',
  );

  // CLOUD & DEV TEMPLATES
  static const awsTemplate = SubscriptionTemplate(
    id: 'aws',
    name: 'AWS',
    logoUrl: '$_logoPath/aws.png',
    category: SubscriptionCategory.productivity,
    color: '#FF9900',
    recommendedPrice: null,
    defaultBillingCycle: BillingCycle.monthly,
    description: 'Cloud services',
  );

  static const digitalOceanTemplate = SubscriptionTemplate(
    id: 'digitalocean',
    name: 'DigitalOcean',
    logoUrl: '$_logoPath/digitalocean.png',
    category: SubscriptionCategory.productivity,
    color: '#0080FF',
    recommendedPrice: null,
    defaultBillingCycle: BillingCycle.monthly,
    description: 'Cloud hosting',
  );

  static const vercelTemplate = SubscriptionTemplate(
    id: 'vercel',
    name: 'Vercel',
    logoUrl: '$_logoPath/vercel.png',
    category: SubscriptionCategory.productivity,
    color: '#000000',
    recommendedPrice: null,
    defaultBillingCycle: BillingCycle.monthly,
    description: 'Deployment',
  );

  static const herokuTemplate = SubscriptionTemplate(
    id: 'heroku',
    name: 'Heroku',
    logoUrl: '$_logoPath/heroku.png',
    category: SubscriptionCategory.productivity,
    color: '#430098',
    recommendedPrice: null,
    defaultBillingCycle: BillingCycle.monthly,
    description: 'App platform',
  );

  static const mongodbAtlasTemplate = SubscriptionTemplate(
    id: 'mongodb_atlas',
    name: 'MongoDB Atlas',
    logoUrl: '$_logoPath/mongodb_atlas.png',
    category: SubscriptionCategory.productivity,
    color: '#47A248',
    recommendedPrice: null,
    defaultBillingCycle: BillingCycle.monthly,
    description: 'Database',
  );

  /// Get all templates grouped by category
  static Map<TemplateCategory, List<SubscriptionTemplate>> getAllTemplates() {
    return {
      TemplateCategory.streaming: [
        netflixTemplate,
        spotifyTemplate,
        youtubePremiumTemplate,
        disneyPlusTemplate,
        amazonPrimeTemplate,
        appleMusicTemplate,
        huluTemplate,
      ],
      TemplateCategory.productivity: [
        microsoft365Template,
        googleWorkspaceTemplate,
        notionTemplate,
        chatgptPlusTemplate,
        githubTemplate,
        adobeCreativeCloudTemplate,
      ],
      TemplateCategory.cloudDev: [
        awsTemplate,
        digitalOceanTemplate,
        vercelTemplate,
        herokuTemplate,
        mongodbAtlasTemplate,
      ],
    };
  }

  /// Get all templates as a flat list
  static List<SubscriptionTemplate> getAllTemplatesList() {
    return getAllTemplates().values.expand((list) => list).toList();
  }

  /// Search templates by name
  static List<SubscriptionTemplate> searchTemplates(String query) {
    if (query.isEmpty) return getAllTemplatesList();

    final lowercaseQuery = query.toLowerCase();
    return getAllTemplatesList()
        .where((template) => template.name.toLowerCase().contains(lowercaseQuery))
        .toList();
  }
}
