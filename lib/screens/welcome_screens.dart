import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return ScreenSurface(
      padding: const EdgeInsets.symmetric(horizontal: 70, vertical: 34),
      child: Column(
        children: [
          const SizedBox(height: 15),
          const Text(
            'H',
            style: TextStyle(
              color: AppColors.gold,
              fontSize: 145,
              height: 0.9,
              fontWeight: FontWeight.w300,
              fontFamily: 'serif',
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'H A I D W A R E',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 30,
              letterSpacing: 6,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'H O S P I T A L I T Y',
            style: TextStyle(
              color: AppColors.gold,
              fontSize: 17,
              letterSpacing: 5,
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Smart Service. Happy Guests.',
            style: TextStyle(color: AppColors.muted, fontSize: 17),
          ),
          const Spacer(),
          const LinearProgressIndicator(
            value: 0.62,
            minHeight: 3,
            backgroundColor: AppColors.border,
            color: AppColors.gold,
          ),
          const SizedBox(height: 8),
          const Text(
            'Loading...',
            style: TextStyle(color: AppColors.muted, fontSize: 14),
          ),
          const SizedBox(height: 13),
          SizedBox(
            width: 215,
            child: GoldButton(
              label: 'Continue',
              onPressed: onContinue,
              icon: Icons.arrow_forward,
            ),
          ),
        ],
      ),
    );
  }
}

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({
    super.key,
    required this.selectedLanguage,
    required this.onSelectLanguage,
    required this.onContinue,
    required this.onBack,
  });

  final String selectedLanguage;
  final ValueChanged<String> onSelectLanguage;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    const languages = ['English', 'Français', 'Español', 'العربية'];
    return ScreenSurface(
      padding: const EdgeInsets.symmetric(horizontal: 70, vertical: 25),
      child: Column(
        children: [
          PageHeader(title: 'Language', onBack: onBack),
          const SizedBox(height: 12),
          const Icon(Icons.language, color: AppColors.gold, size: 43),
          const SizedBox(height: 12),
          const Text(
            'Select Language',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 26,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Choose your preferred language',
            style: TextStyle(color: AppColors.muted, fontSize: 15),
          ),
          const SizedBox(height: 15),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final language in languages)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => onSelectLanguage(language),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selectedLanguage == language
                                ? const Color(0xFF211A0D)
                                : AppColors.surface,
                            border: Border.all(
                              color: selectedLanguage == language
                                  ? AppColors.gold
                                  : AppColors.border,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (selectedLanguage == language)
                                const Icon(
                                  Icons.check_circle,
                                  color: AppColors.gold,
                                  size: 19,
                                ),
                              if (selectedLanguage == language)
                                const SizedBox(width: 7),
                              Text(
                                language,
                                style: const TextStyle(
                                  fontSize: 17,
                                  color: AppColors.text,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: 270,
            child: GoldButton(
              label: 'Continue',
              onPressed: onContinue,
              icon: Icons.arrow_forward,
            ),
          ),
        ],
      ),
    );
  }
}

class RoomScreen extends StatefulWidget {
  const RoomScreen({
    super.key,
    required this.assignedId,
    required this.onAssignedIdChanged,
    required this.onContinue,
    required this.onBack,
  });

  final String assignedId;
  final ValueChanged<String> onAssignedIdChanged;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return ScreenSurface(
      padding: const EdgeInsets.symmetric(horizontal: 70, vertical: 22),
      child: Column(
        children: [
          PageHeader(title: 'Room / Table Info', onBack: widget.onBack),
          const SizedBox(height: 2),
          const Icon(
            Icons.room_service_outlined,
            color: AppColors.gold,
            size: 30,
          ),
          const SizedBox(height: 2),
          const Text(
            'Enter your assigned ID',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Text(
            'Enter the room or table number provided to you',
            style: TextStyle(color: AppColors.muted, fontSize: 15),
          ),
          Expanded(
            child: Center(
              child: SizedBox(
                width: 360,
                child: Form(
                  key: _formKey,
                  child: TextFormField(
                    initialValue: widget.assignedId,
                    onChanged: widget.onAssignedIdChanged,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Room / table number',
                      hintText: 'e.g. 101',
                      prefixIcon: const Icon(Icons.tag),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: AppColors.border,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: AppColors.border,
                        ),
                      ),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Room / table number is required'
                        : null,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Need help? Contact reception',
            style: TextStyle(color: AppColors.muted, fontSize: 14),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: 250,
            child: GoldButton(
              label: 'Browse Menu',
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  widget.onContinue();
                }
              },
              icon: Icons.arrow_forward,
            ),
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.cartCount,
    required this.onOpenKitchen,
    required this.onOpenBar,
    required this.onOpenServices,
    required this.onOpenRoom,
    required this.onOpenCart,
    required this.onOpenNotifications,
  });

  final int cartCount;
  final VoidCallback onOpenKitchen;
  final VoidCallback onOpenBar;
  final VoidCallback onOpenServices;
  final VoidCallback onOpenRoom;
  final VoidCallback onOpenCart;
  final VoidCallback onOpenNotifications;

  @override
  Widget build(BuildContext context) {
    return ScreenSurface(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Room details',
                onPressed: onOpenRoom,
                icon: const Icon(Icons.menu, size: 24),
              ),
              const Spacer(),
              const Text(
                'Room 101  ⌄',
                style: TextStyle(color: AppColors.text, fontSize: 17),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Notifications',
                onPressed: onOpenNotifications,
                icon: const Icon(Icons.notifications_none, size: 22),
              ),
              IconButton(
                tooltip: 'Open cart',
                onPressed: onOpenCart,
                icon: Badge(
                  label: Text('$cartCount'),
                  backgroundColor: AppColors.gold,
                  textColor: AppColors.background,
                  child: const Icon(Icons.shopping_cart_outlined, size: 22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          const Text(
            'Good afternoon 👋',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 29,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'What would you like to order?',
            style: TextStyle(color: AppColors.muted, fontSize: 17),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _CategoryCard(
                    title: 'Kitchen',
                    subtitle: 'Delicious meals',
                    icon: Icons.restaurant,
                    onTap: onOpenKitchen,
                    variant: 0,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _CategoryCard(
                    title: 'Bar',
                    subtitle: 'Drinks & more',
                    icon: Icons.local_bar,
                    onTap: onOpenBar,
                    variant: 1,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _CategoryCard(
                    title: 'Services',
                    subtitle: 'Hotel services',
                    icon: Icons.room_service,
                    onTap: onOpenServices,
                    variant: 2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: onOpenKitchen,
            borderRadius: BorderRadius.circular(10),
            child: const InfoPanel(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              child: Row(
                children: [
                  Icon(Icons.sell_outlined, color: AppColors.gold, size: 27),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Special Offer',
                          style: TextStyle(
                            color: AppColors.goldLight,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '10% off selected items',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'View all',
                    style: TextStyle(color: AppColors.text, fontSize: 14),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward, color: AppColors.gold, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    required this.variant,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final int variant;

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: FoodIllustration(variant: variant)),
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 9, 13, 11),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(icon, color: AppColors.gold, size: 23),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
