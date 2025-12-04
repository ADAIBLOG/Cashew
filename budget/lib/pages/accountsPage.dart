import 'package:budget/colors.dart';
import 'package:budget/functions.dart';
import 'package:budget/main.dart';
import 'package:budget/pages/addTransactionPage.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/accountAndBackup.dart';
import 'package:budget/widgets/animatedExpanded.dart';
import 'package:budget/widgets/button.dart';
import 'package:budget/widgets/dropdownSelect.dart';
import 'package:budget/widgets/fadeIn.dart';
import 'package:budget/widgets/iconButtonScaled.dart';
import 'package:budget/widgets/moreIcons.dart';
import 'package:budget/widgets/navigationFramework.dart';
import 'package:budget/widgets/openBottomSheet.dart';
import 'package:budget/widgets/framework/pageFramework.dart';
import 'package:budget/widgets/openPopup.dart';
import 'package:budget/widgets/settingsContainers.dart';
import 'package:budget/widgets/tappable.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:budget/widgets/extraInfoBoxes.dart';
import 'package:budget/widgets/outlinedButtonStacked.dart';

class AccountsPage extends StatefulWidget {
  const AccountsPage({Key? key}) : super(key: key);

  @override
  State<AccountsPage> createState() => AccountsPageState();
}

class AccountsPageState extends State<AccountsPage> {
  bool currentlyExporting = false;

  void refreshState() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    Widget profileWidget = Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: dynamicPastel(context, Theme.of(context).colorScheme.primary,
            amount: 0.2),
      ),
      child: Icon(Icons.account_circle_outlined, size: 50),
    );

    return PageFramework(
      title: "accounts".tr(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 35),
                Padding(
                  padding: EdgeInsetsDirectional.only(
                      start: 20, end: 20, bottom: 15),
                  child: AccountAndBackup(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
