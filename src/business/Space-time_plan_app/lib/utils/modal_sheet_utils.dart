import 'package:flutter/material.dart';

/// 关闭当前 [Navigator] 栈上叠着的底部弹窗（不弹出普通页面路由）。
void popOpenModalBottomSheets(BuildContext context) {
  Navigator.of(context).popUntil((route) => route is! ModalBottomSheetRoute);
}
