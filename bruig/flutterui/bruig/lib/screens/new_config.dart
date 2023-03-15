import 'dart:async';

import 'package:bruig/models/newconfig.dart';
import 'package:bruig/screens/newconfig/delete_old_wallet.dart';
import 'package:bruig/screens/newconfig/initializing.dart';
import 'package:bruig/screens/newconfig/ln_choice.dart';
import 'package:bruig/screens/newconfig/ln_choice_external.dart';
import 'package:bruig/screens/newconfig/ln_choice_internal.dart';
import 'package:bruig/screens/newconfig/ln_wallet_seed.dart';
import 'package:bruig/screens/newconfig/ln_wallet_seed_confirm.dart';
import 'package:bruig/screens/newconfig/network_choice.dart';
import 'package:bruig/screens/newconfig/restore_wallet.dart';
import 'package:bruig/screens/newconfig/server.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

Future<void> runNewConfigApp(List<String> args) async {
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (c) => NewConfigModel(args)),
    ],
    child: NewConfigScreen(args),
  ));
}

class NewConfigScreen extends StatefulWidget {
  final List<String> args;
  const NewConfigScreen(this.args, {Key? key}) : super(key: key);

  @override
  State<NewConfigScreen> createState() => _NewConfigScreenState();
}

class _NewConfigScreenState extends State<NewConfigScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NewConfigModel>(builder: (context, newconf, child) {
      return MaterialApp(
        title: "Setup New Config",
        theme: ThemeData(
          primarySwatch: Colors.green, // XXX THEMEDATA HERE??
        ),
        initialRoute: "/newconf/initializing",
        routes: {
          "/newconf/initializing": (context) =>
              InitializingNewConfPage(newconf),
          "/newconf/confirm": (context) => ConfirmLNWalletSeedPage(newconf),
          "/newconf/deleteOldWallet": (context) => DeleteOldWalletPage(newconf),
          "/newconf/networkChoice": (context) => NetworkChoicePage(newconf),
          "/newconf/lnChoice": (context) => LNChoicePage(newconf),
          "/newconf/lnChoice/internal": (context) =>
              LNInternalWalletPage(newconf),
          "/newconf/lnChoice/external": (context) =>
              LNExternalWalletPage(newconf),
          "/newconf/server": (context) => ServerPage(newconf),
          "/newconf/seed": (context) => NewLNWalletSeedPage(newconf),
          "/newconf/restore": (context) => RestoreWalletPage(newconf),
        },
        builder: (BuildContext context, Widget? child) => Scaffold(
          body: Center(child: child),
        ),
      );
    });
  }
}
