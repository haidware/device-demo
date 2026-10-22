import 'package:flutter/material.dart';

import '../models/hospitality_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({
    super.key,
    required this.services,
    required this.onRequestService,
    required this.onBack,
  });

  final List<HospitalityService> services;
  final Future<String> Function(HospitalityService service) onRequestService;
  final VoidCallback onBack;

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  int? _requestingServiceId;
  String? _message;
  bool _requestSucceeded = false;

  Future<void> _requestService(HospitalityService service) async {
    setState(() {
      _requestingServiceId = service.id;
      _message = null;
    });
    try {
      final requestId = await widget.onRequestService(service);
      if (!mounted) return;
      setState(() {
        _requestingServiceId = null;
        _requestSucceeded = true;
        _message = '${service.name} requested · Ref $requestId';
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _requestingServiceId = null;
        _requestSucceeded = false;
        _message = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenSurface(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(title: 'Services', onBack: widget.onBack),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                _message!,
                style: TextStyle(
                  color: _requestSucceeded ? AppColors.green : AppColors.red,
                  fontSize: 14,
                ),
              ),
            ),
          Expanded(
            child: widget.services.isEmpty
                ? const Center(
                    child: Text(
                      'No services are available right now.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted, fontSize: 16),
                    ),
                  )
                : ListView.separated(
                    itemCount: widget.services.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final service = widget.services[index];
                      final isRequesting = _requestingServiceId == service.id;
                      return InfoPanel(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.room_service_outlined,
                              color: AppColors.gold,
                              size: 26,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    service.name,
                                    style: const TextStyle(
                                      color: AppColors.text,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (service.description.isNotEmpty)
                                    Text(
                                      service.description,
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 120,
                              height: 40,
                              child: FilledButton(
                                onPressed: _requestingServiceId == null
                                    ? () => _requestService(service)
                                    : null,
                                child: Text(
                                  isRequesting ? 'Sending…' : 'Request',
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
