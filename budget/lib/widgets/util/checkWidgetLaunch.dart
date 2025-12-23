import 'dart:async';
import 'package:budget/colors.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/pages/addTransactionPage.dart';
import 'package:budget/pages/transactionFilters.dart';
import 'package:budget/pages/walletDetailsPage.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/openBottomSheet.dart';
import 'package:budget/widgets/openPopup.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';
import 'package:budget/pages/addWalletPage.dart';
import "package:budget/struct/throttler.dart";

// 扩展DateTime类，添加startOfDay和endOfDay方法
extension DateTimeExtensions on DateTime {
  DateTime startOfDay() {
    return DateTime(year, month, day, 0, 0, 0, 0, 0);
  }
  
  DateTime endOfDay() {
    return DateTime(year, month, day, 23, 59, 59, 999, 999);
  }
}

class AndroidOnly extends StatelessWidget {
  const AndroidOnly({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (getPlatform(ignoreEmulation: true) != PlatformOS.isAndroid)
      return SizedBox.shrink();
    return child;
  }
}

class CheckWidgetLaunch extends StatefulWidget {
  const CheckWidgetLaunch({super.key});

  @override
  State<CheckWidgetLaunch> createState() => _CheckWidgetLaunchState();
}

Throttler widgetActionThrottler =
    Throttler(duration: Duration(milliseconds: 350));

class _CheckWidgetLaunchState extends State<CheckWidgetLaunch> {
  @override
  void initState() {
    super.initState();
    HomeWidget.setAppGroupId('WIDGET_GROUP_ID');
    Future.delayed(Duration(milliseconds: 50), () {
      _checkForWidgetLaunch();
    });
    HomeWidget.widgetClicked.listen(_launchedFromWidget);
  }

  void _checkForWidgetLaunch() {
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_launchedFromWidget);
  }

  // For some reason, older Android versions open an entirely new app instance... weird!
  // has this been fixed with: android:launchMode="singleInstance" ?
  void _launchedFromWidget(Uri? uri) async {
    // Only perform one widget action per launch/continue of the app
    if (!widgetActionThrottler.canProceed()) return;

    String widgetPayload = (uri ?? "").toString();
    if (widgetPayload == "addTransactionWidget") {
      // Add a delay so the keyboard can focus
      Future.delayed(Duration(milliseconds: 50), () {
        pushRoute(
          context,
          AddTransactionPage(
            routesToPopAfterDelete: RoutesToPopAfterDelete.None,
          ),
        );
      });
    } else if (widgetPayload == "addTransactionIncomeWidget") {
      // Add a delay so the keyboard can focus
      Future.delayed(Duration(milliseconds: 50), () {
        pushRoute(
          context,
          AddTransactionPage(
            routesToPopAfterDelete: RoutesToPopAfterDelete.None,
            selectedIncome: true,
          ),
        );
      });
    } else if (widgetPayload == "transferTransactionWidget") {
      // This fixes an issue on older versions of Android where the route would popup twice
      // We can detect when this is going to happen if the Provider is not yet loaded, so just pop
      // the route when this is called so the first time routing does not persist (i.e. we end with one route)
      if (Provider.of<AllWallets>(context, listen: false)
              .indexedByPk[appStateSettings["selectedWalletPk"]] ==
          null) popAllRoutes(context);

      openBottomSheet(
        context,
        fullSnap: true,
        TransferBalancePopup(
          allowEditWallet: true,
          wallet: Provider.of<AllWallets>(context, listen: false)
              .indexedByPk[appStateSettings["selectedWalletPk"]],
          showAllEditDetails: true,
        ),
      );
    } else if (widgetPayload == "netWorthLaunchWidget") {
      pushRoute(
        context,
        WalletDetailsPage(
          wallet: null,
        ),
      );
    } else if (widgetPayload == "monthlyExpenseLaunchWidget") {
      pushRoute(
        context,
        WalletDetailsPage(
          wallet: null,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.shrink();
  }
}

class RenderHomePageWidgets extends StatefulWidget {
  const RenderHomePageWidgets({super.key});

  @override
  State<RenderHomePageWidgets> createState() => RenderHomePageWidgetsState();
}

Future updateWidgetColorsAndText(BuildContext context) async {
  if (getPlatform(ignoreEmulation: true) != PlatformOS.isAndroid) return;
  
  // Remove delay to ensure immediate updates when theme changes
  double widgetBackgroundOpacity = 
      (double.tryParse((appStateSettings["widgetOpacity"] ?? 1).toString()) ?? 1)
          .clamp(0, 1);
  
  // Ensure widgetTheme correctly reflects the current brightness
  // especially when app theme is set to "system"
  ThemeData widgetTheme;
  if (appStateSettings["widgetTheme"] == "light") {
    widgetTheme = getLightTheme();
  } else if (appStateSettings["widgetTheme"] == "dark") {
    widgetTheme = getDarkTheme();
  } else {
    // For "app" theme, use the current context's theme which already reflects system changes
    widgetTheme = Theme.of(context);
  }

  // Debug logging to track theme and color changes
  print("Updating widget colors - Theme brightness: ${widgetTheme.brightness}");
  print("Widget text color: ${widgetTheme.colorScheme.onSecondaryContainer}");
  print("Widget background color: ${widgetTheme.colorScheme.secondaryContainer}");

  await HomeWidget.saveWidgetData<String>('netWorthTitle', "net-worth".tr());
  await HomeWidget.saveWidgetData<String>('monthlyExpenseTitle', "monthly-expense".tr());
  await HomeWidget.saveWidgetData<String>('monthlyIncomeTitle', "monthly-income".tr());
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
  
  // Update all widgets to ensure consistent color across all widgets
  List<String> widgetProviders = [
    'NetWorthWidgetProvider',
    'NetWorthPlusWidgetProvider',
    'PlusWidgetProvider',
    'MinusWidgetProvider',
    'TransferWidgetProvider',
    'MonthlyExpenseWidgetProvider',
    'MonthlyIncomeWidgetProvider',
    'DailyExpenseWidgetProvider',
    'DailyIncomeWidgetProvider',
  ];
  
  for (String widgetName in widgetProviders) {
    await HomeWidget.updateWidget(name: widgetName);
  }
  
  return;
}

class RenderHomePageWidgetsState extends State<RenderHomePageWidgets> {
  // Track the current brightness to detect changes
  Brightness? currentBrightness;
  // Track the current theme setting to detect changes
  String? currentThemeSetting;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () async {
      updateWidgetColorsAndText(context);
      // Initialize current brightness and theme setting
      currentBrightness = Theme.of(context).brightness;
      currentThemeSetting = appStateSettings["theme"];
    });
  }

  void refreshState() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Check if theme or brightness has changed
    bool hasThemeChanged = currentThemeSetting != appStateSettings["theme"];
    bool hasBrightnessChanged = currentBrightness != Theme.of(context).brightness;
    
    if (hasThemeChanged || hasBrightnessChanged) {
      // Update current values
      currentThemeSetting = appStateSettings["theme"];
      currentBrightness = Theme.of(context).brightness;
      // Update widget colors when theme or brightness changes
      updateWidgetColorsAndText(context);
    }
    return StreamBuilder<List<TransactionWallet>>(
      stream: database.getAllPinnedWallets(HomePageWidgetDisplay.NetWorth).$1,
      builder: (context, snapshot) {
        List<String>? walletPks =
            (snapshot.data ?? []).map((item) => item.walletPk).toList();
        if (walletPks.length <= 0 ||
            appStateSettings["netWorthAllWallets"] == true) walletPks = null;
        return Column(
          children: [
            // Net worth widget data update
            StreamBuilder<TotalWithCount?>(
              stream: database.watchTotalWithCountOfWallet(
                isIncome: null,
                allWallets: Provider.of<AllWallets>(context),
                followCustomPeriodCycle: true,
                cycleSettingsExtension: "NetWorth",
                searchFilters: SearchFilters(walletPks: walletPks ?? []),
              ),
              builder: (context, snapshot) {
                Future.delayed(Duration.zero, () async {
                  int totalCount = snapshot.data?.count ?? 0;
                  String netWorthTransactionsNumber = totalCount.toString() +
                      " " +
                      (totalCount == 1
                          ? "transaction".tr().toLowerCase()
                          : "transactions".tr().toLowerCase());
                  double totalSpent = snapshot.data?.total ?? 0;
                  String netWorthAmount = convertToMoney(
                    Provider.of<AllWallets>(context, listen: false),
                    totalSpent,
                  );
                  await HomeWidget.saveWidgetData<String>(
                    'netWorthAmount',
                    netWorthAmount,
                  );
                  await HomeWidget.saveWidgetData<String>(
                    'netWorthTransactionsNumber',
                    netWorthTransactionsNumber,
                  );
                  await HomeWidget.updateWidget(
                    name: 'NetWorthWidgetProvider',
                  );
                  await HomeWidget.updateWidget(
                    name: 'NetWorthPlusWidgetProvider',
                  );
                });

                return const SizedBox.shrink();
              },
            ),
            // Monthly expense widget data update
            StreamBuilder<TotalWithCount?>(
              stream: database.watchTotalWithCountOfWallet(
                isIncome: false, // Filter for expenses only
                allWallets: Provider.of<AllWallets>(context),
                startDate: DateTime.now().firstDayOfMonth(),
                forcedDateTimeRange: DateTimeRange(
                  start: DateTime.now().firstDayOfMonth(),
                  end: DateTime.now().lastDayOfMonth(),
                ),
                followCustomPeriodCycle: false,
                searchFilters: SearchFilters(expenseIncome: [ExpenseIncome.expense]),
              ),
              builder: (context, snapshotExpense) {
                Future.delayed(Duration.zero, () async {
                  int totalCount = snapshotExpense.data?.count ?? 0;
                  String monthlyExpenseTransactionsNumber = totalCount.toString() +
                      " " +
                      (totalCount == 1
                          ? "transaction".tr().toLowerCase()
                          : "transactions".tr().toLowerCase());
                  double totalExpense = snapshotExpense.data?.total ?? 0;
                  // Ensure it shows as positive amount for display
                  double displayExpense = totalExpense.abs();
                  String monthlyExpenseAmount = convertToMoney(
                    Provider.of<AllWallets>(context, listen: false),
                    displayExpense,
                  );
                  
                  await HomeWidget.saveWidgetData<String>(
                    'monthlyExpenseAmount',
                    monthlyExpenseAmount,
                  );
                  await HomeWidget.saveWidgetData<String>(
                    'monthlyExpenseTransactionsNumber',
                    monthlyExpenseTransactionsNumber,
                  );
                  await HomeWidget.updateWidget(
                    name: 'MonthlyExpenseWidgetProvider',
                  );
                });

                return const SizedBox.shrink();
              },
            ),
            // Monthly income widget data update
            StreamBuilder<TotalWithCount?>(
              stream: database.watchTotalWithCountOfWallet(
                isIncome: true, // Filter for income only
                allWallets: Provider.of<AllWallets>(context),
                startDate: DateTime.now().firstDayOfMonth(),
                forcedDateTimeRange: DateTimeRange(
                  start: DateTime.now().firstDayOfMonth(),
                  end: DateTime.now().lastDayOfMonth(),
                ),
                followCustomPeriodCycle: false,
                searchFilters: SearchFilters(expenseIncome: [ExpenseIncome.income]),
              ),
              builder: (context, snapshotIncome) {
                Future.delayed(Duration.zero, () async {
                  int totalCount = snapshotIncome.data?.count ?? 0;
                  String monthlyIncomeTransactionsNumber = totalCount.toString() +
                      " " +
                      (totalCount == 1
                          ? "transaction".tr().toLowerCase()
                          : "transactions".tr().toLowerCase());
                  double totalIncome = snapshotIncome.data?.total ?? 0;
                  // Ensure it shows as positive amount for display
                  double displayIncome = totalIncome.abs();
                  String monthlyIncomeAmount = convertToMoney(
                    Provider.of<AllWallets>(context, listen: false),
                    displayIncome,
                  );
                  
                  await HomeWidget.saveWidgetData<String>(
                    'monthlyIncomeAmount',
                    monthlyIncomeAmount,
                  );
                  await HomeWidget.saveWidgetData<String>(
                    'monthlyIncomeTransactionsNumber',
                    monthlyIncomeTransactionsNumber,
                  );
                  await HomeWidget.updateWidget(
                    name: 'MonthlyIncomeWidgetProvider',
                  );
                });

                return const SizedBox.shrink();
              },
            ),
            // Daily income widget data update
            StreamBuilder<TotalWithCount?>(
              stream: database.watchTotalWithCountOfWallet(
                isIncome: true, // Filter for income only
                allWallets: Provider.of<AllWallets>(context),
                startDate: DateTime.now().startOfDay(),
                forcedDateTimeRange: DateTimeRange(
                  start: DateTime.now().startOfDay(),
                  end: DateTime.now().endOfDay(),
                ),
                followCustomPeriodCycle: false,
                searchFilters: SearchFilters(expenseIncome: [ExpenseIncome.income]),
              ),
              builder: (context, snapshotDailyIncome) {
                Future.delayed(Duration.zero, () async {
                  int totalCount = snapshotDailyIncome.data?.count ?? 0;
                  String dailyIncomeTransactionsNumber = totalCount.toString() +
                      " " +
                      (totalCount == 1
                          ? "transaction".tr().toLowerCase()
                          : "transactions".tr().toLowerCase());
                  double totalIncome = snapshotDailyIncome.data?.total ?? 0;
                  // Ensure it shows as positive amount for display
                  double displayIncome = totalIncome.abs();
                  String dailyIncomeAmount = convertToMoney(
                    Provider.of<AllWallets>(context, listen: false),
                    displayIncome,
                  );
                  
                  await HomeWidget.saveWidgetData<String>(
                    'dailyIncomeAmount',
                    dailyIncomeAmount,
                  );
                  await HomeWidget.saveWidgetData<String>(
                    'dailyIncomeTransactionsNumber',
                    dailyIncomeTransactionsNumber,
                  );
                  await HomeWidget.updateWidget(
                    name: 'DailyIncomeWidgetProvider',
                  );
                });

                return const SizedBox.shrink();
              },
            ),
            // Daily expense widget data update
            StreamBuilder<TotalWithCount?>(
              stream: database.watchTotalWithCountOfWallet(
                isIncome: false, // Filter for expenses only
                allWallets: Provider.of<AllWallets>(context),
                startDate: DateTime.now().startOfDay(),
                forcedDateTimeRange: DateTimeRange(
                  start: DateTime.now().startOfDay(),
                  end: DateTime.now().endOfDay(),
                ),
                followCustomPeriodCycle: false,
                searchFilters: SearchFilters(expenseIncome: [ExpenseIncome.expense]),
              ),
              builder: (context, snapshotDailyExpense) {
                Future.delayed(Duration.zero, () async {
                  int totalCount = snapshotDailyExpense.data?.count ?? 0;
                  String dailyExpenseTransactionsNumber = totalCount.toString() +
                      " " +
                      (totalCount == 1
                          ? "transaction".tr().toLowerCase()
                          : "transactions".tr().toLowerCase());
                  double totalExpense = snapshotDailyExpense.data?.total ?? 0;
                  // Ensure it shows as positive amount for display
                  double displayExpense = totalExpense.abs();
                  String dailyExpenseAmount = convertToMoney(
                    Provider.of<AllWallets>(context, listen: false),
                    displayExpense,
                  );
                  
                  await HomeWidget.saveWidgetData<String>(
                    'dailyExpenseAmount',
                    dailyExpenseAmount,
                  );
                  await HomeWidget.saveWidgetData<String>(
                    'dailyExpenseTransactionsNumber',
                    dailyExpenseTransactionsNumber,
                  );
                  await HomeWidget.updateWidget(
                    name: 'DailyExpenseWidgetProvider',
                  );
                });

                return const SizedBox.shrink();
              },
            ),
          ],
        );
      },
    );
  }
}
