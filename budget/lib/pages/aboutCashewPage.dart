import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../functions.dart';

class AboutCashewPage extends StatelessWidget {
  const AboutCashewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PageFramework(
      title: "关于 Cashew",
      dragDownToDismiss: true,
      horizontalPaddingConstrained: true,
      listWidgets: [
        SizedBox(height: 20),
        Center(
          child: Column(
            children: [
              Image.asset(
                'assets/icon/icon.png',
                width: 80,
                height: 80,
              ),
              SizedBox(height: 20),
              TextFont(
                text: "Cashew",
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              SizedBox(height: 10),
              TextFont(
                text: "个人修改版",
                fontSize: 16,
                textColor: getColor(context, "textLight"),
              ),
            ],
          ),
        ),
        SizedBox(height: 30),
        SettingsHeader(title: "关于此版本"),
        SettingsContainer(
          title: "版本信息",
          description: "基于开源项目 Cashew 通过Trae进行二次修改",
          icon: Icons.info_outline_rounded,
        ),
        SettingsContainer(
          title: "使用声明",
          description: "仅用于个人学习参考，不涉及商业用途",
          icon: Icons.description_outline_rounded,
        ),
        SettingsContainerTappable(
          title: "原版项目",
          description: "https://github.com/jameskokoska/Cashew",
          icon: Icons.link_outlined,
          onTap: () {
            openUrl("https://github.com/jameskokoska/Cashew");
          },
        ),
        SettingsContainerTappable(
          title: "此修改版",
          description: "https://github.com/ADAIBLOG/Cashew",
          icon: Icons.link_outlined,
          onTap: () {
            openUrl("https://github.com/ADAIBLOG/Cashew");
          },
        ),
        SizedBox(height: 30),
        SettingsHeader(title: "主要修改内容"),
        _buildFeatureItem(context, "禁用云服务相关功能", "移除 Google 登录、Firebase 同步/备份、Google Drive 备份等所有依赖第三方云服务的功能，数据仅存储于本地设备，保障隐私安全。"),
        _buildFeatureItem(context, "新增通知栏交易识别功能", "添加通知栏信息监听与解析逻辑，可自动提取银行、支付软件等发送的交易通知中的金额、交易类型等关键信息，快速生成对应交易记录（需授予通知访问权限）。"),
        _buildFeatureItem(context, "新增安卓原生组件", "根据个人使用需求，集成了部分新的安卓原生组件，优化本地操作体验。"),
        _buildFeatureItem(context, "修复语言显示 Bug", "解决原版本中部分语言翻译错乱、显示异常的问题，确保界面文字展示准确、排版规范。"),
        SizedBox(height: 50),
      ],
    );
  }

  Widget _buildFeatureItem(BuildContext context, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFont(
            text: title,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          SizedBox(height: 4),
          TextFont(
            text: description,
            fontSize: 14,
            textColor: getColor(context, "textLight"),
            maxLines: 5,
          ),
        ],
      ),
    );
  }
}

class SettingsHeader extends StatelessWidget {
  final String title;
  const SettingsHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(17, 20, 17, 10),
      child: TextFont(
        text: title,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        textColor: getColor(context, "textLight"),
      ),
    );
  }
}

class SettingsContainerTappable extends StatelessWidget {
  final String title;
  final String? description;
  final IconData icon;
  final VoidCallback onTap;
  const SettingsContainerTappable({
    super.key,
    required this.title,
    this.description,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tappable(
      onTap: onTap,
      borderRadius: 15,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(17, 15, 17, 15),
        child: Row(
          children: [
            Container(
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                color: getColor(context, "textLight").withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: getColor(context, "textLight")),
            ),
            SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFont(text: title, fontSize: 16),
                  if (description != null)
                    TextFont(
                      text: description!, 
                      fontSize: 13,
                      textColor: getColor(context, "textLight"),
                      maxLines: 2,
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: getColor(context, "textLight")),
          ],
        ),
      ),
    );
  }
}
