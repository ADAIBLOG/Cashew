import 'dart:convert';
import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/pages/addTransactionPage.dart';
import 'package:budget/pages/upcomingOverdueTransactionsPage.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/notificationsGlobal.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/struct/upcomingTransactionsFunctions.dart';
import 'package:budget/widgets/navigationFramework.dart';
import 'package:budget/widgets/notificationsSettings.dart';
import 'package:budget/widgets/openPopup.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

Future<String?> initializeNotifications() async {
  // Since iOS cannot send scheduled notifications when the app is open
  // There is no need to listen to incoming notification payloads
  if (getPlatform(ignoreEmulation: true) != PlatformOS.isIOS) {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('notification_icon_android2');
    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
            onDidReceiveLocalNotification: (_, __, ___, ____) {});

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveBackgroundNotificationResponse: onSelectNotification,
      onDidReceiveNotificationResponse: onSelectNotification,
    );
  }

  final NotificationAppLaunchDetails? notificationAppLaunchDetails =
      await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
  NotificationResponse? payload =
      notificationAppLaunchDetails?.notificationResponse;
  String? response = await payload?.payload;
  return response;
}

onSelectNotification(NotificationResponse notificationResponse) async {
  String? payloadData = notificationResponse.payload;
  notificationPayload = payloadData;
  runNotificationPayLoadsNoContext();
}

runNotificationPayLoadsNoContext() {
  if (navigatorKey.currentContext == null) return;
  // If the upcoming transaction notification tapped when app opened, auto pay overdue transaction
  if (notificationPayload == "upcomingTransaction") {
    Future.delayed(Duration.zero, () async {
      await markSubscriptionsAsPaid(navigatorKey.currentContext!);
      await markUpcomingAsPaid();
      await setUpcomingNotifications(navigatorKey.currentContext);
    });
  }
  runNotificationPayLoads(navigatorKey.currentContext);
}

Future<bool> runNotificationPayLoads(context) async {
  print("Notification payload: " + notificationPayload.toString());
  if (kIsWeb) return false;
  if (notificationPayload == null) return false;
  
  // 处理即将到来的交易通知
  if (notificationPayload == "upcomingTransaction") {
    // When the notification comes in, the transaction is past due!
    pushRoute(
      context,
      UpcomingOverdueTransactions(overdueTransactions: null),
    );
    return true;
  } else if (notificationPayload?.split("?")[0] == "openTransaction") {
    Uri notificationPayloadUri = Uri.parse(notificationPayload ?? "");
    if (notificationPayloadUri.queryParameters["transactionPk"] == null)
      return false;
    String transactionPk = 
        notificationPayloadUri.queryParameters["transactionPk"] ?? "";
    Transaction? transaction = 
        await database.getTransactionFromPk(transactionPk);
    pushRoute(
      context,
      AddTransactionPage(
        transaction: transaction,
        routesToPopAfterDelete: RoutesToPopAfterDelete.One,
      ),
    );
    return true;
  } else {
    // 处理自动交易通知，payload是JSON格式
    try {
      Map<String, dynamic> payloadData = jsonDecode(notificationPayload!);
      if (payloadData["type"] == "addTransaction") {
        double amount = double.parse(payloadData["amount"] ?? "0");
        String? title = payloadData["title"];
        String? templatePk = payloadData["templatePk"];
        String? dateStr = payloadData["date"];
        DateTime? selectedDate = dateStr != null ? DateTime.parse(dateStr) : null;
        
        // 获取模板信息
        ScannerTemplate? template;
        if (templatePk != null) {
          try {
            template = await database.getScannerTemplateInstance(templatePk);
          } catch (e) {
            print("Error getting scanner template: " + e.toString());
          }
        }
        
        // 获取钱包信息
        TransactionWallet? wallet;
        if (template != null && template.walletFk != "-1") {
          wallet = await database.getWalletInstanceOrNull(template.walletFk);
        }
        
        // 获取类别信息
        TransactionCategory? category;
        if (title != null) {
          TransactionAssociatedTitleWithCategory? foundTitle = 
              (await database.getSimilarAssociatedTitles(title: title, limit: 1)).firstOrNull;
          category = foundTitle?.category;
        }
        
        if (category == null && template != null) {
          category = await database.getCategoryInstanceOrNull(template.defaultCategoryFk);
        }
        
        pushRoute(
          context,
          AddTransactionPage(
            useCategorySelectedIncome: true,
            routesToPopAfterDelete: RoutesToPopAfterDelete.None,
            selectedAmount: amount,
            selectedTitle: title,
            selectedCategory: category,
            startInitialAddTransactionSequence: false,
            selectedWallet: wallet,
            selectedDate: selectedDate,
          ),
        );
        return true;
      }
    } catch (e) {
      print("Error parsing notification payload: " + e.toString());
    }
  }
  notificationPayload = "";
  return false;
}



Future<void> setUpcomingNotifications(context) async {
  if (kIsWeb) return;
  bool upcomingTransactionsNotificationsEnabled =
      appStateSettings["notificationsUpcomingTransactions"] == true;
  if (upcomingTransactionsNotificationsEnabled) {
    try {
      await scheduleUpcomingTransactionsNotification(context);
    } catch (e) {
      print(e.toString() +
          " Error setting up notifications for upcoming transactions");
    }
  }
  return;
}
