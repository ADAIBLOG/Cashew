import 'dart:io';
import 'dart:math';

import 'package:budget/colors.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/pages/addTransactionPage.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/initializeNotifications.dart';
import 'package:budget/struct/notificationsGlobal.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/animatedExpanded.dart';
import 'package:budget/widgets/framework/popupFramework.dart';
import 'package:budget/widgets/openBottomSheet.dart';
import 'package:budget/widgets/openPopup.dart';
import 'package:budget/widgets/radioItems.dart';
import 'package:budget/widgets/settingsContainers.dart';
import 'package:budget/widgets/transactionEntry/transactionLabel.dart';
import 'package:budget/widgets/util/showTimePicker.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:budget/widgets/timeDigits.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

bool notificationsGlobalEnabled = kIsWeb == false;

enum ReminderNotificationType {
  IfAppNotOpened,
  DayFromOpen,
  Everyday,
}

class DailyNotificationsSettings extends StatefulWidget {
  const DailyNotificationsSettings({super.key});

  @override
  State<DailyNotificationsSettings> createState() =>
      _DailyNotificationsSettingsState();
}

class _DailyNotificationsSettingsState
    extends State<DailyNotificationsSettings> {
  bool notificationsEnabled = appStateSettings["notifications"];
  ReminderNotificationType selectedReminderType = ReminderNotificationType
      .values[appStateSettings["notificationsReminderType"]];
  TimeOfDay timeOfDay = TimeOfDay(
      hour: appStateSettings["notificationHour"],
      minute: appStateSettings["notificationMinute"]);

  @override
  Widget build(BuildContext context) {
    Map<ReminderNotificationType, String> reminderNotificationTypeTranslations =
        {
      ReminderNotificationType.IfAppNotOpened:
          "daily-notification-type-if-not-opened".tr().capitalizeFirst,
      ReminderNotificationType.DayFromOpen:
          "daily-notification-type-one-day-from-open".tr().capitalizeFirst,
      ReminderNotificationType.Everyday:
          "daily-notification-type-everyday".tr().toLowerCase().capitalizeFirst,
    };

    return Column(
      children: [
        SettingsContainerSwitch(
          title: "notifications-reminder".tr(),
          onSwitched: (value) async {
            await updateSettings("notifications", value,
                updateGlobalState: false);
            if (value == true) {
              await initializeNotificationsPlatform();
              await setDailyNotifications(context);
            } else {
              await cancelDailyNotification();
            }
            setState(() {
              notificationsEnabled = !notificationsEnabled;
            });
            return true;
          },
          initialValue: appStateSettings["notifications"],
          icon: notificationsEnabled
              ? appStateSettings["outlinedIcons"]
                  ? Icons.notifications_outlined
                  : Icons.notifications_rounded
              : appStateSettings["outlinedIcons"]
                  ? Icons.notifications_off_outlined
                  : Icons.notifications_off_rounded,
        ),
        AnimatedExpanded(
            expand: notificationsEnabled,
            child: Column(
              children: [
                SettingsContainer(
                  title: "notifications-reminder-type".tr(),
                  description: reminderNotificationTypeTranslations[
                      ReminderNotificationType.values[
                          appStateSettings["notificationsReminderType"]]],
                  onTap: () {
                    openBottomSheet(
                      context,
                      PopupFramework(
                        title: "notifications-reminder-type".tr(),
                        child: RadioItems(
                          items: ReminderNotificationType.values,
                          initial: ReminderNotificationType.values[
                              appStateSettings["notificationsReminderType"]],
                          displayFilter: (ReminderNotificationType value) {
                            return reminderNotificationTypeTranslations[
                                    value] ??
                                "";
                          },
                          onChanged: (ReminderNotificationType option) async {
                            await updateSettings(
                                "notificationsReminderType", option.index,
                                updateGlobalState: false);
                            setState(() {
                              selectedReminderType = option;
                            });
                            popRoute(context);
                          },
                        ),
                      ),
                    );
                  },
                  icon: appStateSettings["outlinedIcons"]
                      ? Icons.notification_important_outlined
                      : Icons.notification_important_rounded,
                ),
                AnimatedExpanded(
                  expand: selectedReminderType !=
                      ReminderNotificationType.DayFromOpen,
                  child: SettingsContainer(
                    key: ValueKey(1),
                    title: "alert-time".tr(),
                    icon: Icons.timer,
                    onTap: () async {
                      TimeOfDay? newTime =
                          await showCustomTimePicker(context, timeOfDay);
                      if (newTime != null) {
                        setState(() {
                          timeOfDay = newTime;
                        });
                        await updateSettings(
                          "notificationHour",
                          timeOfDay.hour,
                          pagesNeedingRefresh: [],
                          updateGlobalState: false,
                        );
                        await updateSettings(
                          "notificationMinute",
                          timeOfDay.minute,
                          pagesNeedingRefresh: [],
                          updateGlobalState: false,
                        );
                        await initializeNotificationsPlatform();
                        await setDailyNotifications(context);
                      }
                    },
                    afterWidget: TimeDigits(timeOfDay: timeOfDay),
                  ),
                ),
              ],
            )),
        Divider(
          indent: 20,
          endIndent: 20,
          thickness: 2,
          color: getColor(context, "dividerColor"),
        ),
      ],
    );
  }
}

class UpcomingTransactionsNotificationsSettings extends StatefulWidget {
  const UpcomingTransactionsNotificationsSettings({super.key});

  @override
  State<UpcomingTransactionsNotificationsSettings> createState() =>
      _UpcomingTransactionsNotificationsSettingsState();
}

class _UpcomingTransactionsNotificationsSettingsState
    extends State<UpcomingTransactionsNotificationsSettings> {
  bool notificationsEnabled =
      appStateSettings["notificationsUpcomingTransactions"];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SettingsContainerSwitch(
          title: "upcoming-transactions".tr(),
          onSwitched: (value) async {
            updateSettings("notificationsUpcomingTransactions", value,
                updateGlobalState: false);
            if (value == true) {
              await initializeNotificationsPlatform();
              await scheduleUpcomingTransactionsNotification(context);
            } else {
              await cancelUpcomingTransactionsNotification();
            }
            setState(() {
              notificationsEnabled = !notificationsEnabled;
            });
            return true;
          },
          initialValue: appStateSettings["notificationsUpcomingTransactions"],
          icon: appStateSettings["outlinedIcons"]
              ? Icons.calendar_month_outlined
              : Icons.calendar_month_rounded,
        ),
        IgnorePointer(
          ignoring: !notificationsEnabled,
          child: AnimatedOpacity(
            opacity: notificationsEnabled ? 1 : 0,
            duration: Duration(milliseconds: 300),
            child: Container(
              padding:
                  EdgeInsetsDirectional.symmetric(horizontal: 0, vertical: 0),
              margin:
                  EdgeInsetsDirectional.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadiusDirectional.circular(
                    getPlatform() == PlatformOS.isIOS ? 10 : 15),
                color: appStateSettings["materialYou"]
                    ? dynamicPastel(context,
                        Theme.of(context).colorScheme.secondaryContainer,
                        amountLight: 0, amountDark: 0.6)
                    : getColor(context, "lightDarkAccent"),
              ),
              child: ClipRRect(
                borderRadius: BorderRadiusDirectional.circular(
                    getPlatform() == PlatformOS.isIOS ? 10 : 15),
                child: StreamBuilder<List<Transaction>>(
                  stream: database.watchAllOverdueUpcomingTransactions(false),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return Column(
                        children: [
                          for (Transaction transaction in snapshot.data!)
                            StreamBuilder<TransactionCategory>(
                              stream: database
                                  .getCategory(transaction.categoryFk)
                                  .$1,
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  return SettingsContainerSwitch(
                                    onLongPress: () {
                                      pushRoute(
                                        context,
                                        AddTransactionPage(
                                          transaction: transaction,
                                          routesToPopAfterDelete:
                                              RoutesToPopAfterDelete.One,
                                        ),
                                      );
                                    },
                                    onTap: () {
                                      pushRoute(
                                        context,
                                        AddTransactionPage(
                                          transaction: transaction,
                                          routesToPopAfterDelete:
                                              RoutesToPopAfterDelete.One,
                                        ),
                                      );
                                    },
                                    icon: getTransactionTypeIcon(
                                        transaction.type),
                                    title: getTransactionLabelSync(
                                        transaction, snapshot.data!),
                                    description: getWordedDateShortMore(
                                            transaction.dateCreated) +
                                        ", " +
                                        getWordedTime(
                                            null, transaction.dateCreated),
                                    onSwitched: (value) async {
                                      await database.createOrUpdateTransaction(
                                          transaction.copyWith(
                                              upcomingTransactionNotification:
                                                  Value(value)));
                                      await initializeNotificationsPlatform();
                                      await scheduleUpcomingTransactionsNotification(
                                          context);
                                      return;
                                    },
                                    syncWithInitialValue: false,
                                    initialValue: transaction
                                            .upcomingTransactionNotification ??
                                        true,
                                  );
                                }
                                return Container();
                              },
                            )
                        ],
                      );
                    }
                    return SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

List<String> _reminderStrings = [
  for (int i = 1; i <= 26; i++) "notification-reminder-" + i.toString()
];

Future<bool> scheduleDailyNotification(
    BuildContext context, TimeOfDay timeOfDay,
    {bool scheduleNowDebug = false}) async {
  // 已隐藏"添加交易提醒"功能，此函数不再执行任何操作
  return false;
}

Future<bool> cancelDailyNotification() async {
  // 已隐藏"添加交易提醒"功能，此函数不再执行任何操作
  return true;
}

Future<bool> scheduleUpcomingTransactionsNotification(context) async {
  await cancelUpcomingTransactionsNotification();

  AndroidNotificationDetails androidNotificationDetails =
      AndroidNotificationDetails(
    'upcomingTransactions',
    'Upcoming Transactions',
    importance: Importance.max,
    priority: Priority.high,
    color: Theme.of(context).colorScheme.primary,
  );

  DarwinNotificationDetails darwinNotificationDetails =
      DarwinNotificationDetails(threadIdentifier: 'upcomingTransactions');

  List<Transaction> upcomingTransactions =
      await database.getAllUpcomingTransactions(
    startDate: DateTime.now().justDay(dayOffset: -1),
    endDate: DateTime.now().justDay(yearOffset: 1),
  );
  // print(upcomingTransactions);
  int idStart = 100;
  for (Transaction upcomingTransaction in upcomingTransactions) {
    idStart++;
    // Note: if upcomingTransactionNotification is NULL the loop will continue and schedule a notification
    if (upcomingTransaction.upcomingTransactionNotification == false) continue;
    if (upcomingTransaction.dateCreated.justDay() == DateTime.now().justDay() &&
        (upcomingTransaction.dateCreated.hour < DateTime.now().hour ||
            (upcomingTransaction.dateCreated.hour == DateTime.now().hour &&
                upcomingTransaction.dateCreated.minute <=
                    DateTime.now().minute))) {
      continue;
    }
    String chosenMessage = await getTransactionLabel(upcomingTransaction);
    tz.TZDateTime dateTime = tz.TZDateTime(
      tz.local,
      upcomingTransaction.dateCreated.year,
      upcomingTransaction.dateCreated.month,
      upcomingTransaction.dateCreated.day,
      upcomingTransaction.dateCreated.hour,
      upcomingTransaction.dateCreated.minute,
    );
    NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: darwinNotificationDetails,
    );
    if (upcomingTransaction.dateCreated.isAfter(DateTime.now())) {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        idStart,
        'notification-upcoming-transaction-title'.tr(),
        chosenMessage,
        dateTime,
        notificationDetails,
        androidAllowWhileIdle: true,
        payload: 'upcomingTransaction',
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,

        // If exact time was used, need USE_EXACT_ALARM and SCHEDULE_EXACT_ALARM permissions
        // which are only meant for calendar/reminder based applications
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } else {
      print("Cannot set up notification before current time!");
    }

    print("Notification " +
        chosenMessage +
        " scheduled for " +
        dateTime.toString() +
        " with id " +
        upcomingTransaction.transactionPk.toString());
  }

  return true;
}

Future<bool> cancelUpcomingTransactionsNotification() async {
  List<Transaction> upcomingTransactions =
      await database.getAllUpcomingTransactions(
    startDate: DateTime.now().justDay(dayOffset: -1),
    endDate: DateTime.now().justDay(dayOffset: 30),
  );
  int idStart = 100;
  for (Transaction upcomingTransaction in upcomingTransactions) {
    idStart++;
    await flutterLocalNotificationsPlugin.cancel(idStart);
  }
  print("Cancelled notifications for upcoming");
  return true;
}

tz.TZDateTime _nextInstanceOfSetTime(TimeOfDay timeOfDay, {int dayOffset = 0}) {
  final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
  // tz.TZDateTime scheduledDate = tz.TZDateTime(
  //     tz.local, now.year, now.month, now.day, timeOfDay.hour, timeOfDay.minute);
  // if (scheduledDate.isBefore(now)) {
  //   scheduledDate = scheduledDate.add(const Duration(days: 1));
  // }

  // add one to current day (if app wasn't opened, it will notify)
  tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month,
      now.day + dayOffset, timeOfDay.hour, timeOfDay.minute);

  return scheduledDate;
}

Future<bool> initializeNotificationsPlatform() async {
  if (kIsWeb || Platform.isLinux) {
    return false;
  }
  bool result = await checkNotificationsPermissionAll();
  if (result) {
    print("Notifications initialized");
    return true;
  } else {
    return false;
  }
}

Future<bool> checkNotificationsPermissionIOS() async {
  bool? result = await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>()
      ?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
  if (result != true) return false;
  return true;
}

Future<bool> checkNotificationsPermissionAndroid() async {
  try {
    // 获取Android版本信息
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    int sdkInt = androidInfo.version.sdkInt;
    
    if (sdkInt >= 33) {
      // Android 13+ 处理 POST_NOTIFICATIONS 权限
      bool? result = await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      return result ?? false;
    } else {
      // 旧版Android不需要单独请求通知权限
      return true;
    }
  } catch (e) {
    print("Error checking Android notification permission: $e");
    return false;
  }
}

Future<bool> checkNotificationsPermissionAll() async {
  try {
    if (Platform.isAndroid) return await checkNotificationsPermissionAndroid();
    if (Platform.isIOS) return await checkNotificationsPermissionIOS();
  } catch (e) {
    print("Error setting up notifications: " + e.toString());
    return false;
  }
  return false;
}
