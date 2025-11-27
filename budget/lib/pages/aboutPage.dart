import 'package:budget/widgets/textWidgets.dart';
import 'package:budget/widgets/framework/pageFramework.dart';
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
    return PageFramework(
      title: "about",
      listWidgets: [
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
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
                text: "1.0.0",
                fontSize: 16,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  final url = Uri.parse('https://github.com/ADAIBLOG/Cashew');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  }
                },
                child: Text('Source Code'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
