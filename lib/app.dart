import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models/app_page.dart';
import 'models/hospitality_service.dart';
import 'models/order.dart';
import 'services/portal_api.dart';
import 'screens/menu_screens.dart';
import 'screens/order_screens.dart';
import 'screens/service_screens.dart';
import 'screens/staff_notifications_screen.dart';
import 'screens/welcome_screens.dart';
import 'theme/app_theme.dart';
import 'widgets/app_widgets.dart';

String? scannedDeviceIdFromUri(Uri uri) {
  final deviceId = uri.queryParameters['device_id'];
  if (deviceId == null || !RegExp(r'^\d{4,12}$').hasMatch(deviceId)) {
    return null;
  }
  return deviceId;
}

class HaidwareApp extends StatelessWidget {
  const HaidwareApp({
    super.key,
    this.initialUri,
    this.portalApi,
    this.launchWhatsApp,
  });

  final Uri? initialUri;
  final PortalApi? portalApi;
  final Future<bool> Function(Uri url)? launchWhatsApp;

  @override
  Widget build(BuildContext context) {
    final uri = initialUri ?? Uri.base;
    final apiBaseUrl = portalApiBaseUrl(
      isWeb: kIsWeb,
      currentUri: uri,
      configuredBaseUrl: PortalApi.configuredBaseUrl,
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Haidware Hospitality',
      theme: buildAppTheme(),
      home: uri.path.replaceFirst(RegExp(r'/$'), '') == '/ordernotification'
          ? StaffNotificationsScreen(baseUrl: apiBaseUrl, api: portalApi)
          : HospitalityOrderDemo(
              initialUri: uri,
              portalApi: portalApi,
              launchWhatsApp: launchWhatsApp,
            ),
    );
  }
}

class HospitalityOrderDemo extends StatefulWidget {
  const HospitalityOrderDemo({
    super.key,
    this.initialUri,
    this.portalApi,
    this.launchWhatsApp,
  });

  final Uri? initialUri;
  final PortalApi? portalApi;
  final Future<bool> Function(Uri url)? launchWhatsApp;

  @override
  State<HospitalityOrderDemo> createState() => _HospitalityOrderDemoState();
}

class _HospitalityOrderDemoState extends State<HospitalityOrderDemo> {
  AppPage _page = AppPage.splash;
  final List<AppPage> _history = [];
  final Map<String, int> _cart = {};
  MenuItem _selectedItem = menuItems.first;
  List<MenuItem> _menuItems = menuItems;
  List<HospitalityService> _services = const [];
  List<PortalWhatsAppMessage> _pendingWhatsAppMessages = const [];
  int _detailQuantity = 1;
  String _deviceIdNumber = '';
  String _propertyName = '';
  String _roomLabel = 'Room 101';
  String _bankName = 'GTBank';
  String _accountName = 'ABC Hotel';
  String _accountNumber = '0123456789';
  String _transferSenderName = '';
  String _category = 'All';
  String _selectedDepartment = 'kitchen';
  bool _isQrGuest = false;
  int _orderStatus = 0;
  bool _isConnecting = false;
  bool _isSubmittingOrder = false;
  String? _deviceAccessError;
  String? _orderSubmissionError;
  bool _notificationsCleared = false;
  String _orderNumber = '#HDW-101-00045';
  late final PortalApi _portalApi =
      widget.portalApi ??
      PortalApi(
        portalApiBaseUrl(
          isWeb: kIsWeb,
          currentUri: Uri.base,
          configuredBaseUrl: PortalApi.configuredBaseUrl,
        ),
      );

  @override
  void initState() {
    super.initState();
    final scannedDeviceId = scannedDeviceIdFromUri(
      widget.initialUri ?? Uri.base,
    );
    if (scannedDeviceId != null) {
      _isQrGuest = true;
      _deviceIdNumber = scannedDeviceId;
      _page = AppPage.home;
      _isConnecting = _portalApi.isConfigured;
      if (_portalApi.isConfigured) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _signInWithDevice();
        });
      } else {
        _deviceAccessError =
            'This room QR is not connected to the ordering portal yet.';
      }
    }
  }

  @override
  void dispose() {
    _portalApi.close();
    super.dispose();
  }

  List<CartLine> get _cartLines => [
    for (final item in _menuItems)
      if ((_cart[item.id] ?? 0) > 0)
        CartLine(item: item, quantity: _cart[item.id]!),
  ];

  int get _cartCount =>
      _cart.values.fold(0, (total, quantity) => total + quantity);
  int get _orderTotal =>
      _cartLines.fold(0, (total, line) => total + line.total);

  Future<void> _signInWithDevice() async {
    if (_portalApi.isConfigured) {
      setState(() {
        _isConnecting = true;
        _deviceAccessError = null;
      });
      try {
        final session = await _portalApi.signIn(_deviceIdNumber.trim());
        if (!mounted) return;
        setState(() {
          _menuItems = session.menuItems;
          _services = session.services;
          if (_menuItems.isNotEmpty) _selectedItem = _menuItems.first;
          _propertyName = session.propertyName ?? '';
          _roomLabel = session.room ?? 'Device $_deviceIdNumber';
          _bankName = session.bankName;
          _accountName = session.accountName;
          _accountNumber = session.accountNumber;
          _category = 'All';
          _history.add(_page);
          _page = AppPage.home;
          _isConnecting = false;
        });
      } on PortalApiException catch (error) {
        if (!mounted) return;
        setState(() {
          _isConnecting = false;
          _deviceAccessError = error.message;
        });
      } on FormatException {
        if (!mounted) return;
        setState(() {
          _isConnecting = false;
          _deviceAccessError = 'The portal address or response is invalid.';
        });
      }
      return;
    }
    _navigate(AppPage.home);
  }

  Future<void> _confirmOrder() async {
    if (_isSubmittingOrder) return;
    if (_portalApi.isConfigured) {
      setState(() {
        _isSubmittingOrder = true;
        _orderSubmissionError = null;
      });
      try {
        final submission = await _portalApi.submitOrder(
          deviceId: _deviceIdNumber.trim(),
          senderName: _transferSenderName,
          lines: _cartLines,
          expectedTotal: _orderTotal,
        );
        if (!mounted) return;
        final messages = submission.whatsappMessages
            .where((message) => message.url.isNotEmpty)
            .toList();
        setState(() {
          _orderNumber = submission.orderNumber;
          _pendingWhatsAppMessages = messages;
          _orderStatus = 1;
          _isSubmittingOrder = false;
          _cart.clear();
          _history.clear();
          _page = AppPage.home;
        });
        if (messages.isNotEmpty) {
          final firstMessage = messages.first;
          final opened = await _openWhatsApp(firstMessage.url);
          if (mounted) {
            setState(() {
              _pendingWhatsAppMessages = opened
                  ? messages.skip(1).toList()
                  : messages;
            });
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Order submitted to the portal. No assigned WhatsApp contact is available.',
              ),
            ),
          );
        }
      } on PortalApiException catch (error) {
        if (!mounted) return;
        setState(() {
          _isSubmittingOrder = false;
          _orderSubmissionError = error.message;
        });
      } on FormatException {
        if (!mounted) return;
        setState(() {
          _isSubmittingOrder = false;
          _orderSubmissionError =
              'The portal returned an invalid order response.';
        });
      }
      return;
    }
    setState(() {
      _isSubmittingOrder = false;
      _orderSubmissionError =
          'The ordering portal is not connected. Your order was not submitted.';
    });
  }

  Future<bool> _openWhatsApp(String link) async {
    try {
      final url = Uri.parse(link);
      final opened = widget.launchWhatsApp != null
          ? await widget.launchWhatsApp!(url)
          : await launchUrl(url, mode: LaunchMode.externalApplication);
      if (opened || !mounted) return opened;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open WhatsApp.')));
      return false;
    } on PlatformException {
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open WhatsApp.')));
      return false;
    }
  }

  Future<void> _openNextWhatsApp() async {
    if (_pendingWhatsAppMessages.isEmpty) return;
    final message = _pendingWhatsAppMessages.first;
    if (await _openWhatsApp(message.url) && mounted) {
      setState(() => _pendingWhatsAppMessages.removeAt(0));
    }
  }

  void _navigate(AppPage page) {
    if (page == _page) return;
    setState(() {
      _history.add(_page);
      _page = page;
    });
  }

  void _back() {
    setState(() {
      _page = _history.isEmpty ? AppPage.splash : _history.removeLast();
    });
  }

  void _openItem(MenuItem item) {
    setState(() {
      _selectedItem = item;
      _detailQuantity = 1;
      _history.add(_page);
      _page = AppPage.detail;
    });
  }

  void _openKitchen() {
    setState(() {
      _selectedDepartment = 'kitchen';
      _category = 'All';
      _history.add(_page);
      _page = AppPage.kitchen;
    });
  }

  void _openBar() {
    setState(() {
      _selectedDepartment = 'bar';
      _category = 'All';
      _history.add(_page);
      _page = AppPage.kitchen;
    });
  }

  void _changeCartQuantity(MenuItem item, int change) {
    setState(() {
      final next = (_cart[item.id] ?? 0) + change;
      if (next <= 0) {
        _cart.remove(item.id);
      } else {
        _cart[item.id] = next;
      }
    });
  }

  void _addSelectedToCart() {
    _changeCartQuantity(_selectedItem, _detailQuantity);
    _navigate(AppPage.cart);
  }

  Widget _buildPage(AppPage page) {
    final go = _navigate;
    final back = _back;
    switch (page) {
      case AppPage.splash:
        return SplashScreen(onContinue: () => go(AppPage.staffAccess));
      case AppPage.staffAccess:
        return StaffAccessScreen(
          deviceIdNumber: _deviceIdNumber,
          onDeviceIdNumberChanged: (value) => _deviceIdNumber = value,
          onContinue: _signInWithDevice,
          isLoading: _isConnecting,
          errorMessage: _deviceAccessError,
          isPortalConfigured: _portalApi.isConfigured,
          onBack: back,
        );
      case AppPage.home:
        return HomeScreen(
          cartCount: _cartCount,
          propertyName: _propertyName,
          roomLabel: _roomLabel,
          isQrGuest: _isQrGuest,
          isConnecting: _isConnecting,
          connectionError: _deviceAccessError,
          onRetryConnection: _signInWithDevice,
          onEnterDeviceId: () => go(AppPage.staffAccess),
          onOpenKitchen: _openKitchen,
          onOpenBar: _openBar,
          onOpenServices: () => go(AppPage.services),
          onOpenRoom: () => go(AppPage.staffAccess),
          onOpenCart: () => go(AppPage.cart),
          onOpenNotifications: () => go(AppPage.notifications),
          nextWhatsAppDepartment: _pendingWhatsAppMessages.isEmpty
              ? null
              : _pendingWhatsAppMessages.first.department,
          onOpenNextWhatsApp: _openNextWhatsApp,
        );
      case AppPage.kitchen:
        return KitchenScreen(
          items: _menuItems
              .where((item) => item.department == _selectedDepartment)
              .toList(),
          department: _selectedDepartment,
          category: _category,
          cartCount: _cartCount,
          onSelectCategory: (value) => setState(() => _category = value),
          onOpenCart: () => go(AppPage.cart),
          onSelectItem: _openItem,
          onBack: back,
        );
      case AppPage.services:
        return ServicesScreen(
          services: _services,
          onRequestService: (service) => _portalApi.requestService(
            deviceId: _deviceIdNumber.trim(),
            service: service,
          ),
          onBack: back,
        );
      case AppPage.detail:
        return DetailScreen(
          item: _selectedItem,
          quantity: _detailQuantity,
          onDecrement: () => setState(() {
            if (_detailQuantity > 1) _detailQuantity--;
          }),
          onIncrement: () => setState(() => _detailQuantity++),
          onAddToCart: _addSelectedToCart,
          onBack: back,
        );
      case AppPage.cart:
        return CartScreen(
          lines: _cartLines,
          total: _orderTotal,
          onChangeQuantity: _changeCartQuantity,
          onCheckout: () =>
              go(_cartLines.isEmpty ? AppPage.kitchen : AppPage.checkout),
          onBack: back,
        );
      case AppPage.checkout:
        return CheckoutScreen(
          total: _orderTotal,
          bankName: _bankName,
          accountName: _accountName,
          accountNumber: _accountNumber,
          senderName: _transferSenderName,
          onConfirm: (senderName) {
            _transferSenderName = senderName;
            go(AppPage.paymentRequestSent);
          },
          onBack: back,
        );
      case AppPage.paymentRequestSent:
        return PaymentRequestScreen(
          orderNumber: _orderNumber,
          deviceIdNumber: _deviceIdNumber,
          senderName: _transferSenderName,
          total: _orderTotal,
          onConfirmOrder: _confirmOrder,
          isSubmitting: _isSubmittingOrder,
          errorMessage: _orderSubmissionError,
          onBack: back,
        );
      case AppPage.tracking:
        return TrackScreen(
          orderNumber: _orderNumber,
          status: _orderStatus,
          onNeedHelp: () => go(AppPage.notifications),
          onOpenDetails: () => go(AppPage.orderDetails),
          onBack: back,
        );
      case AppPage.orderDetails:
        return DetailsScreen(
          orderNumber: _orderNumber,
          lines: _cartLines,
          total: _orderTotal,
          onBackHome: () => go(AppPage.home),
          onBack: back,
        );
      case AppPage.notifications:
        return NotifyScreen(
          onBack: back,
          isCleared: _notificationsCleared,
          onClear: () => setState(() => _notificationsCleared = true),
        );
      case AppPage.designSystem:
        return const DesignSystemScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobileQrGuest =
        _isQrGuest && MediaQuery.sizeOf(context).width < 700;
    return PopScope(
      canPop: _page == AppPage.splash && _history.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: isMobileQrGuest
              ? _buildPage(_page)
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: DeviceCanvas(child: _buildPage(_page)),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
