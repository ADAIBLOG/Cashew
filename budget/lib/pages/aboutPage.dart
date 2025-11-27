import 'package:budget/widgets/textWidgets.dart';
import 'package:budget/widgets/framework/pageFramework.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/functions.dart';
import 'package:budget/widgets/settingsContainers.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:budget/widgets/openBottomSheet.dart';
import 'package:budget/widgets/framework/popupFramework.dart';
import 'package:budget/appState/appState.dart';
import 'package:budget/utilities/deviceOrientations.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({Key? key}) : super(key: key);

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  GlobalKey<PageFrameworkState> pageState = GlobalKey();

  void scrollToTop() {
    pageState.currentState?.scrollToTop();
  }

  @override
  Widget build(BuildContext context) {
    String pageId = "About";

    return PageFramework(
      key: pageState,
      listID: pageId,
      dragDownToDismiss: true,
      title: "about",
      actions: [
        CustomPopupMenuButton(
          showButtons: enableDoubleColumn(context),
          keepOutFirst: true,
          items: [
            DropdownItemMenu(
              id: "settings",
              label: "settings",
              icon: appStateSettings["outlinedIcons"]
                  ? Icons.more_vert_outlined
                  : Icons.more_vert_rounded,
              action: () {
                openBottomSheet(
                  context,
                  PopupFramework(
                    hasPadding: false,
                    child: AboutSettings(),
                  ),
                );
              },
            ),
          ],
        ),
      ],
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
                  text: "1.0.4",
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
            showBorder: true,
          ),
        ),
        SliverToBoxAdapter(
          child: SettingsContainer(
            title: "about-description".tr(),
            description: "a-budget-and-financial-tracking-application".tr(),
            icon: appStateSettings["outlinedIcons"]
                ? Icons.info_outlined
                : Icons.info_rounded,
            showBorder: true,
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: 55)),
      ],
    );
  }
}

class AboutSettings extends StatelessWidget {
  const AboutSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SettingsContainer(
          title: "about".tr(),
          description: "version-1-0-4".tr(),
          icon: appStateSettings["outlinedIcons"]
              ? Icons.info_outlined
              : Icons.info_rounded,
          showBorder: true,
        ),
      ],
    );
  }
}

class CustomPopupMenuButton extends StatelessWidget {
  final List<DropdownItemMenu> items;
  final bool showButtons;
  final bool keepOutFirst;

  const CustomPopupMenuButton({
    Key? key,
    required this.items,
    required this.showButtons,
    required this.keepOutFirst,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton(
      itemBuilder: (context) => items.map((item) {
        return PopupMenuItem(
          onTap: item.action,
          child: ListTile(
            leading: Icon(item.icon),
            title: Text(item.label),
          ),
        );
      }).toList(),
      icon: Icon(
        appStateSettings["outlinedIcons"]
            ? Icons.more_vert_outlined
            : Icons.more_vert_rounded,
      ),
    );
  }
}

class DropdownItemMenu {
  final String id;
  final String label;
  final IconData icon;
  final Function() action;

  DropdownItemMenu({
    required this.id,
    required this.label,
    required this.icon,
    required this.action,
  });
}
