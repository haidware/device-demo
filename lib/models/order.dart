const estimatedPreparationTime = '20–30 min';

class MenuItem {
  const MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
  });

  final String id;
  final String name;
  final String description;
  final String category;
  final int price;
}

class CartLine {
  const CartLine({required this.item, required this.quantity});

  final MenuItem item;
  final int quantity;

  int get total => item.price * quantity;
}

const menuItems = <MenuItem>[
  MenuItem(
    id: 'chicken',
    name: 'Grilled Chicken',
    description:
        'Juicy grilled chicken with herbs and spices, served with vegetables.',
    category: 'Main Course',
    price: 6500,
  ),
  MenuItem(
    id: 'jollof',
    name: 'Jollof Rice',
    description:
        'Nigerian jollof rice, slow cooked with peppers and fragrant spices.',
    category: 'Main Course',
    price: 5000,
  ),
  MenuItem(
    id: 'burger',
    name: 'Beef Burger',
    description: 'Grilled beef, fresh greens and house sauce in a toasted bun.',
    category: 'Main Course',
    price: 6000,
  ),
  MenuItem(
    id: 'pasta',
    name: 'Chicken Pasta',
    description: 'Creamy pasta with tender chicken and freshly grated herbs.',
    category: 'Main Course',
    price: 5500,
  ),
  MenuItem(
    id: 'mocktail',
    name: 'Mango Mocktail',
    description: 'Chilled mango and citrus mocktail, freshly prepared.',
    category: 'Bar',
    price: 3000,
  ),
  MenuItem(
    id: 'orange-juice',
    name: 'Fresh Orange Juice',
    description: 'Freshly squeezed orange juice served over ice.',
    category: 'Bar',
    price: 2500,
  ),
];

String formatPrice(int value) {
  final digits = value.toString();
  final groups = <String>[];
  for (var end = digits.length; end > 0; end -= 3) {
    final start = end - 3 < 0 ? 0 : end - 3;
    groups.insert(0, digits.substring(start, end));
  }
  return 'N${groups.join(',')}';
}
