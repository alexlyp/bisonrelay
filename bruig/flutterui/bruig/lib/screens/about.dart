import 'package:bruig/components/buttons.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String version = "";

  Future<void> getPlatform() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      version = packageInfo.version;
    });
  }

  @override
  void initState() {
    super.initState();
    getPlatform();
  }

  void goBack(BuildContext context) {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    var textColor = const Color(0xFFE4E3E6);
    var backgroundColor = const Color(0xFF19172C);
    var cardColor = const Color(0xFF05031A);

    return Scaffold(
        body: Container(
            color: backgroundColor,
            child: Stack(children: [
              Container(
                  decoration: const BoxDecoration(
                      image: DecorationImage(
                          fit: BoxFit.fill,
                          image: AssetImage("assets/images/loading-bg.png")))),
              Container(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.bottomLeft,
                          end: Alignment.topRight,
                          colors: [
                        cardColor,
                        const Color(0xFF07051C),
                        backgroundColor.withOpacity(0.34),
                      ],
                          stops: const [
                        0,
                        0.17,
                        1
                      ])),
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      const SizedBox(height: 89),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(30)),
                                border: Border.all(color: textColor),
                              ),
                              width: 600,
                              height: 300,
                              child: Row(children: [
                                Image.asset(
                                  "assets/images/icon.png",
                                  width: 200,
                                  height: 200,
                                ),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                        textAlign: TextAlign.left,
                                        "Bison Relay",
                                        style: TextStyle(
                                            color: textColor,
                                            fontSize: 34,
                                            fontWeight: FontWeight.w200)),
                                    const SizedBox(height: 10),
                                    Text("Version $version",
                                        style: TextStyle(
                                            color: textColor,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w200)),
                                    const SizedBox(height: 10),
                                    Row(children: [
                                      Icon(
                                          color: textColor,
                                          size: 20,
                                          Icons.copyright),
                                      const SizedBox(width: 5),
                                      Text("2022-2023, Company 0, LLC",
                                          style: TextStyle(
                                              color: textColor,
                                              fontSize: 20,
                                              fontWeight: FontWeight.w200))
                                    ])
                                  ],
                                )
                              ])),
                        ],
                      ),
                      const SizedBox(height: 89),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            LoadingScreenButton(
                              empty: true,
                              onPressed: () => goBack(context),
                              text: "Go Back",
                            ),
                          ]),
                    ],
                  )),
            ])));
  }
}
