import 'package:flutter/material.dart';

/// Stacked, centered actions so Cancel aligns under Continue (not end-aligned).
List<Widget> centeredDialogActions({
  required BuildContext dialogContext,
  required String confirmLabel,
  required VoidCallback onConfirm,
  String cancelLabel = 'Cancel',
  bool isDestructive = false,
}) {
  final scheme = Theme.of(dialogContext).colorScheme;
  return [
    Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: onConfirm,
          style: isDestructive
              ? FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                )
              : null,
          child: Text(confirmLabel),
        ),
        const SizedBox(height: 4),
        Center(
          child: TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
        ),
      ],
    ),
  ];
}

Future<bool?> showAppConfirmDialog({
  required BuildContext context,
  String? title,
  Widget? content,
  String? contentText,
  Widget? icon,
  String confirmLabel = 'Continue',
  String cancelLabel = 'Cancel',
  bool isDestructive = false,
  bool barrierDismissible = true,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) => AlertDialog(
      icon: icon,
      title: title != null ? Text(title) : null,
      content: content ?? (contentText != null ? Text(contentText) : null),
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actions: centeredDialogActions(
        dialogContext: ctx,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
        onConfirm: () => Navigator.of(ctx).pop(true),
      ),
    ),
  );
}
