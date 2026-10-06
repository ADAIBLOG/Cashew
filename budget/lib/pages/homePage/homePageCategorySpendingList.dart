import 'package:budget/colors.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/pages/editHomePage.dart';
import 'package:budget/pages/homePage/homePagePieChart.dart';
import 'package:budget/pages/transactionFilters.dart';
import 'package:budget/pages/transactionsSearchPage.dart';
import 'package:budget/pages/walletDetailsPage.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/struct/spendingSummaryHelper.dart';
import 'package:budget/widgets/incomeExpenseTabSelector.dart';
import 'package:budget/widgets/navigationFramework.dart';
import 'package:budget/widgets/tappable.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:budget/widgets/util/keepAliveClientMixin.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomePageCategorySpendingList extends StatefulWidget {
  const HomePageCategorySpendingList({super.key});

  @override
  State<HomePageCategorySpendingList> createState() =>
      _HomePageCategorySpendingListState();
}

class _HomePageCategorySpendingListState
    extends State<HomePageCategorySpendingList> {
  bool isIncome = false;
  bool showToday = true;

  void openSettings() async {
    await openCategorySpendingListSettings(context);
    homePageStateKey.currentState?.refreshState();
  }

  @override
  Widget build(BuildContext context) {
    final bool showTodayActive = appStateSettings[
            "showTodayCategorySpendingList"] ==
        true && showToday;
    final bool showTodayCategorySpendingList =
        appStateSettings["showTodayCategorySpendingList"] == true;
    const double borderRadius = 15;
    return KeepAliveClientMixin(
      child: Padding(
        padding:
            const EdgeInsetsDirectional.only(bottom: 13, start: 13, end: 13),
        child: Container(
          decoration: BoxDecoration(
            boxShadow: boxShadowCheck(boxShadowGeneral(context)),
            borderRadius: BorderRadiusDirectional.circular(borderRadius),
          ),
          child: ClipRRect(
            borderRadius: BorderRadiusDirectional.circular(borderRadius),
            child: Tappable(
              borderRadius: borderRadius,
              onLongPress: openSettings,
              color: getColor(context, "lightDarkAccentHeavyLight"),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showTodayCategorySpendingList)
                    TodayPeriodPieChartSelector(
                      showToday: showToday,
                      cycleSettingsExtension: "CategorySpendingList",
                      onChanged: (value) {
                        setState(() {
                          showToday = value;
                        });
                      },
                    ),
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                        13, 13, 13, 5),
                    child: IncomeExpenseTabSelector(
                      initialTabIsIncome: false,
                      showIcons: true,
                      onTabChanged: (value) {
                        setState(() {
                          isIncome = value;
                        });
                      },
                    ),
                  ),
                  CategorySpendingTextList(
                      isIncome: isIncome, showToday: showTodayActive),
                  SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CategorySpendingTextList extends StatefulWidget {
  const CategorySpendingTextList(
      {required this.isIncome, required this.showToday, super.key});
  final bool isIncome;
  final bool showToday;

  @override
  State<CategorySpendingTextList> createState() =>
      _CategorySpendingTextListState();
}

class _CategorySpendingTextListState extends State<CategorySpendingTextList> {
  // 缓存 stream，避免每次 build（包括设置开关触发的全量重建）都重新订阅数据库
  late final Stream<List<TransactionWallet>> _pinnedWalletsStream = database
      .getAllPinnedWallets(HomePageWidgetDisplay.CategorySpendingList)
      .$1;

  Stream<List<CategoryWithTotal>>? _totalSpentStream;
  String? _totalSpentStreamKey;

  Stream<List<CategoryWithTotal>> _getTotalSpentStream(
      BuildContext context, List<String>? walletPks) {
    AllWallets allWallets = Provider.of<AllWallets>(context);
    String key = [
      walletPks?.join(",") ?? "all",
      widget.isIncome,
      widget.showToday,
      appStateSettings["categorySpendingListAllWallets"],
      appStateSettings["categorySpendingListIncomeAndExpenseOnly"],
      allWallets.hashCode,
    ].join("|");
    if (_totalSpentStream == null || _totalSpentStreamKey != key) {
      _totalSpentStreamKey = key;
      _totalSpentStream =
          database.watchTotalSpentInEachCategoryInTimeRangeFromCategories(
        allWallets: allWallets,
        start: DateTime.now(),
        end: DateTime.now(),
        categoryFks: null,
        categoryFksExclude: null,
        budgetTransactionFilters: null,
        memberTransactionFilters: null,
        allTime: widget.showToday ? false : true,
        walletPks: walletPks,
        isIncome: widget.isIncome,
        followCustomPeriodCycle: widget.showToday ? false : true,
        cycleSettingsExtension: "CategorySpendingList",
        countUnassignedTransactions: true,
        includeAllSubCategories: true,
        searchFilters: SearchFilters(expenseIncome: [
          if (appStateSettings["categorySpendingListIncomeAndExpenseOnly"] ==
              true)
            (widget.isIncome == true
                ? ExpenseIncome.income
                : ExpenseIncome.expense)
        ]),
      );
    }
    return _totalSpentStream!;
  }

  @override
  Widget build(BuildContext context) {
    AllWallets allWallets = Provider.of<AllWallets>(context);
    return StreamBuilder<List<TransactionWallet>>(
      stream: _pinnedWalletsStream,
      builder: (context, snapshot) {
        if (snapshot.hasData ||
            appStateSettings["categorySpendingListAllWallets"] == true) {
          List<String>? walletPks =
              (snapshot.data ?? []).map((item) => item.walletPk).toList();
          if (walletPks.length <= 0 ||
              appStateSettings["categorySpendingListAllWallets"] == true) {
            walletPks = null;
          }
          return StreamBuilder<List<CategoryWithTotal>>(
            stream: _getTotalSpentStream(context, walletPks),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                TotalSpentCategoriesSummary s =
                    watchTotalSpentInTimeRangeHelper(
                  dataInput: snapshot.data ?? [],
                  showAllSubcategories: false,
                  multiplyTotalBy: 1,
                  absoluteTotal: true,
                );
                List<CategoryWithTotal> items =
                    [...s.dataFilterUnassignedTransactions]
                      ..sort((a, b) => b.total.abs().compareTo(a.total.abs()));
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsetsDirectional.all(20),
                    child: TextFont(
                      text: widget.isIncome
                          ? appStateSettings[
                                      "categorySpendingListIncomeAndExpenseOnly"] ==
                                  true
                              ? "no-income-within-period".tr()
                              : "no-incoming-within-period".tr()
                          : appStateSettings[
                                      "categorySpendingListIncomeAndExpenseOnly"] ==
                                  true
                              ? "no-expense-within-period".tr()
                              : "no-outgoing-within-period".tr(),
                      textAlign: TextAlign.center,
                      maxLines: 20,
                      fontSize: 17,
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (CategoryWithTotal item in items)
                      CategorySpendingRow(
                        categoryWithTotal: item,
                        totalSpent: s.totalSpent,
                        allWallets: allWallets,
                        isIncome: widget.isIncome,
                        showToday: widget.showToday,
                      ),
                  ],
                );
              }
              return SizedBox.shrink();
            },
          );
        }
        return SizedBox.shrink();
      },
    );
  }
}

class CategorySpendingRow extends StatelessWidget {
  const CategorySpendingRow({
    required this.categoryWithTotal,
    required this.totalSpent,
    required this.allWallets,
    required this.isIncome,
    required this.showToday,
    super.key,
  });
  final CategoryWithTotal categoryWithTotal;
  final double totalSpent;
  final AllWallets allWallets;
  final bool isIncome;
  final bool showToday;

  @override
  Widget build(BuildContext context) {
    TransactionCategory category = categoryWithTotal.category;
    double percent = totalSpent == 0
        ? 0
        : categoryWithTotal.total.abs() / totalSpent * 100;

    return Tappable(
      borderRadius: 15,
      color: Colors.transparent,
      onTap: () {
        pushRoute(
          context,
          TransactionsSearchPage(
            initialFilters: SearchFilters().copyWith(
              dateTimeRange: showToday
                  ? DateTimeRange(
                      start: DateTime.now().justDay(),
                      end: DateTime.now()
                          .justDay(dayOffset: 1)
                          .subtract(const Duration(milliseconds: 1)),
                    )
                  : getDateTimeRangeForPassedSearchFilters(
                      cycleSettingsExtension: "CategorySpendingList"),
              categoryPks: [category.mainCategoryPk ?? category.categoryPk],
              positiveCashFlow: appStateSettings[
                          "categorySpendingListIncomeAndExpenseOnly"] ==
                      true
                  ? null
                  : isIncome,
              expenseIncome: [
                if (appStateSettings["categorySpendingListIncomeAndExpenseOnly"] == true)
                  (isIncome == true
                      ? ExpenseIncome.income
                      : ExpenseIncome.expense)
              ],
            ),
          ),
        );
      },
      child: Padding(
        padding:
            const EdgeInsetsDirectional.symmetric(horizontal: 15, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: HexColor(category.colour),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: TextFont(
                text: category.name,
                fontSize: 15,
                maxLines: 1,
              ),
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TextFont(
                  text: convertToMoney(
                      allWallets, categoryWithTotal.total.abs()),
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  maxLines: 1,
                  textAlign: TextAlign.end,
                ),
                TextFont(
                  text: convertToPercent(percent),
                  fontSize: 12,
                  textColor: Theme.of(context).colorScheme.secondary,
                  maxLines: 1,
                  textAlign: TextAlign.end,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
