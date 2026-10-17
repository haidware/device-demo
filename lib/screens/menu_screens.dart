import 'package:flutter/material.dart';

import '../models/order.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class KitchenScreen extends StatelessWidget {
  const KitchenScreen({
    super.key,
    required this.items,
    required this.category,
    required this.cartCount,
    required this.onSelectCategory,
    required this.onOpenCart,
    required this.onSelectItem,
    required this.onBack,
  });

  final List<MenuItem> items;
  final String category;
  final int cartCount;
  final ValueChanged<String> onSelectCategory;
  final VoidCallback onOpenCart;
  final ValueChanged<MenuItem> onSelectItem;
  final VoidCallback onBack;

  static const categories = [
    'All',
    'Starters',
    'Main Course',
    'Sides',
    'Desserts',
    'Bar',
  ];

  @override
  Widget build(BuildContext context) {
    final visibleItems = category == 'All'
        ? items
        : items.where((item) => item.category == category).toList();
    return ScreenSurface(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: category == 'Bar' ? 'Bar' : 'Kitchen',
            centerTitle: false,
            onBack: onBack,
            trailing: IconButton(
              tooltip: 'Open cart',
              onPressed: onOpenCart,
              icon: Badge(
                label: Text('$cartCount'),
                backgroundColor: AppColors.gold,
                textColor: AppColors.background,
                child: const Icon(Icons.shopping_cart_outlined),
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 45,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = categories[index];
                final selected = item == category;
                return ChoiceChip(
                  label: Text(item),
                  selected: selected,
                  onSelected: (_) => onSelectCategory(item),
                  selectedColor: const Color(0xFF342712),
                  backgroundColor: AppColors.surface,
                  labelStyle: TextStyle(
                    color: selected ? AppColors.goldLight : AppColors.text,
                    fontSize: 15,
                  ),
                  side: BorderSide(
                    color: selected ? AppColors.gold : AppColors.border,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 13),
          Expanded(
            child: visibleItems.isEmpty
                ? const Center(
                    child: Text(
                      'No items in this category yet.',
                      style: TextStyle(color: AppColors.muted, fontSize: 17),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: visibleItems.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 14),
                    itemBuilder: (context, index) => SizedBox(
                      width: 210,
                      child: _MenuItemCard(
                        item: visibleItems[index],
                        index: index,
                        onTap: () => onSelectItem(visibleItems[index]),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  const _MenuItemCard({
    required this.item,
    required this.index,
    required this.onTap,
  });

  final MenuItem item;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: FoodIllustration(variant: index)),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          formatPrice(item.price),
                          style: const TextStyle(
                            color: AppColors.goldLight,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Container(
                        width: 29,
                        height: 29,
                        decoration: const BoxDecoration(
                          color: AppColors.gold,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add,
                          color: AppColors.background,
                          size: 19,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DetailScreen extends StatelessWidget {
  const DetailScreen({
    super.key,
    required this.item,
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
    required this.onAddToCart,
    required this.onBack,
  });

  final MenuItem item;
  final int quantity;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final VoidCallback onAddToCart;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ScreenSurface(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(title: 'Item Detail', onBack: onBack),
          const SizedBox(height: 4),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: FoodIllustration(variant: menuItems.indexOf(item)),
                ),
                const SizedBox(width: 28),
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        item.description,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 17,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              formatPrice(item.price),
                              style: const TextStyle(
                                color: AppColors.goldLight,
                                fontSize: 25,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          QuantityStepper(
                            quantity: quantity,
                            onDecrement: onDecrement,
                            onIncrement: onIncrement,
                            compact: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          InfoPanel(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              children: [
                const Icon(
                  Icons.schedule_outlined,
                  color: AppColors.goldLight,
                  size: 20,
                ),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text(
                    'Estimated order time',
                    style: TextStyle(color: AppColors.muted, fontSize: 14),
                  ),
                ),
                const Text(
                  estimatedPreparationTime,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: GoldButton(
              label: 'Add to Cart',
              onPressed: onAddToCart,
              icon: Icons.shopping_cart_outlined,
            ),
          ),
        ],
      ),
    );
  }
}

class CartScreen extends StatelessWidget {
  const CartScreen({
    super.key,
    required this.lines,
    required this.subtotal,
    required this.serviceCharge,
    required this.total,
    required this.onChangeQuantity,
    required this.onCheckout,
    required this.onBack,
  });

  final List<CartLine> lines;
  final int subtotal;
  final int serviceCharge;
  final int total;
  final void Function(MenuItem item, int change) onChangeQuantity;
  final VoidCallback onCheckout;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final isEmpty = lines.isEmpty;
    return ScreenSurface(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 20),
      child: Column(
        children: [
          PageHeader(title: 'Your Cart', onBack: onBack),
          const SizedBox(height: 4),
          if (isEmpty)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shopping_cart_outlined,
                      size: 54,
                      color: AppColors.gold,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Your cart is empty',
                      style: TextStyle(color: AppColors.text, fontSize: 23),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Browse the menu to add something delicious.',
                      style: TextStyle(color: AppColors.muted, fontSize: 15),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Expanded(
              child: ListView.separated(
                itemCount: lines.length,
                separatorBuilder: (context, index) => const SizedBox(height: 9),
                itemBuilder: (context, index) {
                  final line = lines[index];
                  return InfoPanel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 54,
                          height: 54,
                          child: FoodIllustration(
                            compact: true,
                            variant: index,
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                line.item.name,
                                style: const TextStyle(
                                  color: AppColors.text,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                formatPrice(line.item.price),
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        QuantityStepper(
                          quantity: line.quantity,
                          compact: true,
                          onDecrement: () => onChangeQuantity(line.item, -1),
                          onIncrement: () => onChangeQuantity(line.item, 1),
                        ),
                        const SizedBox(width: 15),
                        SizedBox(
                          width: 100,
                          child: Text(
                            formatPrice(line.total),
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              color: AppColors.goldLight,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            _AmountRow(label: 'Subtotal', amount: subtotal),
            const SizedBox(height: 3),
            _AmountRow(label: 'Service Charge (10%)', amount: serviceCharge),
            const Divider(color: AppColors.border, height: 16),
            _AmountRow(label: 'Total', amount: total, emphasized: true),
          ],
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            child: GoldButton(
              label: isEmpty ? 'Continue Browsing' : 'Checkout',
              onPressed: onCheckout,
              icon: isEmpty ? Icons.arrow_forward : Icons.arrow_forward,
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.amount,
    this.emphasized = false,
  });

  final String label;
  final int amount;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: emphasized ? AppColors.text : AppColors.muted,
            fontSize: emphasized ? 18 : 15,
            fontWeight: emphasized ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
        Text(
          formatPrice(amount),
          style: TextStyle(
            color: emphasized ? AppColors.goldLight : AppColors.text,
            fontSize: emphasized ? 18 : 15,
            fontWeight: emphasized ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
