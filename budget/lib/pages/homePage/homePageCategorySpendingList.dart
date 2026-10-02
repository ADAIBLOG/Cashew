import 'package:budget/colors.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/pages/editHomePage.dart';
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

  void openSettings() async {
    await openCategorySpendingListSettings(context);
    homePageStateKey.currentState?.refreshState();
  }

  @override
  Widget build(BuildContext context) {
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
                  CategorySpendingTextList(isIncome: isIncome),
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

class CategorySpendingTextList extends StatelessWidget {
  const CategorySpendingTextList({required this.isIncome, super.key});
  final bool isIncome;

  @override
  Widget build(BuildContext context) {
    AllWallets allWallets = Provider.of<AllWallets>(context);
    return StreamBuilder<List<TransactionWallet>>(
      stream: database.getAllPinnedWallets(HomePageWidgetDisplay.PieChart).$1,
      builder: (context, snapshot) {
        if (snapshot.hasData ||
            appStateSettings["pieChartAllWallets"] == true) {
          List<String>? walletPks =
              (snapshot.data ?? []).map((item) => item.walletPk).toList();
          if (walletPks.length <= 0 ||
              appStateSettings["pieChartAllWallets"] == true) walletPks = null;
          return StreamBuilder<List<CategoryWithTotal>>(
            stream:
                database.watchTotalSpentInEachCategoryInTimeRangeFromCategories(
              allWallets: allWallets,
              start: DateTime.now(),
              end: DateTime.now(),
              categoryFks: null,
              categoryFksExclude: null,
              budgetTransactionFilters: null,
              memberTransactionFilters: null,
              allTime: true,
              walletPks: walletPks,
              isIncome: isIncome,
              followCustomPeriodCycle: true,
              cycleSettingsExtension: "PieChart",
              countUnassignedTransactions: true,
              includeAllSubCategories: true,
              searchFilters: SearchFilters(expenseIncome: [
                if (appStateSettings["pieChartIncomeAndExpenseOnly"] == true)
                  (isIncome == true
                      ? ExpenseIncome.income
                      : ExpenseIncome.expense)
              ]),
            ),
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
                      text: isIncome
                          ? appStateSettings[
                                      "pieChartIncomeAndExpenseOnly"] ==
                                  true
                              ? "no-income-within-period".tr()
                              : "no-incoming-within-period".tr()
                          : appStateSettings[
                                      "pieChartIncomeAndExpenseOnly"] ==
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
                        isIncome: isIncome,
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
    super.key,
  });
  final CategoryWithTotal categoryWithTotal;
  final double totalSpent;
  final AllWallets allWallets;
  final bool isIncome;

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
              dateTimeRange: getDateTimeRangeForPassedSearchFilters(
                  cycleSettingsExtension: "PieChart"),
              categoryPks: [category.mainCategoryPk ?? category.categoryPk],
              positiveCashFlow: appStateSettings[
                          "pieChartIncomeAndExpenseOnly"] ==
                      true
                  ? null
                  : isIncome,
              expenseIncome: [
                if (appStateSettings["pieChartIncomeAndExpenseOnly"] == true)
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
                  color: Theme.of(context).colorScheme.secondary,
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
