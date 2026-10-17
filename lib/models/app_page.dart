enum AppPage {
  splash,
  staffAccess,
  home,
  kitchen,
  detail,
  cart,
  checkout,
  paymentRequestSent,
  confirmation,
  tracking,
  orderDetails,
  notifications,
  designSystem,
}

extension AppPageLabel on AppPage {
  String get label => switch (this) {
    AppPage.splash => 'Splash Screen',
    AppPage.staffAccess => 'Staff Login',
    AppPage.home => 'Home - Category',
    AppPage.kitchen => 'Kitchen Menu',
    AppPage.detail => 'Item Detail',
    AppPage.cart => 'Cart',
    AppPage.checkout => 'Checkout',
    AppPage.paymentRequestSent => 'Payment Request Sent',
    AppPage.confirmation => 'Order Confirmation',
    AppPage.tracking => 'Order Tracking',
    AppPage.orderDetails => 'Order Details',
    AppPage.notifications => 'Notifications',
    AppPage.designSystem => 'Design System',
  };
}
