import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/pages/addCategoryPage.dart';
import 'package:budget/pages/addWalletPage.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/widgets/animatedExpanded.dart';
import 'package:budget/widgets/button.dart';
import 'package:budget/widgets/framework/pageFramework.dart';
import 'package:budget/widgets/openPopup.dart';
import 'package:budget/widgets/saveBottomButton.dart';
import 'package:budget/widgets/selectChips.dart';
import 'package:budget/widgets/tappable.dart';
import 'package:budget/widgets/textInput.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:budget/colors.dart';
import 'package:provider/provider.dart';

class AddEmailTemplate extends StatefulWidget {
  AddEmailTemplate({
    Key? key,
    required this.messagesList,
    this.scannerTemplate,
  }) : super(key: key);
  final List<String> messagesList;
  //When a transaction is passed in, we are editing that transaction
  final ScannerTemplate? scannerTemplate;

  @override
  _AddEmailTemplateState createState() => _AddEmailTemplateState();
}

class _AddEmailTemplateState extends State<AddEmailTemplate> {
  bool? canAddTemplate;
  String? selectedWalletPk;
  String? selectedName;
  String? selectedSubject;
  TransactionCategory? selectedCategory;
  String? expandedMainCategoryFk;

  @override
  void initState() {
    super.initState();
    if (widget.scannerTemplate != null) {
      selectedWalletPk = widget.scannerTemplate!.walletFk == "-1"
          ? null
          : widget.scannerTemplate!.walletFk;
      selectedName = widget.scannerTemplate!.templateName;
      selectedSubject = widget.scannerTemplate!.contains;
      // 加载已有的默认类别（"-1" 表示未设置）
      if (widget.scannerTemplate!.defaultCategoryFk != "-1") {
        Future.delayed(Duration.zero, () async {
          TransactionCategory? getSelectedCategory = await database
              .getCategoryInstanceOrNull(
                  widget.scannerTemplate!.defaultCategoryFk);
          if (mounted) {
            setState(() {
              selectedCategory = getSelectedCategory;
              // 若默认类别是子分类，则展开其所属主分类
              if (getSelectedCategory?.mainCategoryPk != null) {
                expandedMainCategoryFk = getSelectedCategory!.mainCategoryPk;
              }
            });
          }
        });
      }
    }
    determineBottomButton();
  }

  @override
  void dispose() {
    super.dispose();
  }

  determineBottomButton() {
    bool canAdd = true;
    
    // 简化验证逻辑：只需要模板名称和主题文本
    if (selectedName == null || selectedName!.trim() == "") {
      canAdd = false;
    }
    
    if (selectedSubject == null || selectedSubject!.trim() == "") {
      canAdd = false;
    }

    setState(() {
      canAddTemplate = canAdd;
    });
    return canAdd;
  }



  Future addTemplate() async {
    print("Added template");
    await database.createOrUpdateScannerTemplate(
      insert: widget.scannerTemplate == null,
      createTemplate(),
    );
    // 移除未定义的方法调用
    popRoute(context);
  }

  ScannerTemplate createTemplate() {
    return ScannerTemplate(
      scannerTemplatePk: widget.scannerTemplate != null
          ? widget.scannerTemplate!.scannerTemplatePk
          : "-1",
      dateCreated: widget.scannerTemplate != null
          ? widget.scannerTemplate!.dateCreated
          : DateTime.now(),
      dateTimeModified: null,
      // 金额相关字段设为"auto"，表示使用自动识别
      amountTransactionAfter: "auto",
      amountTransactionBefore: "auto",
      contains: selectedSubject ?? "",
      // 默认类别：未选择（手动选择）时为 "-1"
      defaultCategoryFk: selectedCategory?.categoryPk ?? "-1",
      templateName: selectedName ?? "",
      // 标题相关参数设为空字符串
      titleTransactionAfter: "",
      titleTransactionBefore: "",
      walletFk: selectedWalletPk ?? "-1",
      ignore: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Simplified back navigation without discard confirmation
          popRoute(context);
          return true;
      },
      child: PageFramework(
        staticOverlay: Align(
          alignment: AlignmentDirectional.bottomCenter,
          child: SaveBottomButton(
            label: widget.scannerTemplate == null
                ? "add-template".tr()
                : "save-changes".tr(),
            onTap: () {
              addTemplate();
            },
            disabled: !(canAddTemplate ?? false),
          ),
        ),
        resizeToAvoidBottomInset: true,
        dragDownToDismissEnabled: true,
        dragDownToDismiss: true,
        title:
            widget.scannerTemplate == null ? "add-template".tr() : "edit-template".tr(),
        onBackButton: () async {
          popRoute(context);
        },
        onDragDownToDismiss: () async {
          popRoute(context);
        },
        listWidgets: [
          Container(height: 10),
          // 模板名称输入
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
            child: TextInput(
              autoFocus: kIsWeb,
              labelText: "name-placeholder".tr(),
              bubbly: false,
              initialValue: selectedName,
              onChanged: (text) {
                setState(() {
                  selectedName = text;
                });
                determineBottomButton();
              },
              padding: EdgeInsetsDirectional.only(start: 7, end: 7),
              fontSize: 30,
              fontWeight: FontWeight.bold,
              topContentPadding: 20,
            ),
          ),
          SizedBox(height: 20),
          
          // 主题文本输入 - 用于识别交易的关键词
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
            child: TextInput(
              labelText: "主题文本" + " (" + "用于识别交易的关键词" + ")",
              bubbly: false,
              initialValue: selectedSubject,
              onChanged: (text) {
                setState(() {
                  selectedSubject = text;
                });
                determineBottomButton();
              },
              padding: EdgeInsetsDirectional.only(start: 7, end: 7),
              fontSize: 18,

            ),
          ),
          SizedBox(height: 20),
          
          // 账户选择
          SelectChips(
            wrapped: false,
            extraWidgetBeforeSticky: true,
            allowMultipleSelected: false,
            onLongPress: (TransactionWallet? wallet) {
              pushRoute(
                context,
                AddWalletPage(
                  wallet: wallet,
                  routesToPopAfterDelete: RoutesToPopAfterDelete.None,
                ),
              );
            },
            items: <TransactionWallet?>[
              null,
              ...Provider.of<AllWallets>(context).list
            ],
            getSelected: (TransactionWallet? wallet) {
              return selectedWalletPk == wallet?.walletPk;
            },
            onSelected: (TransactionWallet? wallet) {
              setState(() {
                selectedWalletPk = wallet?.walletPk;
              });
              determineBottomButton();
            },
            getCustomBorderColor: (TransactionWallet? item) {
              return dynamicPastel(
                context,
                lightenPastel(
                  HexColor(
                    item?.colour,
                    defaultColor: Theme.of(context).colorScheme.primary,
                  ),
                  amount: 0.3,
                ),
                amount: 0.4,
              );
            },
            getLabel: (TransactionWallet? wallet) {
              if (wallet == null) return "primary-default".tr();
              return getWalletStringName(
                  Provider.of<AllWallets>(context), wallet);
            },
            extraWidgetAfter: SelectChipsAddButtonExtraWidget(
              openPage: AddWalletPage(
                routesToPopAfterDelete: RoutesToPopAfterDelete.None,
              ),
            ),
          ),
          SizedBox(height: 20),

          // 默认类别选择（可选）- 识别失败时的兜底类别
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFont(
                  text: "默认类别（可选）",
                  textColor: getColor(context, "textLight"),
                  fontSize: 16,
                ),
                SizedBox(height: 2),
                TextFont(
                  text: "识别不到类别时使用此兜底类别；选择“手动选择类别”则每次添加交易时手动选择。",
                  textColor: getColor(context, "textLight"),
                  fontSize: 11,
                  maxLines: 5,
                ),
                SizedBox(height: 8),
                StreamBuilder<List<TransactionCategory>>(
                  stream: database.watchAllCategories(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData == false) return SizedBox.shrink();
                    List<TransactionCategory> mainCategories = snapshot.data!
                        .where((category) => category.mainCategoryPk == null)
                        .toList();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectChips<TransactionCategory?>(
                          wrapped: false,
                          extraWidgetBeforeSticky: true,
                          allowMultipleSelected: false,
                          items: [null, ...mainCategories],
                          getSelected: (TransactionCategory? category) {
                            if (category == null)
                              return selectedCategory == null;
                            return selectedCategory?.categoryPk ==
                                    category.categoryPk ||
                                selectedCategory?.mainCategoryPk ==
                                    category.categoryPk;
                          },
                          onSelected: (TransactionCategory? category) {
                            setState(() {
                              if (category == null) {
                                selectedCategory = null;
                                expandedMainCategoryFk = null;
                              } else {
                                // 再次点击已展开的主分类则收起
                                if (expandedMainCategoryFk ==
                                    category.categoryPk) {
                                  expandedMainCategoryFk = null;
                                } else {
                                  expandedMainCategoryFk =
                                      category.categoryPk;
                                }
                                selectedCategory = category;
                              }
                            });
                            determineBottomButton();
                          },
                          getLabel: (TransactionCategory? category) {
                            if (category == null) return "手动选择类别";
                            return category.name;
                          },
                          getCustomBorderColor: (TransactionCategory? item) {
                            return dynamicPastel(
                              context,
                              lightenPastel(
                                HexColor(
                                  item?.colour,
                                  defaultColor:
                                      Theme.of(context).colorScheme.primary,
                                ),
                                amount: 0.3,
                              ),
                              amount: 0.4,
                            );
                          },
                          extraWidgetAfter: SelectChipsAddButtonExtraWidget(
                            openPage: AddCategoryPage(
                              routesToPopAfterDelete:
                                  RoutesToPopAfterDelete.None,
                            ),
                          ),
                        ),
                        // 点击主分类后，在下方展示其子分类供选择
                        if (expandedMainCategoryFk != null)
                          StreamBuilder<List<TransactionCategory>>(
                            stream: database.watchAllCategories(
                                mainCategoryPks: [expandedMainCategoryFk!]),
                            builder: (context, snapshot) {
                              if (snapshot.hasData == false ||
                                  snapshot.data!.isEmpty) {
                                return SizedBox.shrink();
                              }
                              return AnimatedExpanded(
                                expand: true,
                                child: Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                      top: 8),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (TransactionCategory subCategory
                                          in snapshot.data!)
                                        Tappable(
                                          borderRadius: 15,
                                          color: selectedCategory
                                                      ?.categoryPk ==
                                                  subCategory.categoryPk
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                              : getColor(context,
                                                  "lightDarkAccentHeavy"),
                                          onTap: () {
                                            setState(() {
                                              selectedCategory = subCategory;
                                            });
                                            determineBottomButton();
                                          },
                                          child: Padding(
                                            padding:
                                                const EdgeInsetsDirectional
                                                    .symmetric(
                                                        horizontal: 12,
                                                        vertical: 6),
                                            child: TextFont(
                                              text: subCategory.name,
                                              fontSize: 13,
                                              fontWeight: selectedCategory
                                                          ?.categoryPk ==
                                                      subCategory.categoryPk
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              textColor: selectedCategory
                                                          ?.categoryPk ==
                                                      subCategory.categoryPk
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .onPrimary
                                                  : getColor(context,
                                                      "black"),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          
          // 说明信息
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
            child: Column(
              children: [
                Text("使用说明:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text("1. 输入模板名称便于识别", style: TextStyle(fontSize: 14)),
                Text("2. 输入主题文本（关键词）用于识别交易消息", style: TextStyle(fontSize: 14)),
                Text("3. 选择交易将自动分配到的账户", style: TextStyle(fontSize: 14)),
                Text("4. 金额将从消息中自动识别（支持¥\$€£等货币符号）", style: TextStyle(fontSize: 14)),
              ],
            ),
          ),
          SizedBox(height: 70),
        ],
      ),
    );
  }
}

// Removed TemplateInfoBox class as it's no longer needed
