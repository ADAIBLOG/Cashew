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

// 注册原生 -> Dart 的方法回调：点击提醒后的 payload
void _setupNativeChannelHandler() {
  _notificationListenerNativeChannel.setMethodCallHandler((call) async {
    if (call.method == "onTransactionPayload") {
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
                return true;
              }
              // 权限未授予：返回 false，让开关保持原始位置，
              // 避免「视觉上已打开、实际没保存」导致之后弹回关闭
              return false;
            } else {
              await updateSettings("notificationScanning", false,
                  updateGlobalState: false);
              _stopHealthCheck();
              return true;
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
          openPage: AddEmailTemplate(),
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
      ],
    );
  }
}

class ScannerTemplateEntry extends StatelessWidget {
  const ScannerTemplateEntry({
    required this.scannerTemplate,
    super.key,
  });
  final ScannerTemplate scannerTemplate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 15, end: 15, bottom: 10),
      child: OpenContainerNavigation(
        openPage: AddEmailTemplate(
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
