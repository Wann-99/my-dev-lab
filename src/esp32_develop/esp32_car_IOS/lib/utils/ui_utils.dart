import 'package:flutter/material.dart';

class UIUtils {
  static void showAppBottomSheet({
    required BuildContext context,
    required WidgetBuilder builder,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: builder(context),
      ),
    );
  }
}
