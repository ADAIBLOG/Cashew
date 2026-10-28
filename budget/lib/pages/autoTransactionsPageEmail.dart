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
bool _listenerRepairInProgress = false;
DateTime? _lastListenerRepairPrompt;

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

/// 读取原生侧的「真实」状态：
/// - granted: 系统设置里是否授予了通知使用权
/// - connected: NotificationListenerService 当前是否真的被系统绑定
///
/// 两者必须分开看。国产 ROM 的极限省电/后台清理会只解绑服务、不撤销权限，
/// 只看 granted 会得出「一切正常」的错误结论。
Future<Map<String, dynamic>> getNotificationListenerStatusNative() async {
  try {
    final Map<dynamic, dynamic>? status = await _notificationListenerNativeChannel
        .invokeMethod<Map<dynamic, dynamic>>('getNotificationListenerStatus');
    if (status == null) return <String, dynamic>{};
    return status.map<String, dynamic>(
      (dynamic key, dynamic value) => MapEntry(key.toString(), value),
    );
  } catch (e) {
    return <String, dynamic>{};
  }
}

Future<bool> isNotificationListenerConnectedNative() async {
  final Map<String, dynamic> status = await getNotificationListenerStatusNative();
  return status["connected"] == true;
}

Future<bool> requestNotificationListenerRebindNative() async {
  try {
    return await _notificationListenerNativeChannel
            .invokeMethod<bool>('requestNotificationListenerRebind') ??
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

  await ensureNotificationListenerConnected();
  _startHealthCheck();
}

/// 确保通知监听服务真的处于「已连接」状态，必要时请求系统重新绑定。
///
/// 修复的核心场景：HyperOS/MIUI 的极限省电或后台清理会把监听服务解绑，
/// 但「通知使用权」仍是开启状态。此时 `isNotificationAccessGrantedNative()`
/// 依然返回 true，旧代码因此什么都不做——重启应用也没用，只有在系统设置里
/// 关掉再打开通知使用权（触发系统重新绑定）才能恢复。
/// 这里改为检查原生侧的真实连接状态，并调用系统官方的 `requestRebind()` 恢复。
Future<bool> ensureNotificationListenerConnected({bool prompt = true}) async {
  if (_listenerRepairInProgress) {
    return isNotificationListenerConnectedNative();
  }
  if (getPlatform(ignoreEmulation: true) != PlatformOS.isAndroid) return false;
  if (appStateSettings["notificationScanning"] != true) return false;

  _listenerRepairInProgress = true;
  try {
    final Map<String, dynamic> status =
        await getNotificationListenerStatusNative();

    // 原生通道暂时不可用时不要误判成「权限丢失」去打扰用户
    if (status.isEmpty) return false;

    if (status["granted"] != true) {
      // 权限被系统收回时重绑没有意义，只能引导用户重新授予。
      // 健康检查继续保留，这样用户在系统设置里重新授予后无需重启应用。
      if (prompt) {
        await Future.delayed(const Duration(milliseconds: 500));
        _showListenerRepairHint();
      }
      return false;
    }

    if (status["connected"] == true) return true;

    // 冷启动或刚从后台回来时，系统绑定服务有延迟，先给一点时间再判定
    await Future.delayed(const Duration(milliseconds: 800));
    if (await isNotificationListenerConnectedNative()) return true;

    // 服务确实掉线：请求系统重新绑定。间隔要大于原生的请求冷却时间，
    // 避免第二次请求被本地限流直接丢掉。
    for (int attempt = 0; attempt < 2; attempt++) {
      if (attempt == 0) {
        await requestNotificationListenerRebindNative();
      } else {
        // 普通重绑没成功时，再走一次「解绑 → 重绑」的完整重连（API 34+）
        await forceRestartNotificationListenerService();
      }
      await Future.delayed(const Duration(seconds: 4));
      if (await isNotificationListenerConnectedNative()) return true;
    }

    // 极少数 ROM 会拒绝重绑（例如组件被系统禁用），退回到让用户手动修复。
    if (prompt) _showListenerRepairHint();
    return false;
  } finally {
    _listenerRepairInProgress = false;
  }
}

/// 重绑失败后的兜底提示：点击直达本应用的「通知使用权」详情页。
/// 文案复用已有翻译键，避免为一个提示新增几十种语言的翻译。
void _showListenerRepairHint() {
  final DateTime now = DateTime.now();
  if (_lastListenerRepairPrompt != null &&
      now.difference(_lastListenerRepairPrompt!) < const Duration(minutes: 10)) {
    return;
  }
  // 应用刚启动时 GlobalSnackbar 可能还没挂载，等下一次检查/回到前台再提示
  if (snackbarKey.currentState == null) return;
  _lastListenerRepairPrompt = now;
  openSnackbar(
    SnackbarMessage(
      title: "notification-transactions".tr(),
      description: "please-check-your-system-settings".tr(),
      icon: Icons.notifications_off_outlined,
      timeout: const Duration(seconds: 8),
      onTap: () => openNotificationAccessSettingsNative(),
    ),
  );
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

      // 权限被收回时不自动关开关（避免「自动交易」静默失效），
      // 但仍尝试恢复连接；提示留给启动/回前台时做，避免后台反复弹提示。
      await ensureNotificationListenerConnected(prompt: false);
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
    // 回到前台时系统可能刚把服务解绑（省电模式、后台清理），也可能刚授予权限。
    // initNotificationScanning 会检查真实连接状态并在需要时 requestRebind。
    await initNotificationScanning();
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
            // 手动重新检查监听服务是否还连着；掉线时尝试 requestRebind
            final bool connected =
                await ensureNotificationListenerConnected(prompt: false);
            loadingIndeterminateKey.currentState?.setVisibility(false);
            if (!connected) _showListenerRepairHint();
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
