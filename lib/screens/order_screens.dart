import 'package:flutter/material.dart';

import '../models/order.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({
    super.key,
    required this.total,
    required this.onConfirm,
    required this.onBack,
  });

  final int total;
  final VoidCallback onConfirm;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ScreenSurface(
      padding: const EdgeInsets.fromLTRB(30, 12, 30, 20),
      child: Column(
        children: [
          PageHeader(title: 'Checkout', onBack: onBack),
          const SizedBox(height: 14),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Please make payment to:',
              style: TextStyle(color: AppColors.muted, fontSize: 14),
            ),
          ),
          const SizedBox(height: 5),
          const InfoPanel(
            padding: EdgeInsets.symmetric(horizontal: 15, vertical: 9),
            child: Column(
              children: [
                _BankRow(label: 'Bank', value: 'GTBank'),
                _BankRow(label: 'Account Name', value: 'ABC Hotel'),
                _BankRow(label: 'Account Number', value: '0123456789'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'After transferring, tap “I have paid” to request payment confirmation from reception.',
            style: TextStyle(color: AppColors.muted, fontSize: 14),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Amount Due',
                style: TextStyle(color: AppColors.muted, fontSize: 17),
              ),
              Text(
                formatPrice(total),
                style: const TextStyle(
                  color: AppColors.goldLight,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: GoldButton(
              label: 'I have paid',
              onPressed: onConfirm,
              icon: Icons.arrow_forward,
            ),
          ),
        ],
      ),
    );
  }
}

class PaymentRequestScreen extends StatelessWidget {
  const PaymentRequestScreen({
    super.key,
    required this.orderNumber,
    required this.staffId,
    required this.total,
    required this.onBack,
  });

  final String orderNumber;
  final String staffId;
  final int total;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ScreenSurface(
      padding: const EdgeInsets.fromLTRB(35, 18, 35, 22),
      child: Column(
        children: [
          PageHeader(title: 'Payment Request', onBack: onBack),
          const Spacer(),
          const Icon(Icons.chat, color: Color(0xFF25D366), size: 50),
          const SizedBox(height: 10),
          const Text(
            'WhatsApp message sent',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.text,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Demo simulation',
            style: TextStyle(color: AppColors.goldLight, fontSize: 15),
          ),
          const SizedBox(height: 12),
          InfoPanel(
            child: Text(
              'Hello Reception,\n'
              'I have completed a bank transfer.\n'
              'Order: $orderNumber\n'
              'Staff ID: $staffId\n'
              'Amount: ${formatPrice(total)}\n'
              'Please confirm receipt of payment.',
              style: TextStyle(color: AppColors.text, fontSize: 14),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This message is simulated and was not delivered. Connect a reception WhatsApp number and messaging service to enable sending.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _BankRow extends StatelessWidget {
  const _BankRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.muted, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ConfirmScreen extends StatelessWidget {
  const ConfirmScreen({
    super.key,
    required this.orderNumber,
    required this.onBackHome,
    required this.onTrackOrder,
  });

  final String orderNumber;
  final VoidCallback onBackHome;
  final VoidCallback onTrackOrder;

  @override
  Widget build(BuildContext context) {
    return ScreenSurface(
      padding: const EdgeInsets.fromLTRB(80, 25, 80, 22),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 75,
            height: 75,
            decoration: const BoxDecoration(
              color: AppColors.green,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 46),
          ),
          const SizedBox(height: 10),
          const Text(
            'Thank You!',
            style: TextStyle(
              color: AppColors.goldLight,
              fontSize: 31,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Your order has been received.',
            style: TextStyle(color: AppColors.text, fontSize: 17),
          ),
          const SizedBox(height: 12),
          const Text(
            'Order Number',
            style: TextStyle(color: AppColors.muted, fontSize: 14),
          ),
          const SizedBox(height: 3),
          Text(
            orderNumber,
            style: const TextStyle(
              color: AppColors.goldLight,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'We will notify you when your order is being prepared.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 14),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: GoldButton(
              label: 'Track Order',
              onPressed: onTrackOrder,
              icon: Icons.arrow_forward,
            ),
          ),
          TextButton(
            onPressed: onBackHome,
            child: const Text(
              'Back to Home',
              style: TextStyle(color: AppColors.text, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class TrackScreen extends StatelessWidget {
  const TrackScreen({
    super.key,
    required this.orderNumber,
    required this.status,
    required this.onNeedHelp,
    required this.onOpenDetails,
    required this.onBack,
  });

  final String orderNumber;
  final int status;
  final VoidCallback onNeedHelp;
  final VoidCallback onOpenDetails;
  final VoidCallback onBack;

  static const _steps = [
    'Order Placed',
    'Payment Confirmed',
    'Preparing',
    'On the way',
    'Delivered',
  ];

  @override
  Widget build(BuildContext context) {
    final active = status.clamp(0, _steps.length - 1);
    return ScreenSurface(
      padding: const EdgeInsets.fromLTRB(35, 12, 35, 18),
      child: Column(
        children: [
          PageHeader(
            title: 'Track Order',
            onBack: onBack,
            trailing: TextButton(
              onPressed: onOpenDetails,
              child: const Text(
                'Details',
                style: TextStyle(color: AppColors.goldLight, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            orderNumber,
            style: const TextStyle(color: AppColors.muted, fontSize: 14),
          ),
          const SizedBox(height: 9),
          Expanded(
            child: Column(
              children: [
                for (var index = 0; index < _steps.length; index++)
                  Expanded(
                    child: _TrackingStep(
                      title: _steps[index],
                      active: index == active,
                      complete: index < active,
                      last: index == _steps.length - 1,
                      time: index < active
                          ? 'Completed'
                          : (index == active ? 'In progress' : ''),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onNeedHelp,
              icon: const Icon(Icons.support_agent),
              label: const Text('Need Help?'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackingStep extends StatelessWidget {
  const _TrackingStep({
    required this.title,
    required this.active,
    required this.complete,
    required this.last,
    required this.time,
  });

  final String title;
  final bool active;
  final bool complete;
  final bool last;
  final String time;

  @override
  Widget build(BuildContext context) {
    final color = complete
        ? AppColors.green
        : (active ? AppColors.gold : const Color(0xFF656B72));
    return Row(
      children: [
        SizedBox(
          width: 38,
          child: Column(
            children: [
              Container(
                width: 23,
                height: 23,
                decoration: BoxDecoration(
                  color: complete ? AppColors.green : AppColors.background,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: active ? 2 : 1.5),
                ),
                child: complete
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
              if (!last)
                Expanded(
                  child: Container(
                    width: 2,
                    color: complete ? AppColors.green : AppColors.border,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: active || complete ? AppColors.text : AppColors.muted,
                  fontSize: 16,
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              const Spacer(),
              if (time.isNotEmpty)
                Text(
                  time,
                  style: TextStyle(
                    color: active ? AppColors.goldLight : AppColors.muted,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class DetailsScreen extends StatelessWidget {
  const DetailsScreen({
    super.key,
    required this.orderNumber,
    required this.lines,
    required this.total,
    required this.onBackHome,
    required this.onBack,
  });

  final String orderNumber;
  final List<CartLine> lines;
  final int total;
  final VoidCallback onBackHome;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ScreenSurface(
      padding: const EdgeInsets.fromLTRB(35, 12, 35, 20),
      child: Column(
        children: [
          PageHeader(title: 'Order Details', onBack: onBack),
          const SizedBox(height: 11),
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Order Number',
                  style: TextStyle(color: AppColors.muted, fontSize: 14),
                ),
              ),
              Text(
                'Date',
                style: TextStyle(color: AppColors.muted, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: Text(
                  orderNumber,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Text(
                '12 May 2025, 02:30 PM',
                style: TextStyle(color: AppColors.text, fontSize: 13),
              ),
            ],
          ),
          const Divider(color: AppColors.border, height: 25),
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Items',
                  style: TextStyle(color: AppColors.muted, fontSize: 14),
                ),
              ),
              Text(
                'Amount',
                style: TextStyle(color: AppColors.muted, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ListView(
              children: [
                for (final line in lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${line.item.name} x ${line.quantity}',
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Text(
                          formatPrice(line.total),
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const Divider(color: AppColors.border, height: 16),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Total',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                formatPrice(total),
                style: const TextStyle(
                  color: AppColors.goldLight,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: GoldButton(
              label: 'Back to Home',
              onPressed: onBackHome,
              icon: Icons.arrow_forward,
            ),
          ),
        ],
      ),
    );
  }
}

class NotifyScreen extends StatelessWidget {
  const NotifyScreen({
    super.key,
    required this.onBack,
    required this.isCleared,
    required this.onClear,
  });

  final VoidCallback onBack;
  final bool isCleared;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return ScreenSurface(
      padding: const EdgeInsets.fromLTRB(30, 12, 30, 20),
      child: Column(
        children: [
          PageHeader(title: 'Notifications', onBack: onBack),
          const SizedBox(height: 14),
          if (isCleared)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.notifications_none,
                      color: AppColors.gold,
                      size: 50,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'You are all caught up.',
                      style: TextStyle(color: AppColors.text, fontSize: 20),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            const _NotificationCard(
              icon: Icons.restaurant,
              message: 'Your order is being prepared.',
              time: '5 min ago',
              active: true,
            ),
            const SizedBox(height: 9),
            const _NotificationCard(
              icon: Icons.delivery_dining,
              message: 'Your order is on the way.',
              time: '10 min ago',
            ),
            const SizedBox(height: 9),
            const _NotificationCard(
              icon: Icons.check_circle_outline,
              message: 'Your order has been delivered.',
              time: '15 min ago',
            ),
          ],
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Clear All'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.text,
                side: const BorderSide(color: AppColors.gold),
                minimumSize: const Size.fromHeight(44),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.icon,
    required this.message,
    required this.time,
    this.active = false,
  });

  final IconData icon;
  final String message;
  final String time;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return InfoPanel(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: active ? AppColors.gold : AppColors.raisedSurface,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              icon,
              color: active ? AppColors.background : AppColors.gold,
              size: 22,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.text, fontSize: 15),
            ),
          ),
          Text(
            time,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class DesignSystemScreen extends StatelessWidget {
  const DesignSystemScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const colors = [
      (AppColors.gold, 'GOLD'),
      (AppColors.background, 'BG'),
      (AppColors.surface, 'SURFACE'),
      (AppColors.text, 'TEXT'),
    ];
    return ScreenSurface(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(title: 'Design System'),
          const Text(
            'COLORS',
            style: TextStyle(
              color: AppColors.goldLight,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 9),
          Expanded(
            child: Row(
              children: [
                for (final entry in colors)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Column(
                        children: [
                          Expanded(
                            child: Container(
                              color: entry.$1,
                              width: double.infinity,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            entry.$2,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'TYPOGRAPHY',
            style: TextStyle(
              color: AppColors.goldLight,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Heading - Semibold',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Text(
            'Body - Regular',
            style: TextStyle(color: AppColors.muted, fontSize: 15),
          ),
          const SizedBox(height: 12),
          const Text(
            'COMPONENTS',
            style: TextStyle(
              color: AppColors.goldLight,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              Expanded(
                child: GoldButton(label: 'Primary Button', onPressed: _noop),
              ),
              SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: _noop,
                  child: Text('Secondary'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

void _noop() {}
