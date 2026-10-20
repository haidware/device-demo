import 'package:flutter/material.dart';

import '../models/order.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    super.key,
    required this.total,
    required this.bankName,
    required this.accountName,
    required this.accountNumber,
    required this.senderName,
    required this.onConfirm,
    required this.onBack,
  });

  final int total;
  final String bankName;
  final String accountName;
  final String accountNumber;
  final String senderName;
  final ValueChanged<String> onConfirm;
  final VoidCallback onBack;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _senderNameController;

  @override
  void initState() {
    super.initState();
    _senderNameController = TextEditingController(text: widget.senderName);
  }

  @override
  void dispose() {
    _senderNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenSurface(
      padding: const EdgeInsets.fromLTRB(30, 8, 30, 14),
      child: Column(
        children: [
          PageHeader(title: 'Checkout', onBack: widget.onBack),
          const SizedBox(height: 6),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Please make payment to:',
              style: TextStyle(color: AppColors.muted, fontSize: 14),
            ),
          ),
          const SizedBox(height: 3),
          InfoPanel(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            child: Column(
              children: [
                _BankRow(label: 'Bank', value: widget.bankName, compact: true),
                _BankRow(
                  label: 'Account Name',
                  value: widget.accountName,
                  compact: true,
                ),
                _BankRow(
                  label: 'Account Number',
                  value: widget.accountNumber,
                  compact: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Use the sender name shown on your bank transfer.',
            style: TextStyle(color: AppColors.muted, fontSize: 14),
          ),
          const SizedBox(height: 5),
          Form(
            key: _formKey,
            child: TextFormField(
              controller: _senderNameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Name on bank transfer',
                hintText: 'Enter sender name',
                prefixIcon: const Icon(Icons.person_outline),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
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
                  ? 'Enter sender name'
                  : null,
            ),
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
                formatPrice(widget.total),
                style: const TextStyle(
                  color: AppColors.goldLight,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: GoldButton(
              label: 'I have paid',
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  widget.onConfirm(_senderNameController.text.trim());
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

class PaymentRequestScreen extends StatelessWidget {
  const PaymentRequestScreen({
    super.key,
    required this.orderNumber,
    required this.deviceIdNumber,
    required this.senderName,
    required this.total,
    required this.onConfirmOrder,
    required this.isSubmitting,
    required this.errorMessage,
    required this.onBack,
  });

  final String orderNumber;
  final String deviceIdNumber;
  final String senderName;
  final int total;
  final Future<void> Function() onConfirmOrder;
  final bool isSubmitting;
  final String? errorMessage;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ScreenSurface(
      padding: const EdgeInsets.fromLTRB(35, 18, 35, 22),
      child: Column(
        children: [
          PageHeader(title: 'Confirm Order', onBack: onBack),
          const SizedBox(height: 8),
          const Text(
            'Payment message preview',
            textAlign: TextAlign.left,
            style: TextStyle(
              color: AppColors.text,
              fontSize: 19,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: InfoPanel(
              child: SingleChildScrollView(
                child: Text(
                  'Hello Reception,\n\n'
                  'I have completed a bank transfer.\n'
                  'Order: $orderNumber\n'
                  'Device ID Number: $deviceIdNumber\n'
                  'Name on bank transfer: $senderName\n'
                  'Amount: ${formatPrice(total)}\n\n'
                  'Please confirm receipt of payment.',
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Generated message preview. This is not sent automatically.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.red, fontSize: 12),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: GoldButton(
              label: isSubmitting ? 'Submitting…' : 'Confirm Order',
              onPressed: isSubmitting ? null : () => onConfirmOrder(),
              icon: Icons.check,
            ),
          ),
        ],
      ),
    );
  }
}

class _BankRow extends StatelessWidget {
  const _BankRow({
    required this.label,
    required this.value,
    this.compact = false,
  });

  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 2 : 4),
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
    required this.lines,
    required this.onBackHome,
  });

  final String orderNumber;
  final List<CartLine> lines;
  final VoidCallback onBackHome;

  @override
  Widget build(BuildContext context) {
    return ScreenSurface(
      padding: const EdgeInsets.fromLTRB(80, 16, 80, 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.green,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 6),
          const Text(
            'Thank You!',
            style: TextStyle(
              color: AppColors.goldLight,
              fontSize: 31,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Your order will be confirmed shortly.',
            style: TextStyle(color: AppColors.text, fontSize: 17),
          ),
          const SizedBox(height: 7),
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
          const SizedBox(height: 3),
          const Text(
            'Please expect your order within the estimated time below.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: SingleChildScrollView(
              child: InfoPanel(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Column(
                  children: [
                    for (var index = 0; index < lines.length; index++) ...[
                      if (index > 0)
                        const Divider(height: 8, color: AppColors.border),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${lines[index].item.name} × ${lines[index].quantity}',
                              style: const TextStyle(
                                color: AppColors.text,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Text(
                            lines[index].item.preparationTimeLabel,
                            style: TextStyle(
                              color: AppColors.goldLight,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: GoldButton(label: 'Back to Home', onPressed: onBackHome),
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
