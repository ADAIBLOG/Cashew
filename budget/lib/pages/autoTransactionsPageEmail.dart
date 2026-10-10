import 'dart:async';
import 'package:budget/database/tables.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:budget/pages/addEmailTemplate.dart';
import 'package:budget/pages/addTransactionPage.dart';
import 'package:budget/pages/editCategoriesPage.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/struct/notificationsGlobal.dart';
import 'package:budget/struct/initializeNotifications.dart';
import 'package:budget/widgets/button.dart';
import 'package:budget/widgets/globalSnackbar.dart';
import 'package:budget/widgets/navigationFramework.dart';
import 'package:budget/widgets/openContainerNavigation.dart';
import 'package:budget/widgets/openPopup.dart';
import 'package:budget/widgets/openSnackbar.dart';
import 'package:budget/widgets/notificationsSettings.dart';
import 'package:budget/widgets/framework/pageFramework.dart';
import 'package:budget/widgets/settingsContainers.dart';
import 'package:budget/widgets/statusBox.dart';
import 'package:budget/widgets/tappable.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:budget/functions.dart';

import 'addButton.dart';

Timer? _notificationHealthCheckTimer;

final int maxCapturedNotifications = 20;
List<String> recentCapturedNotifications = [];

const MethodChannel _notificationListenerNativeChannel =
    MethodChannel('com.budget.tracker_app/notification_listener');

Future<bool> forceRestartNotificationListenerService() async {
  try {
    return await _notificationListenerNativeChannel
            .invokeMethod<bool>('forceRestartNotificationListener') ??
        false;
  } catch (e) {
    return false;
  }
}

Future<bool> isNotificationAccessGrantedNative() async {
  try {
    return await _notificationListenerNativeChannel
            .invokeMethod<bool>('isNotificationAccessGranted') ??
        false;
  } catch (e) {
    return false;
  }
}

Future<void> openNotificationAccessSettingsNative() async {
  try {
    await _notificationListenerNativeChannel
        .invokeMethod('openNotificationAccessSettings');
  } catch (e) {}
}

Future<String?> getPendingNativeTransactionPayload() async {
  try {
    return await _notificationListenerNativeChannel
        .invokeMethod<String>('getPendingTransactionPayload');
  } catch (e) {
    return null;
  }
}

Future initNotificationScanning() async {
  if (getPlatform(ignoreEmulation: true) != PlatformOS.isAndroid) return;
  if (appStateSettings["notificationScanning"] != true) {
    _stopHealthCheck();
    return;
  }

  bool status = await isNotificationAccessGrantedNative();
  if (status == true) {
    _startHealthCheck();
  } else {
    // 权限失效时不要自动关闭开关（用户没操作，开关却自己关掉会让人困惑）。
    // 保持开启状态，回到前台时重新校验；权限恢复后原生服务自动继续检测。
    _stopHealthCheck();
  }
}

void _startHealthCheck() {
  _stopHealthCheck();
  if (appStateSettings["notificationScanning"] != true) return;

  _notificationHealthCheckTimer = Timer.periodic(
    const Duration(minutes: 5),
    (_) async {
      if (appStateSettings["notificationScanning"] != true ||
          getPlatform(ignoreEmulation: true) != PlatformOS.isAndroid) {
        _stopHealthCheck();
        return;
      }

      bool hasPermission = await isNotificationAccessGrantedNative();
      if (!hasPermission) {
        // 同上：不自动关闭开关，避免「自动交易」静默失效；回到前台时会重新校验
        _stopHealthCheck();
        return;
      }
    },
  );
}

void _stopHealthCheck() {
  _notificationHealthCheckTimer?.cancel();
  _notificationHealthCheckTimer = null;
}

Future<bool> requestReadNotificationPermission() async {
  bool status = await isNotificationAccessGrantedNative();
  if (status != true) {
    // 用户可能会被引导到系统设置页面；返回后由 onResume / 健康检查重新校验
    await openNotificationAccessSettingsNative();
    status = await isNotificationAccessGrantedNative();
  }
  return status;
}

// 原生服务捕获到通知后，回调此方法维护「捕获的通知」列表
void handleCapturedNativeNotification(String messageString) {
  recentCapturedNotifications.insert(0, messageString);
  if (recentCapturedNotifications.length > maxCapturedNotifications) {
    recentCapturedNotifications =
        recentCapturedNotifications.sublist(0, maxCapturedNotifications);
  }
}

// 注册原生 -> Dart 的方法回调：捕获通知列表、点击提醒后的 payload
void _setupNativeChannelHandler() {
  _notificationListenerNativeChannel.setMethodCallHandler((call) async {
    if (call.method == "onNotificationCaptured") {
      handleCapturedNativeNotification(call.arguments as String? ?? "");
    } else if (call.method == "onTransactionPayload") {
      notificationPayload = call.arguments as String? ?? "";
      runNotificationPayLoadsNoContext();
    }
    return null;
  });
}

class InitializeNotificationService extends StatefulWidget {
  const InitializeNotificationService({required this.child, super.key});
  final Widget child;

  @override
  State<InitializeNotificationService> createState() =>
      _InitializeNotificationServiceState();
}

class _InitializeNotificationServiceState
    extends State<InitializeNotificationService> with WidgetsBindingObserver {
  AppLifecycleState? _lastState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupNativeChannelHandler();
    Future.delayed(Duration.zero, () async {
      initNotificationScanning();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_lastState == null) {
      _lastState = state;
    }

    if (state == AppLifecycleState.resumed &&
        (_lastState == AppLifecycleState.paused ||
            _lastState == AppLifecycleState.inactive)) {
      _onAppResumed();
    }

    _lastState = state;
  }

  Future<void> _onAppResumed() async {
    if (appStateSettings["notificationScanning"] != true) return;
    // 不再强制「禁用→启用」监听组件：该操作在部分系统上会撤销通知使用权，
    // 这正是「开关自动被关闭」的元凶之一。监听服务本身是前台常驻，无需强制重绑。
    initNotificationScanning();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

// 手动处理捕获的通知：匹配模板后直接打开添加交易页
Future queueTransactionFromMessage(String messageString, {bool willPushRoute = true, DateTime? dateTime}) async {
  String? title;
  double? amountDouble;
  List<ScannerTemplate> scannerTemplates = await database.getAllScannerTemplates();
  ScannerTemplate? templateFound;

  for (ScannerTemplate scannerTemplate in scannerTemplates) {
    if (messageString.contains(scannerTemplate.contains)) {
      templateFound = scannerTemplate;
      // 如果是新模式（auto），不需要获取标题，只需要获取金额
      if (scannerTemplate.amountTransactionBefore != "auto" || scannerTemplate.amountTransactionAfter != "auto") {
        title = getTransactionTitleFromEmail(
            messageString,
            scannerTemplate.titleTransactionBefore,
            scannerTemplate.titleTransactionAfter);
      }
      amountDouble = getTransactionAmountFromEmail(
          messageString,
          scannerTemplate.amountTransactionBefore,
          scannerTemplate.amountTransactionAfter);
      break;
    }
  }

  if (templateFound == null || amountDouble == null) return false;

  if (willPushRoute) {
    TransactionCategory? category;
    TransactionCategory? subCategory;
    TransactionWallet? wallet = templateFound.walletFk == "-1"
        ? null
        : await database.getWalletInstanceOrNull(templateFound.walletFk);

    if (title != null) {
      TransactionAssociatedTitleWithCategory? foundTitle =
          (await database.getSimilarAssociatedTitles(title: title, limit: 1)).firstOrNull;
      category = foundTitle?.category;
    }

    if (category == null) {
      category = await database.getCategoryInstanceOrNull(templateFound.defaultCategoryFk);
      // 默认类别为子分类时，拆分为主分类+子分类
      if (category != null && category.mainCategoryPk != null) {
        TransactionCategory? mainCategory = await database
            .getCategoryInstanceOrNull(category.mainCategoryPk!);
        if (mainCategory != null) {
          subCategory = category;
          category = mainCategory;
        }
      }
    }

    pushRoute(
      null,
      AddTransactionPage(
        useCategorySelectedIncome: true,
        routesToPopAfterDelete: RoutesToPopAfterDelete.None,
        selectedAmount: amountDouble,
        selectedTitle: title,
        selectedCategory: category,
        selectedSubCategory: subCategory,
        startInitialAddTransactionSequence: false,
        selectedWallet: wallet,
        selectedDate: dateTime,
      ),
    );
  }
  return true;
}

class AutoTransactionsPageEmail extends StatefulWidget {
  const AutoTransactionsPageEmail({Key? key}) : super(key: key);

  @override
  State<AutoTransactionsPageEmail> createState() =>
      _AutoTransactionsPageEmailState();
}

class _AutoTransactionsPageEmailState extends State<AutoTransactionsPageEmail> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return PageFramework(
      dragDownToDismiss: true,
      title: "auto-transactions-title".tr(),
      actions: [
        RefreshButton(
          timeout: Duration.zero,
          onTap: () async {
            loadingIndeterminateKey.currentState?.setVisibility(true);
            setState(() {});
            loadingIndeterminateKey.currentState?.setVisibility(false);
          },
        ),
      ],
      listWidgets: [
        Padding(
          padding:
              const EdgeInsetsDirectional.only(bottom: 5, start: 20, end: 20),
          child: TextFont(
            text: "transactions-created-based-notifications".tr(),
            fontSize: 14,
            maxLines: 10,
          ),
        ),
        SettingsContainerSwitch(
          onSwitched: (value) async {
            if (value == true) {
              // 先请求权限，只有权限授予后才更新设置
              bool status = await requestReadNotificationPermission();
              if (status == true) {
                await updateSettings("notificationScanning", true,
                    updateGlobalState: false);
                initNotificationScanning();
              }
              // 如果权限被拒绝，不更新设置，保持为false
            } else {
              await updateSettings("notificationScanning", false,
                  updateGlobalState: false);
              _stopHealthCheck();
            }
          },
          title: "notification-transactions".tr(),
          description: "notification-transactions-description".tr(),
          initialValue: appStateSettings["notificationScanning"],
        ),
        StreamBuilder<List<ScannerTemplate>>(
          stream: database.watchAllScannerTemplates(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              if (snapshot.data!.length <= 0) {
                return Padding(
                  padding: const EdgeInsetsDirectional.all(5),
                  child: StatusBox(
                    title: "notification-configuration-missing".tr(),
                    description: "please-add-configuration".tr(),
                    icon: appStateSettings["outlinedIcons"]
                        ? Icons.warning_outlined
                        : Icons.warning_rounded,
                    color: Theme.of(context).colorScheme.error,
                  ),
                );
              }
              return Column(
                children: [
                  for (ScannerTemplate scannerTemplate in snapshot.data!)
                    ScannerTemplateEntry(
                      messagesList: recentCapturedNotifications,
                      scannerTemplate: scannerTemplate,
                    )
                ],
              );
            } else {
              return Container();
            }
          },
        ),
        OpenContainerNavigation(
          openPage: AddEmailTemplate(
            messagesList: recentCapturedNotifications,
          ),
          borderRadius: 15,
          button: (openContainer) {
            return Row(
              children: [
                Expanded(
                  child: AddButton(
                    margin: EdgeInsetsDirectional.only(
                      start: 15,
                      end: 15,
                      bottom: 9,
                      top: 4,
                    ),
                    onTap: openContainer,
                  ),
                ),
              ],
            );
          },
        ),
        SettingsContainerSwitch(
          onSwitched: (value) async {
            await updateSettings("notificationShowCapturedData", value,
                updateGlobalState: false);
          },
          title: "显示捕获的通知数据",
          description: "关闭此选项可以减少电量消耗，同时保持通知扫描功能",
          initialValue: appStateSettings["notificationShowCapturedData"] ?? true,
        ),
        if (appStateSettings["notificationShowCapturedData"] ?? true)
          EmailsList(
            messagesList: recentCapturedNotifications,
          ),
      ],
    );
  }
}

String? getTransactionTitleFromEmail(String messageString,
    String titleTransactionBefore, String titleTransactionAfter) {
  String? title;
  try {
    int startIndex = messageString.indexOf(titleTransactionBefore) +
        titleTransactionBefore.length;
    int endIndex = messageString.indexOf(titleTransactionAfter, startIndex);
    title = messageString.substring(startIndex, endIndex);
    title = title.replaceAll("\n", "");
    title = title.toLowerCase();
    title = title.capitalizeFirst;
  } catch (e) {}
  return title;
}

double? getTransactionAmountFromEmail(String messageString, String amountTransactionBefore, String amountTransactionAfter) {
  double? amountDouble;
  
  try {
    // 新的自动识别逻辑：如果模板中设置了amountTransactionBefore为"auto"，使用正则表达式匹配货币符号后的数字
    if (amountTransactionBefore == "auto" && amountTransactionAfter == "auto") {
      // 正则表达式：匹配常见货币符号(¥$€£)后的数字，支持小数点和千位分隔符
      RegExp amountRegex = RegExp(r'[¥$€£]\s*([\d,]+\.?\d*)');
      Match? match = amountRegex.firstMatch(messageString);
      
      if (match != null && match.groupCount >= 1) {
        String amountString = match.group(1)!;
        // 清理数字字符串：移除千位分隔符，只保留数字和小数点
        String cleanAmountString = amountString.replaceAll(RegExp(r','), '');
        amountDouble = double.tryParse(cleanAmountString);
      }
      
      // 如果没找到，尝试其他可能的格式，比如数字前面没有空格
      if (amountDouble == null) {
        RegExp altAmountRegex = RegExp(r'[¥$€£]([\d,]+\.?\d*)');
        Match? altMatch = altAmountRegex.firstMatch(messageString);
        if (altMatch != null && altMatch.groupCount >= 1) {
          String amountString = altMatch.group(1)!;
          String cleanAmountString = amountString.replaceAll(RegExp(r','), '');
          amountDouble = double.tryParse(cleanAmountString);
        }
      }
      
      // 如果没找到，尝试匹配数字后面带货币符号的情况（如：0.02元）
      if (amountDouble == null) {
        RegExp altAmountRegex2 = RegExp(r'([\d,]+\.?\d*)\s*[¥$€£元角分]');
        Match? altMatch2 = altAmountRegex2.firstMatch(messageString);
        if (altMatch2 != null && altMatch2.groupCount >= 1) {
          String amountString = altMatch2.group(1)!;
          String cleanAmountString = amountString.replaceAll(RegExp(r','), '');
          amountDouble = double.tryParse(cleanAmountString);
        }
      }
    } else {
      // 保持原有的模板匹配逻辑作为后备
      int startIndex = messageString.indexOf(amountTransactionBefore) + amountTransactionBefore.length;
      int endIndex = messageString.indexOf(amountTransactionAfter, startIndex);
      String amountString = messageString.substring(startIndex, endIndex);
      String cleanAmountString = amountString
          .replaceAll(RegExp(r'[\s]'), '')
          .replaceAll(RegExp(r'[¥$€£]'), '')
          .replaceAll(RegExp(r','), '');
      amountDouble = double.tryParse(cleanAmountString);
    }
  } catch (e) {
    print('Error parsing amount: $e');
  }
  
  return amountDouble;
}

class ScannerTemplateEntry extends StatelessWidget {
  const ScannerTemplateEntry({
    required this.scannerTemplate,
    required this.messagesList,
    super.key,
  });
  final ScannerTemplate scannerTemplate;
  final List<String> messagesList;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 15, end: 15, bottom: 10),
      child: OpenContainerNavigation(
        openPage: AddEmailTemplate(
          messagesList: messagesList,
          scannerTemplate: scannerTemplate,
        ),
        borderRadius: 15,
        button: (openContainer) {
          return Tappable(
            borderRadius: 15,
            color: Theme.of(context).colorScheme.secondaryContainer,
            onTap: openContainer,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                start: 7,
                end: 15,
                top: 5,
                bottom: 5,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      TextFont(
                        text: scannerTemplate.templateName,
                        fontWeight: FontWeight.bold,
                      ),
                    ],
                  ),
                  ButtonIcon(
                    onTap: () async {
                      DeletePopupAction? action = await openDeletePopup(
                        context,
                        title: "delete-template-question".tr(),
                        subtitle: scannerTemplate.templateName,
                      );
                      if (action == DeletePopupAction.Delete) {
                        await database.deleteScannerTemplate(
                            scannerTemplate.scannerTemplatePk);
                        popRoute(context);
                        openSnackbar(
                          SnackbarMessage(
                            title: "deleted-template".tr() + " " + scannerTemplate.templateName,
                            icon: Icons.delete,
                          ),
                        );
                      }
                    },
                    icon: appStateSettings["outlinedIcons"]
                        ? Icons.delete_outlined
                        : Icons.delete_rounded,
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class EmailsList extends StatelessWidget {
  const EmailsList({
    required this.messagesList,
    this.onTap,
    this.backgroundColor,
    super.key,
  });
  final List<String> messagesList;
  final Function(String)? onTap;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ScannerTemplate>>(
      stream: database.watchAllScannerTemplates(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          List<ScannerTemplate> scannerTemplates = snapshot.data!;
          List<Widget> messageTxt = [];
          for (String messageString in messagesList) {
            bool doesEmailContain = false;
            String? title;
            double? amountDouble;
            String? templateFound;

            for (ScannerTemplate scannerTemplate in scannerTemplates) {
              if (messageString.contains(scannerTemplate.contains)) {
                doesEmailContain = true;
                templateFound = scannerTemplate.templateName;
                title = getTransactionTitleFromEmail(
                    messageString,
                    scannerTemplate.titleTransactionBefore,
                    scannerTemplate.titleTransactionAfter);
                amountDouble = getTransactionAmountFromEmail(
                    messageString,
                    scannerTemplate.amountTransactionBefore,
                    scannerTemplate.amountTransactionAfter);
                break;
              }
            }

            messageTxt.add(
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 15, vertical: 5),
                child: Tappable(
                  borderRadius: 15,
                  color: doesEmailContain &&
                          (title == null || amountDouble == null)
                      ? Theme.of(context)
                          .colorScheme
                          .errorContainer
                          .withOpacity(0.5)
                      : doesEmailContain
                          ? Theme.of(context)
                              .colorScheme
                              .secondary
                              .withOpacity(0.3)
                          : backgroundColor ??
                              Theme.of(context).colorScheme.secondaryContainer,
                  onTap: () {
                    if (onTap != null) onTap!(messageString);
                    if (onTap == null)
                      queueTransactionFromMessage(messageString);
                  },
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsetsDirectional.symmetric(
                              horizontal: 20, vertical: 15),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              doesEmailContain &&
                                      (title == null || amountDouble == null)
                                  ? Padding(
                                      padding: const EdgeInsetsDirectional.only(
                                          bottom: 5),
                                      child: TextFont(
                                        text: "parsing-failed".tr(),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17,
                                      ),
                                    )
                                  : SizedBox(),
                              doesEmailContain
                                  ? templateFound == null
                                      ? TextFont(
                                          fontSize: 19,
                                          text: "template-not-found".tr(),
                                          maxLines: 10,
                                          fontWeight: FontWeight.bold,
                                        )
                                      : TextFont(
                                          fontSize: 19,
                                          text: templateFound,
                                          maxLines: 10,
                                          fontWeight: FontWeight.bold,
                                        )
                                  : SizedBox(),
                              doesEmailContain
                                  ? title == null
                                      ? TextFont(
                                          fontSize: 15,
                                          text: "title-not-found".tr(),
                                          maxLines: 10,
                                          fontWeight: FontWeight.bold,
                                        )
                                      : TextFont(
                                          fontSize: 15,
                                          text: "" + title,
                                          maxLines: 10,
                                          fontWeight: FontWeight.bold,
                                        )
                                  : SizedBox(),
                              doesEmailContain
                                  ? amountDouble == null
                                      ? Padding(
                                          padding: const EdgeInsetsDirectional.only(
                                              bottom: 8.0),
                                          child: TextFont(
                                            fontSize: 15,
                                            text: "amount-not-found".tr(),
                                            maxLines: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : Padding(
                                          padding: const EdgeInsetsDirectional.only(
                                              bottom: 8.0),
                                          child: TextFont(
                                            fontSize: 15,
                                            text: convertToMoney(
                                                Provider.of<AllWallets>(
                                                    context),
                                                amountDouble),
                                            maxLines: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                  : SizedBox(),
                              TextFont(
                                fontSize: 13,
                                text: messageString,
                                maxLines: 10,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          return Column(
            children: messageTxt,
          );
        } else {
          return Container(width: 100, height: 100, color: Colors.white);
        }
      },
    );
  }
}
