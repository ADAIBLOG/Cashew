import 'package:budget/widgets/textWidgets.dart';
import 'package:budget/widgets/framework/pageFramework.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/functions.dart';
import 'package:budget/widgets/settingsContainers.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({Key? key}) : super(key: key);

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  @override
  Widget build(BuildContext context) {
    String pageId = "About";
    String version = packageInfoGlobal?.version ?? "2.1.2";

    return PageFramework(
      listID: pageId,
      dragDownToDismiss: true,
      title: "about".tr(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(
                top: 30, start: 20, end: 20, bottom: 35),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image(
                  image: AssetImage("assets/icon/icon-small.png"),
                  height: 100,
                ),
                SizedBox(height: 20),
                TextFont(
                  text: "app-name".tr(),
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
                SizedBox(height: 10),
                TextFont(
                  text: version,
                  fontSize: 16,
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SettingsContainer(
            title: "source-code".tr(),
            description: "view-source-code-description".tr(),
            icon: appStateSettings["outlinedIcons"]
                ? Icons.code_outlined
                : Icons.code_rounded,
            onTap: () {
              openUrl("https://github.com/ADAIBLOG/Cashew");
            },
          ),
        ),

        SliverToBoxAdapter(
          child: SettingsContainer(
            title: "app-is-open-source".tr(namedArgs: {"app": "app-name".tr()}),
            description: "based-on-original-project".tr(),
            icon: appStateSettings["outlinedIcons"]
                ? Icons.open_in_new_outlined
                : Icons.open_in_new_rounded,
            onTap: () {
              openUrl("https://github.com/jameskokoska/Cashew");
            },
          ),
        ),
        SliverToBoxAdapter(
          child: SettingsContainer(
            title: "view-licenses-and-legalese".tr(),
            description: "GPL-3.0",
            icon: appStateSettings["outlinedIcons"]
                ? Icons.account_balance_outlined
                : Icons.account_balance_rounded,
            onTap: () {
              openAboutLicensesPage(context);
            },
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: 55)),
      ],
    );
  }
}

void openAboutLicensesPage(BuildContext context) {
  showLicensePage(
    context: context,
    applicationName: "app-name".tr(),
    applicationVersion: packageInfoGlobal?.version ?? "",
    applicationLegalese:
        "Copyright (C) 2023 James Kokoska\n\n"
        "This program is free software: you can redistribute it and/or modify "
        "it under the terms of the GNU General Public License as published by "
        "the Free Software Foundation, either version 3 of the License, or "
        "(at your option) any later version.\n\n"
        "This program is distributed in the hope that it will be useful, "
        "but WITHOUT ANY WARRANTY; without even the implied warranty of "
        "MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the "
        "GNU General Public License for more details.\n\n"
        "You should have received a copy of the GNU General Public License "
        "along with this program.  If not, see <https://www.gnu.org/licenses/>.\n\n" +
        "exchange-rate-notice-description".tr(),
  );
}
