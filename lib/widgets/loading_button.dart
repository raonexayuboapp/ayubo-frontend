import 'package:flutter/material.dart';

class LoadingButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onPressed;

  const LoadingButton({
    super.key,
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;

    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: goldColor,
        disabledBackgroundColor: theme.colorScheme.primary.withValues(alpha: 0.6),
        disabledForegroundColor: goldColor.withValues(alpha: 0.6),
        padding: const EdgeInsets.symmetric(vertical: 14),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: loading
          ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: goldColor,
              ),
            )
          : Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
    );
  }
}