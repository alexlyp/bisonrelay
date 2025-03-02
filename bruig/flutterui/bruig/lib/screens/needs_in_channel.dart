import 'dart:async';

import 'package:bruig/components/dcr_input.dart';
import 'package:bruig/components/buttons.dart';
import 'package:bruig/components/info_grid.dart';
import 'package:bruig/components/snackbars.dart';
import 'package:bruig/models/client.dart';
import 'package:bruig/models/notifications.dart';
import 'package:flutter/material.dart';
import 'package:golib_plugin/golib_plugin.dart';
import 'package:golib_plugin/util.dart';
import 'package:tuple/tuple.dart';

class NeedsInChannelScreen extends StatefulWidget {
  final AppNotifications ntfns;
  final ClientModel client;
  const NeedsInChannelScreen(this.ntfns, this.client, {Key? key})
      : super(key: key);

  @override
  State<NeedsInChannelScreen> createState() => _NeedsInChannelScreenState();
}

class _NeedsInChannelScreenState extends State<NeedsInChannelScreen> {
  ClientModel get client => widget.client;

  String addr = "";
  int initialMaxInAmount = -1;
  int maxOutAmount = 0;
  int maxInAmount = 0;
  int walletBalance = 0;
  int numPendingChannels = 0;
  int numChannels = 0;
  Timer? updateTimer;
  bool loading = false;
  TextEditingController serverCtrl = TextEditingController();
  TextEditingController certCtrl = TextEditingController();
  AmountEditingController amountCtrl = AmountEditingController();

  void getNewAddress() async {
    try {
      var res = await Golib.lnGetDepositAddr();
      setState(() {
        addr = res;
      });
    } catch (exception) {
      showErrorSnackbar(context, "Unable to load deposit address: $exception");
    }
  }

  void updateBalance(bool resetTimer) async {
    try {
      var res = await Golib.lnGetBalances();
      var resInfo = await Golib.lnGetInfo();
      setState(() {
        maxOutAmount = res.channel.maxOutboundAmount;
        maxInAmount = res.channel.maxInboundAmount;
        walletBalance = res.wallet.totalBalance;
        numPendingChannels = resInfo.numPendingChannels;
        numChannels = resInfo.numActiveChannels;
      });

      if (initialMaxInAmount == -1) {
        initialMaxInAmount = res.channel.maxInboundAmount;
      }

      if (res.channel.maxInboundAmount > 0) {
        widget.ntfns.delType(AppNtfnType.walletNeedsInChannels);

        if (res.channel.maxInboundAmount > initialMaxInAmount) {
          Navigator.of(context).pop();
        }
      }
    } catch (exception) {
      showErrorSnackbar(context, "Unable to update wallet balance: $exception");
    } finally {
      if (resetTimer) {
        updateTimer =
            Timer(const Duration(seconds: 5), () => updateBalance(true));
      }
    }
  }

  void requestRecvCapacity() async {
    if (serverCtrl.text == "") {
      showErrorSnackbar(context, "Liquidity provider server cannot be empty");
      return;
    }

    if (amountCtrl.amount < 0.00001) {
      showErrorSnackbar(
          context, "Channel size to request liquidity is too low");
      return;
    }

    setState(() => loading = true);
    try {
      await Golib.lnRequestRecvCapacity(
          serverCtrl.text, "", amountCtrl.amount, certCtrl.text);
      setState(() {
        serverCtrl.clear();
        amountCtrl.clear();
      });
    } catch (exception) {
      showErrorSnackbar(
          context, "Unable to request receive capacity: $exception");
    } finally {
      setState(() => loading = false);
      updateBalance(false);
    }
  }

  void verifyNetwork() async {
    try {
      var res = await Golib.lnGetInfo();
      if (res.chains[0].network == "mainnet") {
        setState(() {
          serverCtrl.text = "https://lp0.bisonrelay.org:9130";
          certCtrl.text = """-----BEGIN CERTIFICATE-----             
MIIBwjCCAWmgAwIBAgIQA78YKmDt+ffFJmAN5EZmejAKBggqhkjOPQQDAjAyMRMw
EQYDVQQKEwpiaXNvbnJlbGF5MRswGQYDVQQDExJscDAuYmlzb25yZWxheS5vcmcw
HhcNMjIwOTE4MTMzNjA4WhcNMzIwOTE2MTMzNjA4WjAyMRMwEQYDVQQKEwpiaXNv
bnJlbGF5MRswGQYDVQQDExJscDAuYmlzb25yZWxheS5vcmcwWTATBgcqhkjOPQIB
BggqhkjOPQMBBwNCAASF1StlsfdDUaCXMiZvDBhhMZMdvAUoD6wBdS0tMBN+9y91
UwCBu4klh+VmpN1kCzcR6HJHSx5Cctxn7Smw/w+6o2EwXzAOBgNVHQ8BAf8EBAMC
AoQwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUqqlcDx8e+XgXXU9cXAGQEhS8
59kwHQYDVR0RBBYwFIISbHAwLmJpc29ucmVsYXkub3JnMAoGCCqGSM49BAMCA0cA
MEQCIGtLFLIVMnU2EloN+gI+uuGqqqeBIDSNhP9+bznnZL/JAiABsLKKtaTllCSM
cNPr8Y+sSs2MHf6xMNBQzV4KuIlPIg==                                
-----END CERTIFICATE-----""";
        });
      } else if (res.chains[0].network == "simnet") {
        setState(() {
          serverCtrl.text = "https://127.0.0.1:29130";
        });
      }
    } catch (exception) {
      showErrorSnackbar(context, "Unable to verify network: $exception");
    }
  }

  @override
  void initState() {
    super.initState();
    verifyNetwork();
    getNewAddress();
    updateBalance(true);
  }

  @override
  void dispose() {
    updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var backgroundColor = const Color(0xFF19172C);
    var cardColor = const Color(0xFF05031A);
    var textColor = const Color(0xFF8E8D98);
    var secondaryTextColor = const Color(0xFFE4E3E6);
    var darkTextColor = const Color(0xFF5A5968);

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
                      Text("Setting up Bison Relay",
                          style: TextStyle(
                              color: textColor,
                              fontSize: 34,
                              fontWeight: FontWeight.w200)),
                      const SizedBox(height: 20),
                      Text("Add Inbound Capacity",
                          style: TextStyle(
                              color: secondaryTextColor,
                              fontSize: 21,
                              fontWeight: FontWeight.w300)),
                      const SizedBox(height: 34),
                      Text('''
The wallet requires LN channels with inbound capacity to receive funds
to be able to receive payments from other users.

One way of opening a channel with inbound capacity is to pay for a node to open
a channel back to your LN wallet. This is done through a "Liquidity Provider"
service.

Note that having a channel with inbound capacity is for sending or receiving 
messages. It is only required in order to receive payments from other users.
''',
                          style: TextStyle(
                              color: secondaryTextColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w300)),
                      const SizedBox(height: 21),
                      Container(
                          margin: const EdgeInsets.only(
                              left: 324 + 22, right: 324 + 20),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                    textAlign: TextAlign.left,
                                    "Outbound Channel Capacity:",
                                    style: TextStyle(
                                        color: darkTextColor,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w300)),
                                Text(
                                    textAlign: TextAlign.right,
                                    "$formatDCR(atomsToDCR(maxOutAmount))",
                                    style: TextStyle(
                                        color: darkTextColor,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w300)),
                              ])),
                      const SizedBox(height: 3),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                                textAlign: TextAlign.left,
                                "Inbound Channel Capacity:",
                                style: TextStyle(
                                    color: darkTextColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w300)),
                            Text(
                                textAlign: TextAlign.right,
                                "$formatDCR(atomsToDCR(maxInAmount))",
                                style: TextStyle(
                                    color: darkTextColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w300))
                          ]),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                                textAlign: TextAlign.left,
                                "Pending Channels:",
                                style: TextStyle(
                                    color: darkTextColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w300)),
                            Text(
                                textAlign: TextAlign.right,
                                "$numPendingChannels",
                                style: TextStyle(
                                    color: darkTextColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w300))
                          ]),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                                textAlign: TextAlign.left,
                                "Active Channels:",
                                style: TextStyle(
                                    color: darkTextColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w300)),
                            Text(
                                textAlign: TextAlign.right,
                                "$numChannels",
                                style: TextStyle(
                                    color: darkTextColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w300))
                          ]),
                      const SizedBox(height: 10),
                      Expanded(
                          child: SimpleInfoGrid([
                        Tuple2(
                            Text("LP Server Address",
                                style: TextStyle(
                                    color: darkTextColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w300)),
                            TextField(
                              controller: serverCtrl,
                              decoration: const InputDecoration(
                                  hintText: "https://lpd-server:port"),
                            )),
                        Tuple2(
                            Text("LP Server Cert",
                                style: TextStyle(
                                    color: darkTextColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w300)),
                            TextField(
                              controller: certCtrl,
                              maxLines: null,
                              keyboardType: TextInputType.multiline,
                            )),
                        Tuple2(
                            Text("Amount",
                                style: TextStyle(
                                    color: darkTextColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w300)),
                            SizedBox(
                              width: 150,
                              child: dcrInput(controller: amountCtrl),
                            )),
                        Tuple2(
                            const SizedBox(height: 50),
                            LoadingScreenButton(
                              onPressed: !loading ? requestRecvCapacity : null,
                              text: "Request Inbound Channel",
                            ))
                      ])),
                      LoadingScreenButton(
                        onPressed: () => Navigator.of(context).pop(),
                        text: "Skip",
                      )
                    ],
                  )),
            ])));
  }
}
