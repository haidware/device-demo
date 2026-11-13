import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/portal_api.dart';
import '../services/staff_push.dart';
import '../theme/app_theme.dart';

class StaffNotificationsScreen extends StatefulWidget {
  const StaffNotificationsScreen({super.key, required this.baseUrl, this.api});

  final String baseUrl;
  final PortalApi? api;

  @override
  State<StaffNotificationsScreen> createState() =>
      _StaffNotificationsScreenState();
}

class _StaffNotificationsScreenState extends State<StaffNotificationsScreen> {
  late final PortalApi _api = widget.api ?? PortalApi(widget.baseUrl);
  Timer? _pollTimer;
  PortalStaffSession? _session;
  List<PortalStaffNotification> _notifications = const [];
  final Set<int> _knownNotificationIds = {};
  final Set<int> _seenNotificationIds = {};
  bool _isLoading = true;
  bool _isEnablingPush = false;
  bool _hasLoadedNotifications = false;
  String? _errorMessage;
  String? _pushMessage;

  @override
  void initState() {
    super.initState();
    _loadStaffSession();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _api.close();
    super.dispose();
  }

  Future<void> _loadStaffSession() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final session = await _api.loadStaffSession();
      if (!mounted) return;
      setState(() {
        _session = session;
        _isLoading = false;
      });
      if (session != null) {
        await _refreshNotifications();
        _pollTimer = Timer.periodic(
          const Duration(seconds: 8),
          (_) => _refreshNotifications(),
        );
      }
    } on PortalApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });
    }
  }

  Future<void> _refreshNotifications() async {
    try {
      final notifications = await _api.loadStaffNotifications();
      if (!mounted) return;
      final newNotifications = _hasLoadedNotifications
          ? notifications
                .where(
                  (notification) =>
                      !_knownNotificationIds.contains(notification.id),
                )
                .toList()
          : const <PortalStaffNotification>[];
      if (!_hasLoadedNotifications) {
        _seenNotificationIds.addAll(
          notifications.map((notification) => notification.id),
        );
      }
      _knownNotificationIds.addAll(
        notifications.map((notification) => notification.id),
      );
      setState(() {
        _notifications = notifications;
        _hasLoadedNotifications = true;
        _errorMessage = null;
      });
      if (newNotifications.isNotEmpty) {
        final latest = newNotifications.first;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('${latest.title} · ${latest.room}'),
              duration: const Duration(seconds: 5),
            ),
          );
      }
    } on PortalApiException catch (error) {
      if (!mounted) return;
      if (error.message == 'Sign in to view staff notifications.') {
        _pollTimer?.cancel();
        setState(() {
          _session = null;
          _errorMessage = null;
        });
      } else {
        setState(() => _errorMessage = error.message);
      }
    }
  }

  Future<void> _enablePush() async {
    final session = _session;
    if (session == null || !session.pushEnabled || _isEnablingPush) return;
    setState(() {
      _isEnablingPush = true;
      _pushMessage = null;
    });
    try {
      final subscription = await createStaffPushSubscription(
        session.pushPublicKey,
      );
      await _api.saveStaffPushSubscription(
        csrfToken: session.csrfToken,
        subscription: subscription,
      );
      if (!mounted) return;
      setState(() => _pushMessage = 'Push notifications are enabled.');
    } on PortalApiException catch (error) {
      if (!mounted) return;
      setState(() => _pushMessage = error.message);
    } on UnsupportedError catch (error) {
      if (!mounted) return;
      setState(() => _pushMessage = error.message);
    } on StateError catch (error) {
      if (!mounted) return;
      setState(() => _pushMessage = error.message);
    } finally {
      if (mounted) setState(() => _isEnablingPush = false);
    }
  }

  Future<void> _openStaffLogin() async {
    final opened = await launchUrl(
      _api.staffLoginUri,
      mode: LaunchMode.platformDefault,
    );
    if (!opened && mounted) {
      setState(() => _errorMessage = 'Could not open the staff sign-in page.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Staff Notifications'),
        actions: [
          if (session != null)
            IconButton(
              tooltip: 'Refresh notifications',
              onPressed: _refreshNotifications,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : session == null
          ? _buildSignIn()
          : _buildInbox(session),
    );
  }

  Widget _buildSignIn() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.notifications_active_outlined,
                color: AppColors.gold,
                size: 52,
              ),
              const SizedBox(height: 16),
              const Text(
                'Sign in to your staff inbox',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Use the username and password created for you by your hotel administrator.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, height: 1.5),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.red),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _openStaffLogin,
                icon: const Icon(Icons.login),
                label: const Text('Staff sign in'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _loadStaffSession,
                child: const Text('I have already signed in'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInbox(PortalStaffSession session) {
    return RefreshIndicator(
      onRefresh: _refreshNotifications,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${session.department} · @${session.username}',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 12),
                  if (session.pushEnabled)
                    OutlinedButton.icon(
                      onPressed: _isEnablingPush ? null : _enablePush,
                      icon: _isEnablingPush
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.notifications_active_outlined),
                      label: Text(
                        _isEnablingPush
                            ? 'Enabling push…'
                            : 'Enable push notifications',
                      ),
                    )
                  else
                    const Text(
                      'Background push is not configured yet. New orders will still appear while this inbox is open.',
                      style: TextStyle(color: AppColors.muted, height: 1.4),
                    ),
                  if (_pushMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _pushMessage!,
                      style: TextStyle(
                        color: _pushMessage!.contains('enabled')
                            ? AppColors.green
                            : AppColors.red,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.red),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
            child: Text(
              'Assigned messages (${_notifications.length})',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          if (_notifications.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No assigned orders or service requests yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            )
          else
            for (final notification in _notifications)
              _NotificationCard(
                notification: notification,
                isNew: !_seenNotificationIds.contains(notification.id),
                onTap: () =>
                    setState(() => _seenNotificationIds.add(notification.id)),
              ),
          if (kIsWeb && !session.pushEnabled)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Ask your administrator to configure Web Push to receive alerts while the app is closed.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.isNew,
    required this.onTap,
  });

  final PortalStaffNotification notification;
  final bool isNew;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isOrder = notification.type == 'order';
    final localTime = notification.createdAt.toLocal();
    final time = TimeOfDay.fromDateTime(localTime).format(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      notification.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (isNew)
                    const Chip(
                      label: Text('NEW'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${notification.department} · ${notification.room} · $time',
                style: const TextStyle(color: AppColors.muted),
              ),
              const Divider(height: 20),
              if (isOrder) ...[
                Text('Order ${notification.orderNumber}'),
                if (notification.senderName.isNotEmpty)
                  Text('Transfer sender: ${notification.senderName}'),
                const SizedBox(height: 6),
                for (final item in notification.items)
                  Text('${item.name} × ${item.quantity}'),
                const SizedBox(height: 8),
                Text(
                  'Order amount: ₦${notification.total}',
                  style: const TextStyle(
                    color: AppColors.goldLight,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Order: ${notification.status} · Payment: ${notification.paymentStatus}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ] else ...[
                Text('Request ${notification.orderNumber}'),
                if (notification.details.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(notification.details),
                ],
                const SizedBox(height: 8),
                Text(
                  'Status: ${notification.status}',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
