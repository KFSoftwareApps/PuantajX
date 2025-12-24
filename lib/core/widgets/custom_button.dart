import 'package:flutter/material.dart';

enum CustomButtonType { primary, secondary, outline, text }

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final CustomButtonType type;
  final bool isLoading;
  final IconData? icon;
  final bool isFullWidth;
  final Color? backgroundColor;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.type = CustomButtonType.primary,
    this.isLoading = false,
    this.icon,
    this.isFullWidth = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Widget buttonContent = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: type == CustomButtonType.outline ? colorScheme.primary : colorScheme.onPrimary,
            ),
          ),
          const SizedBox(width: 12),
        ] else if (icon != null) ...[
          Icon(icon, size: 20),
          const SizedBox(width: 8),
        ],
        Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ],
    );

    ButtonStyle style;
    switch (type) {
      case CustomButtonType.primary:
        style = ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
        );
        break;
      case CustomButtonType.secondary:
        style = ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? colorScheme.secondary,
          foregroundColor: colorScheme.onSecondary,
          elevation: 0,
        );
        break;
      case CustomButtonType.outline:
        style = OutlinedButton.styleFrom(
          foregroundColor: backgroundColor ?? colorScheme.primary,
          side: BorderSide(color: backgroundColor ?? colorScheme.primary, width: 2),
        );
        break;
      case CustomButtonType.text:
        style = TextButton.styleFrom(
          foregroundColor: backgroundColor ?? colorScheme.primary,
        );
        break;
    }

    Widget button;
    if (type == CustomButtonType.outline) {
      button = OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: style,
        child: buttonContent,
      );
    } else if (type == CustomButtonType.text) {
      button = TextButton(
        onPressed: isLoading ? null : onPressed,
        style: style,
        child: buttonContent,
      );
    } else {
      button = ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: style,
        child: buttonContent,
      );
    }

    if (isFullWidth) {
      return SizedBox(
        width: double.infinity,
        height: 50, // Minimum touch target 44px + extra
        child: button,
      );
    }

    return SizedBox(height: 50, child: button);
  }
}
