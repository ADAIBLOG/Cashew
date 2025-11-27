import 'package:budget/colors.dart';
import 'package:budget/main.dart';
import 'package:budget/widgets/framework/pageFramework.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:budget/functions.dart';
import 'package:budget/struct/languageMap.dart';
import 'package:budget/widgets/showChangelog.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutCashewPage extends StatefulWidget {
  const AboutCashewPage({Key? key}) : super(key: key);

  @override
  State<AboutCashewPage> createState() => AboutCashewPageState();
}

class AboutCashewPageState extends State<AboutCashewPage> {
  final pageId = "AboutCashew";
  
  @override
  Widget build(BuildContext context) {
    return PageFramework(
      title: "关于",
      listID: pageId,
      listWidgets: [
        Container(
          padding: EdgeInsets.all(20),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 应用图标和名称
              Image(
                image: AssetImage("assets/icon/icon-small.png"),
                height: 80,
              ),
              SizedBox(height: 20),
              Text(
                globalAppName,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              SizedBox(height: 10),
              Text(
                getVersionString(),
                style: TextStyle(
                  fontSize: 16,
                  color: getColor(context, "textLight"),
                ),
              ),
              SizedBox(height: 30),
              
              // GPL-3.0 许可证声明
              _buildLicenseInfoBox(context, "GNU GENERAL PUBLIC LICENSE", "Version 3, 29 June 2007", () async {
                final Uri url = Uri.parse("https://www.gnu.org/licenses/gpl-3.0.html");
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                }
              }),
              SizedBox(height: 20),
              
              // 原始版权信息
              _buildInfoBox(context, "原始版权信息", "Copyright (C) 2007 Free Software Foundation, Inc."),
              SizedBox(height: 20),
              
              // 原始作者信息
              _buildInfoBox(context, "原始作者", "James (dapperappdeveloper@gmail.com)\nYuYing (数据库设计)"),
              SizedBox(height: 20),
              
              // 项目来源
              _buildLicenseInfoBox(context, "项目来源", "基于 Cashew 项目修改", () async {
                final Uri url = Uri.parse("https://github.com/jameskokoska/Cashew");
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                }
              }),
              SizedBox(height: 20),
              
              // GPL 声明
              Padding(
                padding: EdgeInsets.all(15),
                child: Text(
                  "本程序是自由软件：您可以根据自由软件基金会发布的GNU通用公共许可证条款重新发布和/或修改它，无论是许可证的第3版还是（您选择的）任何更高版本。\n\n本程序的发布是希望它能有用，但没有任何保证；甚至没有对适销性或特定用途适用性的隐含保证。有关更多详细信息，请参见GNU通用公共许可证。\n\n您应该已经收到了GNU通用公共许可证的副本。如果没有，请参见<https://www.gnu.org/licenses/>。",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: getColor(context, "textLight"),
                    height: 1.5,
                  ),
                ),
              ),
              SizedBox(height: 30),
              
              // 免责声明
              Text(
                "免责声明：本程序按'原样'提供，不附带任何形式的保证。",
                style: TextStyle(
                  fontSize: 12,
                  color: getColor(context, "textLight"),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  // 创建信息框组件
  Widget _buildInfoBox(BuildContext context, String title, String content) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(15),
      margin: EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: getColor(context, "lightDarkAccent"),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            content,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: getColor(context, "black"),
            ),
          ),
        ],
      ),
    );
  }
  
  // 创建可点击的许可证信息框
  Widget _buildLicenseInfoBox(BuildContext context, String title, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(15),
        margin: EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: getColor(context, "lightDarkAccent"),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
            SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: getColor(context, "black"),
              ),
            ),
            SizedBox(height: 5),
            Text(
              "点击查看更多",
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).primaryColor,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
