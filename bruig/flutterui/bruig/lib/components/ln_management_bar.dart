import 'package:flutter/material.dart';

class LNManagementBar extends StatefulWidget {
  final int selectedIndex;
  final Function tabChange;
  const LNManagementBar(this.tabChange, this.selectedIndex, {Key? key})
      : super(key: key);

  @override
  State<LNManagementBar> createState() => _LNManagementBarState();
}

class _LNManagementBarState extends State<LNManagementBar> {
  int get selectedIndex => widget.selectedIndex;
  Function get tabChange => widget.tabChange;
  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(LNManagementBar oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var unselectedTextColor = theme.dividerColor;
    var selectedTextColor = theme.focusColor; // MESSAGE TEXT COLOR
    var sidebarBackground = theme.backgroundColor;
    var hoverColor = theme.hoverColor;
    return Container(
        margin: const EdgeInsets.all(1),
        width: 118,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          gradient: LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: [
                hoverColor,
                sidebarBackground,
                sidebarBackground,
              ],
              stops: const [
                0,
                0.51,
                1
              ]),
        ),
        //color: theme.colorScheme.secondary,
        child: ListView(children: [
          ListTile(
            title: Text("Overview",
                style: TextStyle(
                    color: selectedIndex == 0
                        ? selectedTextColor
                        : unselectedTextColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w400)),
            onTap: () {
              tabChange(0);
            },
          ),
          ListTile(
            title: Text("Channels",
                style: TextStyle(
                    color: selectedIndex == 1
                        ? selectedTextColor
                        : unselectedTextColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w400)),
            onTap: () {
              tabChange(1);
            },
          ),
          ListTile(
            title: Text("Payments",
                style: TextStyle(
                    color: selectedIndex == 2
                        ? selectedTextColor
                        : unselectedTextColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w400)),
            onTap: () {
              tabChange(2);
            },
          ),
          ListTile(
            title: Text("Network",
                style: TextStyle(
                    color: selectedIndex == 3
                        ? selectedTextColor
                        : unselectedTextColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w400)),
            onTap: () {
              tabChange(3);
            },
          ),
        ]));
  }
}
