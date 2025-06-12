import 'package:bruig/components/empty_widget.dart';
import 'package:bruig/components/md_elements.dart';
import 'package:bruig/components/inputs.dart';
import 'package:bruig/models/resources.dart';
import 'package:bruig/models/snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

class StyleElementBuilder extends MarkdownElementBuilder {
  StyleElementBuilder();

  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    if (element is! StyleElement) {
      return const Text("not-a-style-element",
          style: TextStyle(color: Colors.amber));
    }
    StyleElement style = element;
    return PageContainer(style);
  }
}

class PageContainer extends StatefulWidget {
  final StyleElement style;
  const PageContainer(this.style, {super.key});

  @override
  PageContainerState createState() {
    return PageContainerState();
  }
}

class PageContainerState extends State<PageContainer> {
  final _styleKey = GlobalKey<PageContainerState>();
  StyleElement get style => widget.style;
  @override
  Widget build(BuildContext context) {
    FormField? submit;

    List<Widget> fieldWidgets = [];
    for (var field in style.fields) {
      switch (field.type) {
        case "bg-color":
          break;
        case "fg-color":
          break;
        case "fontsize":
          break;
        default:
          debugPrint("Unknown field type ${field.type}");
      }
    }

    // Build a Form widget using the _styleKey created above.
    return Container(
      key: _styleKey,
      child: Column(
        children: <Widget>[
          ...fieldWidgets,
          const SizedBox(height: 10),
          const Empty(),
          // Add TextFormFields and ElevatedButton here.
        ],
      ),
    );
  }
}

class StyleElement extends md.Element {
  final List<StyleField> fields;

  StyleElement(this.fields) : super("style", [md.Text("")]);
}

class StyleField {
  final String type;
  dynamic value;

  StyleField(this.type, {this.value});
}

class StyleBlockSyntax extends md.BlockSyntax {
  static String closeTag = r'--/style--';
  static RegExp tagPattern = RegExp(r'^--style--$');
  static RegExp fieldPattern = RegExp(r'([\w]+)="([^"]*)"');

  @override
  RegExp get pattern => tagPattern;

  @override
  bool canEndBlock(md.BlockParser parser) =>
      parser.current.content == "--/style--";

  @override
  md.Node? parse(md.BlockParser parser) {
    parser.advance();
    List<StyleField> children = [];

    while (!parser.isDone && !md.BlockSyntax.isAtBlockEnd(parser)) {
      if (parser.current.content == closeTag) {
        parser.advance();
        continue;
      }

      var matches = fieldPattern.allMatches(parser.current.content);
      String type = "";
      Map<Symbol, dynamic> args = {};
      for (var m in matches) {
        if (m.groupCount < 2) {
          continue;
        }
        String name = m.group(1)!;
        String value = m.group(2)!;
        switch (name) {
          case "type":
            type = value;
            break;
          case "value":
            args[Symbol(name)] = value;
            break;
        }
      }

      StyleField field = Function.apply(StyleField.new, [type], args);
      children.add(field);
      parser.advance();
    }

    var res = md.Element("p", [StyleElement(children)]);
    print(res.children);
    return res;
  }
}
