import 'package:flutter/material.dart';

class ShowDialogs {
  static Future<void> pedirConfirmacion({
    required BuildContext context,
    required String title,
    required String message,
    required VoidCallback onAccept,
    VoidCallback? onCancel,
    String acceptText = 'Aceptar',
    String cancelText = 'Cancelar',
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onAccept();
              },
              child: Text(acceptText),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onCancel?.call();
              },
              child: Text(cancelText),
            ),
          ],
        );
      },
    );
  }
  
  static void mostrarResultado(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
