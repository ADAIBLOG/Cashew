import 'dart:async';
import 'dart:convert';
import 'package:budget/colors.dart';
import 'package:budget/database/tables.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:budget/pages/addEmailTemplate.dart';
import 'package:budget/pages/addTransactionPage.dart';
import 'package:budget/pages/editCategoriesPage.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/struct/notificationsGlobal.dart';
import 'package:budget/widgets/button.dart';
import 'package:budget/widgets/globalSnackbar.dart';
import 'package:budget/widgets/navigationFramework.dart';
import 'package:budget/widgets/openPopup.dart';
import 'package:budget/widgets/openSnackbar.dart';
import 'package:budget/widgets/notificationsSettings.dart';
import 'package:budget/widgets/framework/pageFramework.dart';
import 'package:budget/widgets/settingsContainers.dart';
import 'package:budget/widgets/statusBox.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AutoTransactionsPageEmail extends StatefulWidget {
  const AutoTransactionsPageEmail({super.key});

  @override
  State<AutoTransactionsPageEmail> createState() =>
      _AutoTransactionsPageEmailState();
}

class _AutoTransactionsPageEmailState extends State<AutoTransactionsPageEmail> {
  bool canReadEmails = appStateSettings["AutoTransactions-canReadEmails"] ?? false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () async {
      // Google services have been removed, email scanning is no longer available
      updateSettings("AutoTransactions-canReadEmails", false,
          pagesNeedingRefresh: [3], updateGlobalState: false);
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return PageFramework(
      dragDownToDismiss: true,
      title: "auto-transactions-title".tr(),
      actions: [
        RefreshButton(onTap: () async {
          loadingIndeterminateKey.currentState?.setVisibility(true);
          await parseEmailsInBackground(context, 
              sayUpdates: true, forceParse: true);
          loadingIndeterminateKey.currentState?.setVisibility(false);
        }),
      ],
      slivers: [
        SliverList(
          delegate: SliverChildListDelegate([
            Padding(
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              child: Column(
                children: [
                  SizedBox(height: 10),
                  StatusBox(
                    title: "email-scanning-disabled".tr(),
                    description: "google-services-removed".tr(),
                    color: Theme.of(context).colorScheme.secondary,
                    icon: Icons.info,
                  ),
                  SizedBox(height: 15),
                  SettingsContainerOutlined(
                    title: "read-emails".tr(),
                    description:
                        "google-services-removed".tr(),
                    icon: appStateSettings["outlinedIcons"]
                        ? Icons.mark_email_unread_outlined
                        : Icons.mark_email_unread_rounded,
                    isExpanded: true,
                    afterWidget: Switch(
                      value: false,
                      onChanged: (value) {
                        // Google services have been removed, do nothing
                      },
                    ),
                  ),
                  SizedBox(height: 15),
                  SettingsContainerOutlined(
                    title: "notifications-scanning".tr(),
                    description:
                        "scan-notifications-for-transactions".tr(),
                    icon: appStateSettings["outlinedIcons"]
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_active_rounded,
                    isExpanded: true,
                    afterWidget: Switch(
                      value: appStateSettings["notificationScanning"] ?? false,
                      onChanged: (value) async {
                        updateSettings("notificationScanning", value,
                            pagesNeedingRefresh: [], updateGlobalState: false);
                        setState(() {});
                      },
                    ),
                  ),
                  SizedBox(height: 5),
                ],
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

Future<void> parseEmailsInBackground(context,
    {bool sayUpdates = false, bool forceParse = false}) async {
  // Google services have been removed, email scanning is no longer available
  await updateSettings("AutoTransactions-canReadEmails", false,
      pagesNeedingRefresh: [3], updateGlobalState: false);
  await updateSettings("emailScanning", false,
      pagesNeedingRefresh: [], updateGlobalState: false);
  if (sayUpdates == true) {
    openSnackbar(SnackbarMessage(
      title: "email-scanning-disabled".tr(),
      description: "google-services-removed".tr(),
      icon: appStateSettings["outlinedIcons"]
          ? Icons.info_outlined
          : Icons.info_rounded,
    ));
  }
}
