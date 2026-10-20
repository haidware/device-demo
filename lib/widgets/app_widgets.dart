import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class DeviceCanvas extends StatelessWidget {
  const DeviceCanvas({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 5 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ColoredBox(
          color: AppColors.background,
          child: FittedBox(
            fit: BoxFit.fill,
            child: SizedBox(width: 800, height: 480, child: child),
          ),
        ),
      ),
    );
  }
}

class ScreenSurface extends StatelessWidget {
  const ScreenSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: padding,
      child: child,
    );
  }
}

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
    this.centerTitle = true,
  });

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;
  final bool centerTitle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Row(
        children: [
          SizedBox(
            width: 54,
            child: onBack == null
                ? const Icon(Icons.menu, color: AppColors.text, size: 25)
                : IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back, color: AppColors.text),
                  ),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: centerTitle ? TextAlign.center : TextAlign.left,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 23,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 70,
            child: Align(
              alignment: Alignment.centerRight,
              child: trailing ?? const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

class GoldButton extends StatelessWidget {
  const GoldButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: FilledButton(
        style: FilledButton.styleFrom(
          foregroundColor: const Color(0xFF171717),
          backgroundColor: AppColors.gold,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            if (icon != null) ...[
              const SizedBox(width: 12),
              Icon(icon, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}

class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
    this.compact = false,
  });

  final int quantity;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 18.0 : 22.0;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onDecrement,
            icon: Icon(Icons.remove, size: iconSize),
          ),
          SizedBox(
            width: compact ? 22 : 30,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: compact ? 15 : 18),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onIncrement,
            icon: Icon(Icons.add, size: iconSize),
          ),
        ],
      ),
    );
  }
}

class FoodIllustration extends StatelessWidget {
  const FoodIllustration({super.key, this.compact = false, this.variant = 0});

  final bool compact;
  final int variant;

  @override
  Widget build(BuildContext context) {
    final background = switch (variant % 3) {
      0 => const Color(0xFF493119),
      1 => const Color(0xFF3B3520),
      _ => const Color(0xFF362920),
    };
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [background, const Color(0xFF17140F)],
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: compact ? 64 : 180,
            height: compact ? 64 : 180,
            decoration: BoxDecoration(
              color: const Color(0xFFE6D4AA),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFB7893F),
                width: compact ? 3 : 7,
              ),
            ),
          ),
          Icon(
            switch (variant % 3) {
              0 => Icons.lunch_dining,
              1 => Icons.rice_bowl,
              _ => Icons.set_meal,
            },
            color: const Color(0xFF9B5421),
            size: compact ? 42 : 116,
          ),
          Positioned(
            top: compact ? 7 : 25,
            right: compact ? 11 : 38,
            child: Icon(
              Icons.circle,
              color: AppColors.green,
              size: compact ? 8 : 18,
            ),
          ),
          Positioned(
            bottom: compact ? 9 : 30,
            left: compact ? 12 : 40,
            child: Icon(
              Icons.circle,
              color: AppColors.red,
              size: compact ? 7 : 16,
            ),
          ),
        ],
      ),
    );
  }
}

class InfoPanel extends StatelessWidget {
  const InfoPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}
