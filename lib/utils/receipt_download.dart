import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../services/api_service.dart';

/// Downloads an order's receipt and opens it in the device's PDF viewer (which can save or share it).
/// It shows its own messages, so a screen only has to call it.
Future<void> downloadReceipt(BuildContext context, int orderId, String orderNumber) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..clearSnackBars()
    ..showSnackBar(const SnackBar(content: Text('Preparing your receipt…')));

  final (bytes, error) = await ApiService.instance.downloadReceipt(orderId);
  messenger.clearSnackBars();

  if (bytes == null) {
    messenger.showSnackBar(SnackBar(content: Text(error ?? 'The receipt could not be downloaded.')));
    return;
  }

  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/Receipt-$orderNumber.pdf');
    await file.writeAsBytes(bytes, flush: true);

    final result = await OpenFilex.open(file.path, type: 'application/pdf');
    if (result.type != ResultType.done) {
      messenger.showSnackBar(
        const SnackBar(content: Text('The receipt was saved, but no app on this phone can open PDF files.')),
      );
    }
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text('The receipt could not be saved on this device.')));
  }
}