import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/pages/addWalletPage.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/widgets/button.dart';
import 'package:budget/widgets/framework/pageFramework.dart';
import 'package:budget/widgets/openPopup.dart';
import 'package:budget/widgets/saveBottomButton.dart';
import 'package:budget/widgets/selectChips.dart';
import 'package:budget/widgets/textInput.dart';
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

  @override
  void initState() {
    super.initState();
    if (widget.scannerTemplate != null) {
      selectedWalletPk = widget.scannerTemplate!.walletFk == "-1"
          ? null
          : widget.scannerTemplate!.walletFk;
      selectedName = widget.scannerTemplate!.templateName;
      selectedSubject = widget.scannerTemplate!.contains;
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
      // 默认类别设置为-1，表示不使用类别
      defaultCategoryFk: "-1",
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
