import 'package:budget/widgets/framework/pageFramework.dart';
import 'package:flutter/material.dart';

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
          alignment: Alignment.center,
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 保持页面简洁，不添加对不存在方法的引用
            ],
          ),
        ),
      ],
    );
  }
}
