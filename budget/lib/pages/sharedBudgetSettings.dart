import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/shareBudget.dart';
import 'package:budget/widgets/button.dart';
import 'package:budget/widgets/openPopup.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:budget/colors.dart';
import 'package:budget/struct/settings.dart';

class SharedBudgetSettings extends StatefulWidget {
  SharedBudgetSettings({
    Key? key,
    required this.budget,
  }) : super(key: key);

  final Budget budget;

  @override
  _SharedBudgetSettingsState createState() => _SharedBudgetSettingsState();
}

class _SharedBudgetSettingsState extends State<SharedBudgetSettings> {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(height: 35),
        Center(
          child: Icon(
            appStateSettings["outlinedIcons"]
                ? Icons.info_outlined
                : Icons.info_rounded,
            color: Theme.of(context).colorScheme.secondary,
            size: 40,
          ),
        ),
        SizedBox(height: 15),
        Center(
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
            child: TextFont(
              text: "Cloud sharing functionality has been removed",
              fontSize: 18,
              fontWeight: FontWeight.bold,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        SizedBox(height: 10),
        Center(
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 30),
            child: TextFont(
              text: "This budget is no longer shared. You can continue using it as a personal budget.",
              fontSize: 15,
              textAlign: TextAlign.center,
              textColor: getColor(context, "textLight"),
            ),
          ),
        ),
        SizedBox(height: 25),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 15),
          child: Button(
            icon: appStateSettings["outlinedIcons"]
                ? Icons.block_outlined
                : Icons.block_rounded,
            iconColor: Theme.of(context).colorScheme.onError,
            label: "Remove Shared Status",
            onTap: () async {
              openPopup(
                context,
                title: "Remove Shared Status?",
                description: 
                    "Are you sure you want to remove the shared status from this budget? It will become a personal budget.",
                icon: appStateSettings["outlinedIcons"]
                    ? Icons.block_outlined
                    : Icons.block_rounded,
                onCancel: () {
                  popRoute(context);
                },
                onCancelLabel: "cancel".tr(),
                onSubmit: () async {
                  popRoute(context);
                  await removedSharedFromBudget(widget.budget);
                  popRoute(context);
                },
                onSubmitLabel: "Remove".tr(),
              );
            },
            color: Theme.of(context).colorScheme.error,
            textColor: Theme.of(context).colorScheme.onError,
          ),
        ),
        SizedBox(height: 25),
      ],
    );
  }
}
