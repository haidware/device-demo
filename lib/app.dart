import 'package:flutter/material.dart';

import 'models/app_page.dart';
import 'models/order.dart';
import 'screens/menu_screens.dart';
import 'screens/order_screens.dart';
import 'screens/welcome_screens.dart';
import 'theme/app_theme.dart';
import 'widgets/app_widgets.dart';

class HaidwareApp extends StatelessWidget {
  const HaidwareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Haidware Hospitality',
      theme: buildAppTheme(),
      home: const HospitalityOrderDemo(),
    );
  }
}

class HospitalityOrderDemo extends StatefulWidget {
  const HospitalityOrderDemo({super.key});

  @override
  State<HospitalityOrderDemo> createState() => _HospitalityOrderDemoState();
}

class _HospitalityOrderDemoState extends State<HospitalityOrderDemo> {
  AppPage _page = AppPage.splash;
  final List<AppPage> _history = [];
  final Map<String, int> _cart = {};
  MenuItem _selectedItem = menuItems.first;
  int _detailQuantity = 1;
  String _deviceIdNumber = '';
  String _transferSenderName = '';
  String _category = 'All';
  int _orderStatus = 0;
  bool _notificationsCleared = false;
  static const _orderNumber = '#HDW-101-00045';

  List<CartLine> get _cartLines => [
    for (final item in menuItems)
      if ((_cart[item.id] ?? 0) > 0)
        CartLine(item: item, quantity: _cart[item.id]!),
  ];

  int get _cartCount =>
      _cart.values.fold(0, (total, quantity) => total + quantity);
  int get _subtotal => _cartLines.fold(0, (total, line) => total + line.total);
  int get _serviceCharge => (_subtotal * 0.1).round();
  int get _grandTotal => _subtotal + _serviceCharge;

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
      _category = 'All';
      _history.add(_page);
      _page = AppPage.kitchen;
    });
  }

  void _openBar() {
    setState(() {
      _category = 'Bar';
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
          onContinue: () => go(AppPage.home),
          onBack: back,
        );
      case AppPage.home:
        return HomeScreen(
          cartCount: _cartCount,
          onOpenKitchen: _openKitchen,
          onOpenBar: _openBar,
          onOpenServices: () => go(AppPage.staffAccess),
          onOpenRoom: () => go(AppPage.staffAccess),
          onOpenCart: () => go(AppPage.cart),
          onOpenNotifications: () => go(AppPage.notifications),
        );
      case AppPage.kitchen:
        return KitchenScreen(
          items: menuItems,
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
          onConfirmOrder: () {
            _orderStatus = 1;
            go(AppPage.confirmation);
          },
          onBack: back,
        );
      case AppPage.confirmation:
        return ConfirmScreen(
          orderNumber: _orderNumber,
          onBackHome: () => go(AppPage.home),
          onTrackOrder: () => go(AppPage.tracking),
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
