import 'dart:io';

import 'package:bruig/components/buttons.dart';
import 'package:bruig/models/newconfig.dart';
import 'package:flutter/material.dart';
import 'package:bruig/models/snackbar.dart';

class LNExternalWalletPage extends StatefulWidget {
  final NewConfigModel newconf;
  final SnackBarModel snackBar;
  const LNExternalWalletPage(this.newconf, this.snackBar, {Key? key})
      : super(key: key);

  @override
  State<LNExternalWalletPage> createState() => _LNExternalWalletPageState();
}

class _LNExternalWalletPageState extends State<LNExternalWalletPage> {
  SnackBarModel get snackBar => widget.snackBar;
  final TextEditingController hostCtrl = TextEditingController();
  final TextEditingController tlsCtrl = TextEditingController();
  final TextEditingController macaroonCtrl = TextEditingController();
  bool loading = false;

  void done() async {
    var host = hostCtrl.text.trim();
    var tls = tlsCtrl.text.trim();
    var macaroon = macaroonCtrl.text.trim();
    if (host == "") {
      snackBar.error("Host cannot be empty");
      return;
    }
    if (!File(tls).existsSync()) {
      snackBar.error("TLS path $tls does not exist");
      return;
    }
    if (!File(macaroon).existsSync()) {
      snackBar.error("Macaroon path $macaroon does not exist");
      return;
    }
    setState(() {
      loading = true;
    });
    try {
      var res = await widget.newconf.tryExternalDcrlnd(host, tls, macaroon);
      if (res.chains.length != 1) {
        snackBar.error("Wrong number of chains ($res.chains.length)");
        return;
      }
      String wantNetwork = "";
      switch (widget.newconf.netType) {
        case NetworkType.mainnet:
          wantNetwork = "mainnet";
          break;
        case NetworkType.testnet:
          wantNetwork = "testnet";
          break;
        case NetworkType.simnet:
          wantNetwork = "simnet";
          break;
      }
      if (res.chains[0].network != wantNetwork) {
        snackBar.error(
            "LN running in the wrong network (${res.chains[0].network} vs $wantNetwork)");
        return;
      }
      Navigator.of(context).pushNamed("/newconf/server");
    } catch (exception) {
      snackBar.error("Unable to connect to external dcrlnd: $exception");
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var backgroundColor = const Color(0xFF19172C);
    var cardColor = const Color(0xFF05031A);
    var textColor = const Color(0xFF8E8D98);
    var secondaryTextColor = const Color(0xFFE4E3E6);
    var darkTextColor = const Color(0xFF5A5968);

    void goToAbout() {
      Navigator.of(context).pushNamed("/about");
    }

    return Container(
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
              child: Column(children: [
                Row(children: [
                  IconButton(
                      alignment: Alignment.topLeft,
                      tooltip: "About Bison Relay",
                      iconSize: 50,
                      onPressed: goToAbout,
                      icon: Image.asset(
                        "assets/images/icon.png",
                      )),
                ]),
                const SizedBox(height: 39),
                Text("Setting up Bison Relay",
                    style: TextStyle(
                        color: textColor,
                        fontSize: 34,
                        fontWeight: FontWeight.w200)),
                const SizedBox(height: 20),
                Text("External dcrlnd Config",
                    style: TextStyle(
                        color: secondaryTextColor,
                        fontSize: 21,
                        fontWeight: FontWeight.w300)),
                const SizedBox(height: 34),
                Column(children: [
                  SizedBox(
                      width: 377,
                      child: Text("RPC Host",
                          textAlign: TextAlign.left,
                          style: TextStyle(
                              color: darkTextColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w300))),
                  const SizedBox(height: 5),
                  Center(
                      child: SizedBox(
                          width: 377,
                          child: TextField(
                              cursorColor: secondaryTextColor,
                              decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: "RPC Host",
                                  hintStyle:
                                      TextStyle(fontSize: 21, color: textColor),
                                  filled: true,
                                  fillColor: cardColor),
                              style: TextStyle(
                                  color: secondaryTextColor, fontSize: 21),
                              controller: hostCtrl))),
                  const SizedBox(height: 13),
                  SizedBox(
                      width: 377,
                      child: Text("TLS Cert Path",
                          textAlign: TextAlign.left,
                          style: TextStyle(
                              color: darkTextColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w300))),
                  const SizedBox(height: 5),
                  Center(
                      child: SizedBox(
                          width: 377,
                          child: TextField(
                              cursorColor: secondaryTextColor,
                              decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: "TLS Cert Path",
                                  hintStyle:
                                      TextStyle(fontSize: 21, color: textColor),
                                  filled: true,
                                  fillColor: cardColor),
                              style: TextStyle(
                                  color: secondaryTextColor, fontSize: 21),
                              controller: tlsCtrl))),
                  const SizedBox(height: 13),
                  SizedBox(
                      width: 377,
                      child: Text("Macarooon Path",
                          textAlign: TextAlign.left,
                          style: TextStyle(
                              color: darkTextColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w300))),
                  const SizedBox(height: 5),
                  Center(
                      child: SizedBox(
                          width: 377,
                          child: TextField(
                              cursorColor: secondaryTextColor,
                              decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: "Macaroon Path",
                                  hintStyle:
                                      TextStyle(fontSize: 21, color: textColor),
                                  filled: true,
                                  fillColor: cardColor),
                              style: TextStyle(
                                  color: secondaryTextColor, fontSize: 21),
                              controller: macaroonCtrl))),
                  const SizedBox(height: 34),
                  Center(
                      child: SizedBox(
                          width: 283,
                          child: Row(children: [
                            const SizedBox(width: 35),
                            LoadingScreenButton(
                              onPressed: !loading ? done : null,
                              text: "Connect Wallet",
                            ),
                            const SizedBox(width: 10),
                            loading
                                ? SizedBox(
                                    height: 25,
                                    width: 25,
                                    child: CircularProgressIndicator(
                                        value: null,
                                        backgroundColor: backgroundColor,
                                        color: textColor,
                                        strokeWidth: 2),
                                  )
                                : const SizedBox(width: 25),
                          ])))
                ])
              ]))
        ]));
  }
}
