import 'package:flutter/material.dart';

class UIUtils {
  static bool _isBottomSheetOpen = false;

  static Future<T?> showAppBottomSheet<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isScrollControlled = true,
  }) async {
    // If a bottom sheet is already open, pop it first
    if (_isBottomSheetOpen) {
      if (context.mounted) {
        Navigator.pop(context);
      }
      _isBottomSheetOpen = false;
      // Small delay to allow pop animation to start or complete if needed
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (!context.mounted) return null;

    _isBottomSheetOpen = true;
    final result = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => PopScope(
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) _isBottomSheetOpen = false;
        },
        child: builder(context),
      ),
    );
    
    _isBottomSheetOpen = false;
    return result;
  }
}
