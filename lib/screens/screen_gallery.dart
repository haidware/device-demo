import 'package:flutter/material.dart';

import '../models/app_page.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class ScreenGallery extends StatelessWidget {
  const ScreenGallery({
    super.key,
    required this.onOpen,
    required this.screenBuilder,
  });

  final ValueChanged<AppPage> onOpen;
  final Widget Function(AppPage page) screenBuilder;

  static const _firstRow = [
    AppPage.splash,
    AppPage.language,
    AppPage.room,
    AppPage.home,
  ];
  static const _secondRow = [
    AppPage.kitchen,
    AppPage.detail,
    AppPage.cart,
    AppPage.checkout,
    AppPage.designSystem,
  ];
  static const _thirdRow = [
    AppPage.confirmation,
    AppPage.tracking,
    AppPage.orderDetails,
    AppPage.notifications,
  ];

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF07090C),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth < 1460
              ? constraints.maxWidth
              : 1460.0;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
            child: Center(
              child: SizedBox(
                width: maxWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (maxWidth < 620)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'HAIDWARE  /  HOSPITALITY',
                            maxLines: 1,
                            style: TextStyle(
                              color: AppColors.goldLight,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Interactive screen overview',
                                  style: TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => onOpen(AppPage.splash),
                                icon: const Icon(Icons.play_arrow, size: 19),
                                label: const Text('Walkthrough'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.goldLight,
                                  side: const BorderSide(color: AppColors.gold),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'HAIDWARE  /  HOSPITALITY',
                                  style: TextStyle(
                                    color: AppColors.goldLight,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Interactive screen overview',
                                  style: TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => onOpen(AppPage.splash),
                            icon: const Icon(Icons.play_arrow, size: 19),
                            label: const Text('Start walkthrough'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.goldLight,
                              side: const BorderSide(color: AppColors.gold),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 14),
                    _buildRow(context, _firstRow),
                    const SizedBox(height: 13),
                    _buildRow(context, _secondRow),
                    const SizedBox(height: 13),
                    _buildRow(context, _thirdRow),
                    const SizedBox(height: 10),
                    const Center(
                      child: Text(
                        'All screens are designed for 800 x 480 resolution (LVGL)',
                        style: TextStyle(
                          color: Color(0xFF777D84),
                          fontSize: 11,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRow(BuildContext context, List<AppPage> pages) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 13.0;
        final idealWidth =
            (constraints.maxWidth - spacing * (pages.length - 1)) /
            pages.length;
        final cardWidth = idealWidth.clamp(175.0, 260.0);
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: spacing,
          runSpacing: 12,
          children: [
            for (final page in pages)
              SizedBox(
                width: cardWidth,
                child: _GalleryCard(
                  page: page,
                  onTap: () => onOpen(page),
                  screen: screenBuilder(page),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _GalleryCard extends StatelessWidget {
  const _GalleryCard({
    required this.page,
    required this.onTap,
    required this.screen,
  });

  final AppPage page;
  final VoidCallback onTap;
  final Widget screen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 3, bottom: 5),
              child: Text(
                _title(page),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFD7DCE2),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.55,
                ),
              ),
            ),
            Material(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              clipBehavior: Clip.antiAlias,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF2A2D31)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IgnorePointer(child: DeviceCanvas(child: screen)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _title(AppPage page) {
    final number = switch (page) {
      AppPage.splash => '1.',
      AppPage.language => '2.',
      AppPage.room => '3.',
      AppPage.home => '4.',
      AppPage.kitchen => '5.',
      AppPage.detail => '6.',
      AppPage.cart => '7.',
      AppPage.checkout => '8.',
      AppPage.confirmation => '9.',
      AppPage.tracking => '10.',
      AppPage.orderDetails => '11.',
      AppPage.notifications => '12.',
      AppPage.designSystem => '',
      AppPage.overview => '',
    };
    final label = switch (page) {
      AppPage.splash => 'SPLASH SCREEN',
      AppPage.language => 'LANGUAGE SELECTION',
      AppPage.room => 'ROOM / TABLE INFO',
      AppPage.home => 'HOME - CATEGORY',
      AppPage.kitchen => 'KITCHEN MENU (HORIZONTAL)',
      AppPage.detail => 'ITEM DETAIL',
      AppPage.cart => 'CART',
      AppPage.checkout => 'CHECKOUT',
      AppPage.confirmation => 'ORDER CONFIRMATION',
      AppPage.tracking => 'ORDER TRACKING',
      AppPage.orderDetails => 'ORDER DETAILS',
      AppPage.notifications => 'NOTIFICATION',
      AppPage.designSystem => 'DESIGN SYSTEM',
      AppPage.overview => 'OVERVIEW',
    };
    return '$number $label'.trim();
  }
}
