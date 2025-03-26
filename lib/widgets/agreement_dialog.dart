import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';

class AgreementDialog extends StatefulWidget {
  final String rideId;

  const AgreementDialog({super.key, required this.rideId});

  @override
  State<AgreementDialog> createState() => _AgreementDialogState();
}

class _AgreementDialogState extends State<AgreementDialog> {
  bool _isAgreeing = false;
  bool _hasAgreed = false;
  late ApiService _apiService;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _apiService = Provider.of<ApiService>(context, listen: false);
  }

  Future<void> _handleAgreement() async {
    setState(() => _isAgreeing = true);
    try {
      await _apiService.sendAgreement(widget.rideId);
      if (mounted) setState(() => _hasAgreed = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Agreement failed: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAgreeing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AlertDialog(
      title: const Text('Ride Agreement'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('By agreeing, you confirm:'),
            const SizedBox(height: 12),
            _buildAgreementPoint(Icons.directions_car, 'All participants have coordinated transport'),
            _buildAgreementPoint(Icons.location_on, 'You understand the meeting point'),
            _buildAgreementPoint(Icons.security, 'You accept responsibility for safety'),
            const SizedBox(height: 20),
            if (_hasAgreed)
              Center(
                child: Chip(
                  label: const Text('Agreement received'),
                  backgroundColor: colors.tertiaryContainer,
                  labelStyle: TextStyle(color: colors.onTertiaryContainer),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isAgreeing ? null : _handleAgreement,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isAgreeing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('I Agree to These Terms'),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isAgreeing ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget _buildAgreementPoint(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}