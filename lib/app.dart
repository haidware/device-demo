import 'package:flutter/material.dart';

import 'models/app_page.dart';
import 'models/order.dart';
import 'services/portal_api.dart';
import 'screens/menu_screens.dart';
import 'screens/order_screens.dart';
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
  const HaidwareApp({super.key, this.initialUri});

  final Uri? initialUri;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Haidware Hospitality',
      theme: buildAppTheme(),
      home: HospitalityOrderDemo(initialUri: initialUri),
    );
  }
}

class HospitalityOrderDemo extends StatefulWidget {
  const HospitalityOrderDemo({super.key, this.initialUri});

  final Uri? initialUri;

  @override
  State<HospitalityOrderDemo> createState() => _HospitalityOrderDemoState();
}

class _HospitalityOrderDemoState extends State<HospitalityOrderDemo> {
  AppPage _page = AppPage.splash;
  final List<AppPage> _history = [];
  final Map<String, int> _cart = {};
  MenuItem _selectedItem = menuItems.first;
  List<MenuItem> _menuItems = menuItems;
  int _detailQuantity = 1;
  String _deviceIdNumber = '';
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
  final PortalApi _portalApi = PortalApi(PortalApi.configuredBaseUrl);

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
  int get _subtotal => _cartLines.fold(0, (total, line) => total + line.total);
  int get _serviceCharge => (_subtotal * 0.1).round();
  int get _grandTotal => _subtotal + _serviceCharge;

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
          if (_menuItems.isNotEmpty) _selectedItem = _menuItems.first;
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
        final orderNumber = await _portalApi.submitOrder(
          deviceId: _deviceIdNumber.trim(),
          senderName: _transferSenderName,
          lines: _cartLines,
          expectedTotal: _grandTotal,
        );
        if (!mounted) return;
        setState(() {
          _orderNumber = orderNumber;
          _orderStatus = 1;
          _isSubmittingOrder = false;
          _history.add(_page);
          _page = AppPage.confirmation;
        });
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
    setState(() => _orderStatus = 1);
    _navigate(AppPage.confirmation);
  }

  void _backHome() {
    setState(() {
      _cart.clear();
      _history.clear();
      _page = AppPage.home;
    });
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
          roomLabel: _roomLabel,
          showKitchen: _menuItems.any((item) => item.department == 'kitchen'),
          showBar: _menuItems.any((item) => item.department == 'bar'),
          isQrGuest: _isQrGuest,
          isConnecting: _isConnecting,
          connectionError: _deviceAccessError,
          onRetryConnection: _signInWithDevice,
          onEnterDeviceId: () => go(AppPage.staffAccess),
          onOpenKitchen: _openKitchen,
          onOpenBar: _openBar,
          onOpenRoom: () => go(AppPage.staffAccess),
          onOpenCart: () => go(AppPage.cart),
          onOpenNotifications: () => go(AppPage.notifications),
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
          subtotal: _subtotal,
          serviceCharge: _serviceCharge,
          total: _grandTotal,
          onChangeQuantity: _changeCartQuantity,
          onCheckout: () =>
              go(_cartLines.isEmpty ? AppPage.kitchen : AppPage.checkout),
          onBack: back,
        );
      case AppPage.checkout:
        return CheckoutScreen(
          total: _grandTotal,
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
          total: _grandTotal,
          onConfirmOrder: _confirmOrder,
          isSubmitting: _isSubmittingOrder,
          errorMessage: _orderSubmissionError,
          onBack: back,
        );
      case AppPage.confirmation:
        return ConfirmScreen(
          orderNumber: _orderNumber,
          lines: _cartLines,
          onBackHome: _backHome,
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
          total: _grandTotal,
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
    return PopScope(
      canPop: _page == AppPage.splash && _history.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
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
