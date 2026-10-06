import 'package:flutter/material.dart';

/// The project badge icons — one per shape in the constellation library.
///
/// This map and `starsShapePresets` (constellation_presets.dart) are two
/// halves of the same catalogue: every preset shape names exactly one of
/// these slugs, no slug is shared by two presets, and there are no spare
/// slugs. Pick "Bicycle" in the library and the badge is the bicycle icon;
/// draw your own shape and you pick freely from the same 100. Both halves
/// are checked against each other by `constellation_presets_test.dart`.
///
/// Deliberately disjoint from the 8 [LifeArea] icons: an area is a
/// supernova and a project is a constellation, and the two must never
/// render with the same glyph. `NewProjectScreen` also filters the area
/// slugs out on top of that, as a belt-and-braces guard.
///
/// Keys are exactly Flutter's own [Icons] constant names, so a slug and its
/// glyph can't drift apart. Grouped the way the library is rather than
/// alphabetically — a pairing only makes sense read next to the shape it
/// belongs to.
const Map<String, IconData> _iconsBySlug = {
  // Nature
  'park': Icons.park, // Tree
  'forest': Icons.forest, // Pine
  'local_florist': Icons.local_florist, // Flower
  'eco': Icons.eco, // Leaf
  'terrain': Icons.terrain, // Mountain
  'waves': Icons.waves, // Wave
  'local_fire_department': Icons.local_fire_department, // Flame
  'wb_sunny': Icons.wb_sunny, // Sun
  'nightlight': Icons.nightlight, // Crescent moon
  'water_drop': Icons.water_drop, // Rain cloud
  'ac_unit': Icons.ac_unit, // Snowflake
  // Animals
  'pets': Icons.pets, // Dog
  'flutter_dash': Icons.flutter_dash, // Bird
  'set_meal': Icons.set_meal, // Fish
  'emoji_nature': Icons.emoji_nature, // Bee
  'filter_vintage': Icons.filter_vintage, // Butterfly
  'cruelty_free': Icons.cruelty_free, // Rabbit
  // Body & sport
  'fitness_center': Icons.fitness_center, // Dumbbell
  'directions_run': Icons.directions_run, // Runner
  'directions_bike': Icons.directions_bike, // Bicycle
  'sports_soccer': Icons.sports_soccer, // Football
  'sports_basketball': Icons.sports_basketball, // Basketball hoop
  'pool': Icons.pool, // Swimmer
  'sports_gymnastics': Icons.sports_gymnastics, // Yoga pose
  'sports_mma': Icons.sports_mma, // Boxing glove
  'sports_tennis': Icons.sports_tennis, // Tennis racket
  'monitor_heart': Icons.monitor_heart, // Heartbeat
  // Work & study
  'business_center': Icons.business_center, // Briefcase
  'laptop_mac': Icons.laptop_mac, // Laptop
  'school': Icons.school, // Graduation cap
  'menu_book': Icons.menu_book, // Open book
  'edit': Icons.edit, // Pencil
  'settings': Icons.settings, // Gear
  'trending_up': Icons.trending_up, // Rising chart
  'stairs': Icons.stairs, // Ladder
  'corporate_fare': Icons.corporate_fare, // Tower
  'schedule': Icons.schedule, // Clock
  'emoji_objects': Icons.emoji_objects, // Lightbulb
  // Money
  'paid': Icons.paid, // Coins
  'account_balance_wallet': Icons.account_balance_wallet, // Wallet
  'account_balance': Icons.account_balance, // Bank
  'credit_card': Icons.credit_card, // Credit card
  'diamond': Icons.diamond, // Diamond
  'shopping_cart': Icons.shopping_cart, // Shopping cart
  'balance': Icons.balance, // Scales
  'vpn_key': Icons.vpn_key, // Key
  // Home & everyday
  'home': Icons.home, // House
  'king_bed': Icons.king_bed, // Bed
  'chair': Icons.chair, // Armchair
  'light': Icons.light, // Table lamp
  'door_front_door': Icons.door_front_door, // Door
  'yard': Icons.yard, // Potted plant
  'umbrella': Icons.umbrella, // Umbrella
  'checkroom': Icons.checkroom, // T-shirt
  'cleaning_services': Icons.cleaning_services, // Broom
  // Food & drink
  'local_cafe': Icons.local_cafe, // Coffee cup
  'restaurant': Icons.restaurant, // Fork and knife
  'wine_bar': Icons.wine_bar, // Wine glass
  'local_pizza': Icons.local_pizza, // Pizza slice
  'cake': Icons.cake, // Cake
  'icecream': Icons.icecream, // Ice cream
  'agriculture': Icons.agriculture, // Apple
  // Art, music & play
  'audiotrack': Icons.audiotrack, // Guitar
  'piano': Icons.piano, // Piano keys
  'music_note': Icons.music_note, // Music note
  'mic': Icons.mic, // Microphone
  'headphones': Icons.headphones, // Headphones
  'brush': Icons.brush, // Paintbrush
  'palette': Icons.palette, // Palette
  'photo_camera': Icons.photo_camera, // Camera
  'sports_esports': Icons.sports_esports, // Game controller
  'casino': Icons.casino, // Dice
  // Travel & adventure
  'flight': Icons.flight, // Airplane
  'sailing': Icons.sailing, // Sailboat
  'directions_car': Icons.directions_car, // Car
  'cabin': Icons.cabin, // Tent
  'explore': Icons.explore, // Compass
  'backpack': Icons.backpack, // Backpack
  'place': Icons.place, // Map pin
  'anchor': Icons.anchor, // Anchor
  'rocket_launch': Icons.rocket_launch, // Rocket
  'luggage': Icons.luggage, // Suitcase
  // People & bonds
  'favorite': Icons.favorite, // Heart
  'people': Icons.people, // Two people
  'handshake': Icons.handshake, // Handshake
  'chat_bubble': Icons.chat_bubble, // Speech bubble
  'redeem': Icons.redeem, // Gift
  'family_restroom': Icons.family_restroom, // Family
  'celebration': Icons.celebration, // Toast
  'mail': Icons.mail, // Envelope
  'campaign': Icons.campaign, // Megaphone
  // Spirit & symbols
  'wb_incandescent': Icons.wb_incandescent, // Candle
  'spa': Icons.spa, // Lotus
  'temple_buddhist': Icons.temple_buddhist, // Temple
  'church': Icons.church, // Cross
  'mosque': Icons.mosque, // Crescent and star
  'synagogue': Icons.synagogue, // Star of David
  'front_hand': Icons.front_hand, // Praying hands
  'visibility': Icons.visibility, // Eye
  'star': Icons.star, // Star
};

/// Falls back to a generic star for a slug this map doesn't know — most
/// likely one saved by an older version of the app, before the icon set was
/// rebuilt around the shape library. A missing glyph is cosmetic; nothing
/// about the project or its stars depends on it.
IconData iconForSlug(String slug) => _iconsBySlug[slug] ?? Icons.star_border;

/// Every slug a project's badge icon can be — the canonical list behind
/// `NewProjectScreen`'s icon grid.
final Set<String> availableIconSlugs = _iconsBySlug.keys.toSet();

/// Which icons float to the top of the picker for a given area, before the
/// rest of the set follows in map order — a shortlist, not a filter: every
/// icon stays reachable from every area. Keyed by
/// [LifeAreaX.suggestedIconsKey].
///
/// Hand-picked rather than derived from [PresetCategory], since the useful
/// grouping isn't the same one: "Body & sport" maps cleanly onto Physical,
/// but Philanthropic borrows from People, Nature and Food at once, and
/// Personal would otherwise get half the catalogue and no shortlist worth
/// the name.
const Map<String, List<String>> suggestedIconsByArea = {
  'physical': [
    'fitness_center',
    'directions_run',
    'directions_bike',
    'sports_soccer',
    'sports_basketball',
    'pool',
    'sports_gymnastics',
    'sports_mma',
    'sports_tennis',
    'monitor_heart',
    'king_bed',
    'restaurant',
  ],
  'psychological': [
    'spa',
    'wb_incandescent',
    'visibility',
    'nightlight',
    'waves',
    'eco',
    'terrain',
    'filter_vintage',
    'menu_book',
    'brush',
    'palette',
    'front_hand',
  ],
  'professional': [
    'business_center',
    'laptop_mac',
    'school',
    'settings',
    'trending_up',
    'stairs',
    'corporate_fare',
    'schedule',
    'emoji_objects',
    'edit',
    'rocket_launch',
    'flight',
  ],
  'financial': [
    'paid',
    'account_balance_wallet',
    'account_balance',
    'credit_card',
    'diamond',
    'shopping_cart',
    'balance',
    'vpn_key',
  ],
  'personal': [
    'park',
    'home',
    'local_cafe',
    'explore',
    'photo_camera',
    'music_note',
    'sports_esports',
    'pets',
    'luggage',
    'star',
    'light',
    'checkroom',
    'cake',
    'audiotrack',
  ],
  'social': [
    'favorite',
    'people',
    'handshake',
    'chat_bubble',
    'redeem',
    'family_restroom',
    'celebration',
    'mail',
    'campaign',
    'wine_bar',
  ],
  'spiritual': [
    'spa',
    'wb_incandescent',
    'temple_buddhist',
    'church',
    'mosque',
    'synagogue',
    'front_hand',
    'visibility',
    'star',
    'nightlight',
  ],
  'philanthropical': [
    'handshake',
    'redeem',
    'campaign',
    'people',
    'family_restroom',
    'eco',
    'park',
    'forest',
    'mail',
    'agriculture',
    'water_drop',
  ],
};
