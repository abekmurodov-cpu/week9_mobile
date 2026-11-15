import 'package:flutter/material.dart';

/// Text field + Apply button. The typed text is ephemeral UI state, so it
/// lives in the controller, not in any of the four cart state holders.
class CouponField extends StatefulWidget {
  const CouponField({
    super.key,
    required this.coupon,
    required this.error,
    required this.onApply,
  });

  final String? coupon;
  final String? error;
  final void Function(String code) onApply;

  @override
  State<CouponField> createState() => _CouponFieldState();
}

class _CouponFieldState extends State<CouponField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            key: const Key('coupon-field'),
            controller: _controller,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Coupon code',
              errorText: widget.error,
              helperText: widget.coupon == null
                  ? null
                  : '${widget.coupon} applied',
            ),
            onSubmitted: widget.onApply,
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: FilledButton.tonal(
            onPressed: () => widget.onApply(_controller.text),
            child: const Text('Apply'),
          ),
        ),
      ],
    ),
  );
}
