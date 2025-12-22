import 'package:budget/functions.dart';
import 'package:budget/pages/accountsPage.dart';
import 'package:budget/pages/autoTransactionsPageEmail.dart';
import 'package:budget/struct/currencyFunctions.dart';
import 'package:budget/struct/iconObjects.dart';
import 'package:budget/struct/keyboardIntents.dart';
import 'package:budget/struct/logging.dart';
import 'package:budget/widgets/fadeIn.dart';
import 'package:budget/struct/languageMap.dart';
import 'package:budget/struct/initializeBiometrics.dart';
import 'package:home_widget/home_widget.dart';
import 'package:flutter/foundation.dart';

import 'package:budget/widgets/util/onAppResume.dart';
import 'package:budget/widgets/util/watchForDayChange.dart';
import 'package:budget/widgets/watchAllWallets.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/struct/notificationsGlobal.dart';
import 'package:budget/widgets/navigationSidebar.dart';
import 'package:budget/widgets/globalLoadingProgress.dart';
import 'package:budget/struct/scrollBehaviorOverride.dart';
import 'package:budget/widgets/globalSnackbar.dart';
import 'package:budget/struct/initializeNotifications.dart';
import 'package:budget/widgets/navigationFramework.dart';
import 'package:budget/widgets/restartApp.dart';
import 'package:budget/struct/customDelayedCurve.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:budget/colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_preview/device_preview.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:easy_localization/easy_localization.dart';

// Requires hot restart when changed
bool enableDevicePreview = false && kDebugMode;
bool allowDebugFlags = true || kIsWeb;
bool allowDangerousDebugFlags = true;

void main() async {
  captureLogs(() async {
    WidgetsFlutterBinding.ensureInitialized();
    

    
    await EasyLocalization.ensureInitialized();
    sharedPreferences = await SharedPreferences.getInstance();
    database = await constructDb('db');
    notificationPayload = await initializeNotifications();
    entireAppLoaded = false;
    await loadCurrencyJSON();
    await loadLanguageNamesJSON();
    await initializeSettings();
    
    // Ensure Chinese is set as default language if system is Chinese
    String? userSettings = sharedPreferences.getString('userSettings');
    if (userSettings == null) {
      // First time launch, check if system is Chinese
      final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
      if (systemLocale.languageCode == 'zh') {
        await updateSettings("locale", "zh", updateGlobalState: false);
      }
    }
    
    tz.initializeTimeZones();
    final String? locationName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(locationName ?? "America/New_York"));
    iconObjects.sort((a, b) => (a.mostLikelyCategoryName ?? a.icon)
        .compareTo((b.mostLikelyCategoryName ?? b.icon)));
    setHighRefreshRate();
    runApp(
      DevicePreview(
        enabled: enableDevicePreview,
        builder: (context) => InitializeLocalizations(
          child: RestartApp(
            child: InitializeApp(key: appStateKey),
          ),
        ),
      ),
    );
  });
}

GlobalKey<_InitializeAppState> appStateKey = GlobalKey();
GlobalKey<PageNavigationFrameworkState> pageNavigationFrameworkKey =
    GlobalKey();

class InitializeApp extends StatefulWidget {
  InitializeApp({Key? key}) : super(key: key);

  @override
  State<InitializeApp> createState() => _InitializeAppState();
}

class _InitializeAppState extends State<InitializeApp> {
  void refreshAppState() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return App(key: ValueKey("Main App"));
  }
}

class App extends StatelessWidget {
  const App({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print("Rebuilt Material App");
    return MaterialApp(
      showPerformanceOverlay: kProfileMode,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale:
          enableDevicePreview ? DevicePreview.locale(context) : context.locale,
      shortcuts: shortcuts,
      actions: keyboardIntents,
      themeAnimationDuration: Duration(milliseconds: 400),
      themeAnimationCurve: CustomDelayedCurve(),
      key: ValueKey('CashewAppMain'),
      title: 'Cashew',
      theme: getLightTheme(),
      darkTheme: getDarkTheme(),
      scrollBehavior: ScrollBehaviorOverride(),
      themeMode: getSettingConstants(appStateSettings)["theme"],
      home: HandleWillPopScope(
        child: Stack(
          children: [
            Row(
              children: [
                NavigationSidebar(key: sidebarStateKey),
                Expanded(
                    child: Stack(
                  children: [
                    InitialPageRouteNavigator(),
                    GlobalSnackbar(key: snackbarKey),
                  ],
                )),
              ],
            ),

            GlobalLoadingIndeterminate(key: loadingIndeterminateKey),
            GlobalLoadingProgress(key: loadingProgressKey),
          ],
        ),
      ),
      builder: (context, child) {
        if (kReleaseMode) {
          ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
            return Container(color: Colors.transparent);
          };
        }

        Widget mainWidget = OnAppResume(
          updateGlobalAppLifecycleState: true,
          onAppResume: () async {
            await setHighRefreshRate();
            // 当应用从后台恢复时，更新桌面组件的主题
            if (getPlatform(ignoreEmulation: true) == PlatformOS.isAndroid) {
              // 导入 checkWidgetLaunch.dart 中的 updateWidgetColorsAndText 函数
              // 由于无法直接导入，我们将使用 HomeWidget 来更新组件
              // 实际上，我们需要确保 updateWidgetColorsAndText 函数在应用恢复时被调用
              // 这里我们可以通过广播或其他方式通知，但为了简单起见，我们将在 main.dart 中直接调用
              // 首先获取当前主题
              ThemeData widgetTheme = getSettingConstants(appStateSettings)["theme"] == ThemeMode.light
                  ? getLightTheme()
                  : getSettingConstants(appStateSettings)["theme"] == ThemeMode.dark
                      ? getDarkTheme()
                      : Theme.of(context);
              
              double widgetBackgroundOpacity = (double.tryParse((appStateSettings["widgetOpacity"] ?? 1).toString()) ?? 1).clamp(0, 1);
              
              // 更新组件颜色
              await HomeWidget.saveWidgetData<String>(
                'widgetColorBackground',
                colorToHex(widgetTheme.colorScheme.secondaryContainer),
              );
              await HomeWidget.saveWidgetData<String>(
                'widgetAlpha',
                widgetTheme.colorScheme.secondaryContainer
                    .withOpacity(widgetBackgroundOpacity)
                    .alpha
                    .toString(),
              );
              await HomeWidget.saveWidgetData<String>(
                'widgetColorPrimary',
                colorToHex(widgetTheme.colorScheme.primary),
              );
              await HomeWidget.saveWidgetData<String>(
                'widgetColorText',
                colorToHex(widgetTheme.colorScheme.onSecondaryContainer),
              );
              
              // 更新所有组件
              await HomeWidget.updateWidget(name: 'NetWorthWidgetProvider');
              await HomeWidget.updateWidget(name: 'NetWorthPlusWidgetProvider');
              await HomeWidget.updateWidget(name: 'PlusWidgetProvider');
              await HomeWidget.updateWidget(name: 'MinusWidgetProvider');
              await HomeWidget.updateWidget(name: 'TransferWidgetProvider');
              await HomeWidget.updateWidget(name: 'MonthlyExpenseWidgetProvider');
              await HomeWidget.updateWidget(name: 'MonthlyIncomeWidgetProvider');
              await HomeWidget.updateWidget(name: 'DailyExpenseWidgetProvider');
              await HomeWidget.updateWidget(name: 'DailyIncomeWidgetProvider');
            }
          },
          child: InitializeNotificationService(
            child: InitializeBiometrics(
              child: WatchForDayChange(
                child: WatchSelectedWalletPk(
                  child: WatchAllWallets(
                    child: child ?? SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
        );

        if (kIsWeb) {
          return FadeIn(
              duration: Duration(milliseconds: 1000), child: mainWidget);
        } else {
          return mainWidget;
        }
      },
      // ),
    );
  }
}
