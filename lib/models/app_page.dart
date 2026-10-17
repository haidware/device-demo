enum AppPage {
  overview,
  splash,
  language,
  room,
  home,
  kitchen,
  detail,
  cart,
  checkout,
  confirmation,
  tracking,
  orderDetails,
  notifications,
  designSystem,
}

extension AppPageLabel on AppPage {
  String get label => switch (this) {
    AppPage.overview => 'Screen Overview',
    AppPage.splash => 'Splash Screen',
    AppPage.language => 'Language Selection',
    AppPage.room => 'Room / Table Info',
    AppPage.home => 'Home - Category',
    AppPage.kitchen => 'Kitchen Menu',
    AppPage.detail => 'Item Detail',
    AppPage.cart => 'Cart',
    AppPage.checkout => 'Checkout',
    AppPage.confirmation => 'Order Confirmation',
    AppPage.tracking => 'Order Tracking',
    AppPage.orderDetails => 'Order Details',
    AppPage.notifications => 'Notifications',
    AppPage.designSystem => 'Design System',
  };
}
