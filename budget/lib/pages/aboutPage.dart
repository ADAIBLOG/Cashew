import 'package:budget/widgets/textWidgets.dart';
import 'package:budget/widgets/framework/pageFramework.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/functions.dart';
import 'package:budget/widgets/settingsContainers.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
      title: "about",
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
                  text: "Cashew",
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
            onTap: () async {
              final url = Uri.parse('https://github.com/ADAIBLOG/Cashew');
              if (await canLaunchUrl(url)) {
                await launchUrl(url);
              }
            },

          ),
        ),

        SliverToBoxAdapter(child: SizedBox(height: 55)),
      ],
    );
  }
}
