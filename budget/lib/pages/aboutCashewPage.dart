import 'package:budget/colors.dart';
import 'package:budget/main.dart';
import 'package:budget/widgets/framework/pageFramework.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:flutter/material.dart';
import 'package:budget/widgets/openBottomSheet.dart';
import 'package:budget/widgets/navigationFramework.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutCashewPage extends StatelessWidget {
  const AboutCashewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PageFramework(
      title: "关于 Cashew",
      dragDownToDismiss: true,
      listWidgets: [
        Container(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 20),
              CircleAvatar(
                radius: 60,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Icon(
                  Icons.pie_chart_outline,
                  size: 80,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 20),
              TextFont(
                text: "Cashew",
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
              SizedBox(height: 8),
              TextFont(
                text: "个人财务助手",
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              SizedBox(height: 4),
              TextFont(
                text: "版本 1.0.0",
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              SizedBox(height: 30),
              Card(
                margin: EdgeInsets.all(10),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFont(
                        text: "项目介绍",
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      SizedBox(height: 10),
                      TextFont(
                        text: "Cashew 是一个功能丰富的个人财务管理应用，帮助用户有效管理预算、跟踪支出、设置财务目标。",
                        fontSize: 14,
                        maxLines: 10,
                      ),
                    ],
                  ),
                ),
              ),
              Card(
                margin: EdgeInsets.all(10),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFont(
                        text: "开源信息",
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      SizedBox(height: 10),
                      InkWell(
                        onTap: () => _launchURL('https://github.com/jameskokoska/Cashew'),
                        child: TextFont(
                          text: "原始项目地址: https://github.com/jameskokoska/Cashew",
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.primary,
                          textDecoration: TextDecoration.underline,
                        ),
                      ),
                      SizedBox(height: 5),
                      InkWell(
                        onTap: () => _launchURL('https://github.com/ADAIBLOG/Cashew'),
                        child: TextFont(
                          text: "本修改版地址: https://github.com/ADAIBLOG/Cashew",
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.primary,
                          textDecoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Card(
                margin: EdgeInsets.all(10),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFont(
                        text: "重要声明",
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      SizedBox(height: 10),
                      TextFont(
                        text: "1. 本版本基于开源项目 Cashew 进行二次修改，仅用于个人学习参考，不涉及商业用途。\n" +
                            "2. 原项目的开源协议及相关权利归属原作者所有。\n" +
                            "3. 本修改版移除了 Google 登录、Firebase 同步/备份、Google Drive 备份等所有依赖第三方云服务的功能。\n" +
                            "4. 数据仅存储于本地设备，保障隐私安全。\n" +
                            "5. 本应用仅供学习和参考，作者不对使用本应用产生的任何问题负责。",
                        fontSize: 14,
                        maxLines: 20,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 30),
              TextFont(
                text: "© 2024 Cashew 个人修改版",
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
