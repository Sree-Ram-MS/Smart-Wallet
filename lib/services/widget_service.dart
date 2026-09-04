import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import '../core/utils/utils.dart';

class WidgetService {
  static const String appGroupId = 'group.com.smartwallet.smart_wallet';
  static const String androidWidgetName = 'QuickAddWidgetProvider';

  static Future<void> init() async {
    try {
      await HomeWidget.setAppGroupId(appGroupId);
    } catch (e) {
      debugPrint('WidgetService.init error: $e');
    }
  }

  static Future<void> updateWidgetData({
    required double netBalance,
    required String currency,
  }) async {
    try {
      final symbol = CurrencyUtil.symbol(currency);
      final isNegative = netBalance < 0;
      final absVal = netBalance.abs().toStringAsFixed(2);
      final formatted = isNegative ? '-$symbol$absVal' : '$symbol$absVal';

      await HomeWidget.saveWidgetData<String>('net_balance', formatted);
      await HomeWidget.saveWidgetData<String>('base_currency', currency);
      await HomeWidget.updateWidget(
        androidName: androidWidgetName,
      );
    } catch (e) {
      debugPrint('WidgetService.updateWidgetData error: $e');
    }
  }
}
