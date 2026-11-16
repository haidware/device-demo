import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

String greetingForTime(DateTime time) {
  if (time.hour < 12) return 'Good morning';
  if (time.hour < 17) return 'Good afternoon';
  return 'Good evening';
}

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

class StaffAccessScreen extends StatefulWidget {
  const StaffAccessScreen({
    super.key,
    required this.deviceIdNumber,
    required this.onDeviceIdNumberChanged,
    required this.onContinue,
    required this.isLoading,
    required this.errorMessage,
    required this.isPortalConfigured,
    required this.onBack,
  });

  final String deviceIdNumber;
  final ValueChanged<String> onDeviceIdNumberChanged;
  final Future<void> Function() onContinue;
  final bool isLoading;
  final String? errorMessage;
  final bool isPortalConfigured;
  final VoidCallback onBack;

  @override
  State<StaffAccessScreen> createState() => _StaffAccessScreenState();
}

class _StaffAccessScreenState extends State<StaffAccessScreen> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return ScreenSurface(
      padding: const EdgeInsets.symmetric(horizontal: 70, vertical: 22),
      child: Column(
        children: [
          PageHeader(title: 'Staff Login', onBack: widget.onBack),
          const SizedBox(height: 2),
          const Icon(
            Icons.room_service_outlined,
            color: AppColors.gold,
            size: 30,
          ),
          const SizedBox(height: 2),
          const Text(
            'Hotel staff sign in',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Text(
            'Enter the assigned device ID number to continue',
            style: TextStyle(color: AppColors.muted, fontSize: 15),
          ),
          if (!widget.isPortalConfigured) ...[
            const SizedBox(height: 4),
            const Text(
              'Demo mode — device IDs are not validated against the portal.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ],
          Expanded(
            child: Center(
              child: SizedBox(
                width: 360,
                child: Form(
                  key: _formKey,
                  child: TextFormField(
                    initialValue: widget.deviceIdNumber,
                    onChanged: widget.onDeviceIdNumberChanged,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Device ID Number',
                      hintText: 'Enter device ID number',
                      prefixIcon: const Icon(Icons.badge_outlined),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Device ID number is required'
                        : null,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (widget.errorMessage != null) ...[
            Text(
              widget.errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.red, fontSize: 13),
            ),
            const SizedBox(height: 6),
          ],
          const Text(
            'Need access? Contact your manager',
            style: TextStyle(color: AppColors.muted, fontSize: 14),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: 250,
            child: GoldButton(
              label: widget.isLoading ? 'Connecting…' : 'Sign In',
              onPressed: widget.isLoading
                  ? null
                  : () async {
                      if (_formKey.currentState!.validate()) {
                        await widget.onContinue();
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
    required this.propertyName,
    required this.roomLabel,
    required this.isQrGuest,
    required this.isConnecting,
    required this.connectionError,
    required this.onRetryConnection,
    required this.onEnterDeviceId,
    required this.onOpenKitchen,
    required this.onOpenBar,
    required this.onOpenServices,
    required this.onOpenRoom,
    required this.onOpenCart,
    required this.onOpenNotifications,
    required this.nextWhatsAppDepartment,
    required this.onOpenNextWhatsApp,
  });

  final int cartCount;
  final String propertyName;
  final String roomLabel;
  final bool isQrGuest;
  final bool isConnecting;
  final String? connectionError;
  final Future<void> Function() onRetryConnection;
  final VoidCallback onEnterDeviceId;
  final VoidCallback onOpenKitchen;
  final VoidCallback onOpenBar;
  final VoidCallback onOpenServices;
  final VoidCallback onOpenRoom;
  final VoidCallback onOpenCart;
  final VoidCallback onOpenNotifications;
  final String? nextWhatsAppDepartment;
  final VoidCallback onOpenNextWhatsApp;

  @override
  Widget build(BuildContext context) {
    final isMobileQrGuest = isQrGuest && MediaQuery.sizeOf(context).width < 700;
    final categoryCards = [
      _CategoryCard(
        title: 'Kitchen',
        subtitle: 'Delicious meals',
        icon: Icons.restaurant_menu,
        onTap: onOpenKitchen,
        variant: 0,
      ),
      _CategoryCard(
        title: 'Bar',
        subtitle: 'Signature drinks & moments',
        icon: Icons.local_bar,
        onTap: onOpenBar,
        variant: 1,
      ),
      _CategoryCard(
        title: 'Services',
        subtitle: 'Considered care, on request',
        icon: Icons.room_service_outlined,
        onTap: onOpenServices,
        variant: 2,
      ),
    ];
    return ScreenSurface(
      padding: isMobileQrGuest
          ? const EdgeInsets.fromLTRB(18, 12, 18, 16)
          : const EdgeInsets.fromLTRB(28, 12, 28, 22),
      child: Stack(
        children: [
          IgnorePointer(
            ignoring: isConnecting || connectionError != null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (!isQrGuest)
                      IconButton(
                        tooltip: 'Room details',
                        onPressed: onOpenRoom,
                        icon: const Icon(Icons.menu, size: 24),
                      ),
                    const Spacer(),
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (propertyName.isNotEmpty)
                            Text(
                              propertyName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.goldLight,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          Text(
                            '$roomLabel  ⌄',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 17,
                            ),
                          ),
                        ],
                      ),
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
                        child: const Icon(
                          Icons.shopping_cart_outlined,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'A STAY, BEAUTIFULLY SERVED',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${greetingForTime(DateTime.now())} 👋',
                  style: const TextStyle(
                    color: AppColors.text,
                    fontFamily: 'serif',
                    fontSize: 28,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Text(
                  'How may we make your experience exceptional?',
                  style: TextStyle(color: AppColors.muted, fontSize: 14),
                ),
                if (nextWhatsAppDepartment != null) ...[
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.mark_chat_unread_outlined,
                            color: AppColors.gold,
                            size: 19,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Send the order message to $nextWhatsAppDepartment',
                              style: const TextStyle(
                                color: AppColors.text,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: onOpenNextWhatsApp,
                            child: const Text('Open WhatsApp'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Expanded(
                  child: Flex(
                    direction: isMobileQrGuest
                        ? Axis.vertical
                        : Axis.horizontal,
                    children: [
                      for (var index = 0; index < categoryCards.length; index++)
                        Expanded(
                          child: Padding(
                            padding: isMobileQrGuest
                                ? EdgeInsets.only(top: index == 0 ? 0 : 10)
                                : EdgeInsets.only(left: index == 0 ? 0 : 12),
                            child: categoryCards[index],
                          ),
                        ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 9),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.circle, color: AppColors.gold, size: 6),
                      SizedBox(width: 8),
                      Text(
                        'Your comfort is our priority',
                        style: TextStyle(color: AppColors.muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isConnecting || connectionError != null)
            Positioned.fill(
              child: ColoredBox(
                color: AppColors.background.withValues(alpha: 0.88),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: InfoPanel(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isConnecting)
                            const CircularProgressIndicator(
                              color: AppColors.gold,
                            )
                          else
                            const Icon(
                              Icons.wifi_off_outlined,
                              color: AppColors.red,
                              size: 32,
                            ),
                          const SizedBox(height: 14),
                          Text(
                            isConnecting
                                ? 'Opening $roomLabel…'
                                : 'Unable to open this location',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (connectionError != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              connectionError!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 16),
                            GoldButton(
                              label: 'Try Again',
                              onPressed: onRetryConnection,
                              icon: Icons.refresh,
                            ),
                            TextButton(
                              onPressed: onEnterDeviceId,
                              child: const Text('Enter device ID manually'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
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
    final accent = switch (variant) {
      0 => const Color(0xFFB98845),
      1 => const Color(0xFF8F9DA8),
      _ => const Color(0xFFD4B77A),
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [const Color(0xFF1B1B1A), AppColors.surface],
          ),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 12, 13, 0),
              child: Row(
                children: [
                  Text(
                    '0${variant + 1}  /  ${switch (variant) {
                      0 => 'DINING',
                      1 => 'DRINKS',
                      _ => 'CONCIERGE',
                    }}',
                    style: TextStyle(
                      color: accent,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_outward, color: accent, size: 17),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.09),
                    border: Border.all(color: accent.withValues(alpha: 0.45)),
                  ),
                  child: Icon(icon, color: accent, size: 35),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 0, 13, 13),
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
                            fontFamily: 'serif',
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
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
