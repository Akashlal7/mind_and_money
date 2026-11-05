import 'package:flutter/material.dart';

/// Helper mapping category icon strings to Material IconData
class CategoryIconHelper {
  CategoryIconHelper._();

  static const Map<String, IconData> _icons = {
    'restaurant': Icons.restaurant_rounded,
    'shopping_basket': Icons.shopping_basket_rounded,
    'directions_car': Icons.directions_car_rounded,
    'home': Icons.home_rounded,
    'receipt_long': Icons.receipt_long_rounded,
    'favorite': Icons.favorite_rounded,
    'school': Icons.school_rounded,
    'movie': Icons.movie_rounded,
    'shopping_bag': Icons.shopping_bag_rounded,
    'spa': Icons.spa_rounded,
    'work': Icons.work_rounded,
    'laptop': Icons.laptop_mac_rounded,
    'add_circle': Icons.add_circle_rounded,
    'category': Icons.category_rounded,
    'fitness_center': Icons.fitness_center_rounded,
    'flight': Icons.flight_rounded,
    'local_gas_station': Icons.local_gas_station_rounded,
    'pets': Icons.pets_rounded,
    'card_giftcard': Icons.card_giftcard_rounded,
    'savings': Icons.savings_rounded,
  };

  static IconData getIcon(String? iconName) {
    if (iconName == null) return Icons.category_rounded;
    return _icons[iconName] ?? Icons.category_rounded;
  }

  static List<String> get availableIcons => _icons.keys.toList();
}
