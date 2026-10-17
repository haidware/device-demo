import 'package:flutter/material.dart';

import 'models/app_page.dart';
import 'models/order.dart';
import 'screens/menu_screens.dart';
import 'screens/order_screens.dart';
import 'screens/screen_gallery.dart';
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
  AppPage _page = AppPage.overview;
  final List<AppPage> _history = [];
  final Map<String, int> _cart = {};
  MenuItem _selectedItem = menuItems.first;
  int _detailQuantity = 1;
  String _language = 'English';
  String _category = 'All';
  String _paymentMethod = 'Direct Bank Transfer';
  int _orderStatus = 1;
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
      _page = _history.isEmpty ? AppPage.overview : _history.removeLast();
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

  Widget _buildPage(AppPage page, {bool preview = false}) {
    final go = preview ? _ignore : _navigate;
    final back = preview ? _ignore : _back;
    switch (page) {
      case AppPage.overview:
        return const SizedBox.shrink();
      case AppPage.splash:
        return SplashScreen(onContinue: () => go(AppPage.language));
      case AppPage.language:
        return LanguageScreen(
          selectedLanguage: preview ? 'English' : _language,
          onSelectLanguage: preview
              ? (_) {}
              : (language) => setState(() => _language = language),
          onContinue: () => go(AppPage.room),
          onBack: back,
        );
      case AppPage.room:
        return RoomScreen(onContinue: () => go(AppPage.home), onBack: back);
      case AppPage.home:
        return HomeScreen(
          cartCount: preview ? 2 : _cartCount,
          onOpenKitchen: preview ? _ignore : _openKitchen,
          onOpenBar: preview ? _ignore : _openBar,
          onOpenServices: () => go(AppPage.room),
          onOpenRoom: () => go(AppPage.room),
          onOpenCart: () => go(AppPage.cart),
          onOpenNotifications: () => go(AppPage.notifications),
        );
      case AppPage.kitchen:
        return KitchenScreen(
          items: menuItems,
          category: preview ? 'All' : _category,
          cartCount: preview ? 2 : _cartCount,
          onSelectCategory: preview
              ? (_) {}
              : (value) => setState(() => _category = value),
          onOpenCart: () => go(AppPage.cart),
          onSelectItem: preview ? (_) {} : _openItem,
          onBack: back,
        );
      case AppPage.detail:
        return DetailScreen(
          item: preview ? menuItems.first : _selectedItem,
          quantity: preview ? 1 : _detailQuantity,
          onDecrement: preview
              ? _ignore
              : () => setState(() {
                  if (_detailQuantity > 1) _detailQuantity--;
                }),
          onIncrement: preview
              ? _ignore
              : () => setState(() => _detailQuantity++),
          onAddToCart: preview ? _ignore : _addSelectedToCart,
          onBack: back,
        );
      case AppPage.cart:
        final lines = preview
            ? [
                CartLine(item: menuItems[0], quantity: 1),
                CartLine(item: menuItems[1], quantity: 1),
              ]
            : _cartLines;
        final subtotal = lines.fold(0, (total, line) => total + line.total);
        final service = (subtotal * 0.1).round();
        return CartScreen(
          lines: lines,
          subtotal: subtotal,
          serviceCharge: service,
          total: subtotal + service,
          onChangeQuantity: preview ? (_, __) {} : _changeCartQuantity,
          onCheckout: () => go(
            !preview && _cartLines.isEmpty ? AppPage.kitchen : AppPage.checkout,
          ),
          onBack: back,
        );
      case AppPage.checkout:
        return CheckoutScreen(
          paymentMethod: preview ? 'Direct Bank Transfer' : _paymentMethod,
          total: preview ? 12650 : _grandTotal,
          onSelectPayment: preview
              ? (_) {}
              : (value) => setState(() => _paymentMethod = value),
          onConfirm: preview
              ? _ignore
              : () {
                  _orderStatus = 2;
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
          lines: preview
              ? [
                  CartLine(item: menuItems[0], quantity: 1),
                  CartLine(item: menuItems[1], quantity: 1),
                ]
              : _cartLines,
          total: preview ? 12650 : _grandTotal,
          onBackHome: () => go(AppPage.home),
          onBack: back,
        );
      case AppPage.notifications:
        return NotifyScreen(
          onBack: back,
          isCleared: !preview && _notificationsCleared,
          onClear: preview
              ? _ignore
              : () => setState(() => _notificationsCleared = true),
        );
      case AppPage.designSystem:
        return const DesignSystemScreen();
    }
  }

  static void _ignore() {}

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _page == AppPage.overview,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _page != AppPage.overview) _back();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: _page == AppPage.overview
            ? ScreenGallery(
                onOpen: _navigate,
                screenBuilder: (page) => _buildPage(page, preview: true),
              )
            : SafeArea(
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
