import 'dart:async';

import 'package:cli_script/cli_script.dart' as cs;
import 'package:clipboard/clipboard.dart';
import 'package:fast_overlays/fast_overlays.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

late SharedPreferences prefs;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  prefs = await SharedPreferences.getInstance();
  if (prefs.getKeys().isEmpty) {
    //RAINY We could probably set it up to permit empty sets AND initial defaults, but it'd take more work
    await prefs.setString("(.*amazon\\.com.*)(/dp/)(\\w+)/.*", "\\1\\2\\3"); // Amazon
    await prefs.setString("(.*://.*)\\?.+", "\\1");
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      navigatorKey: FastOverlays.init(),
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var str = "";
  Map<String, String> transforms = {}; //DUMMY Probably surprising to only be able to store one of a key

  String newKey = "";
  String newValue = "";
  String testResult = "";

  @override
  void initState() {
    super.initState();
    unawaited(Future(() async {
      Map<String, String> transforms = {};
      for (var k in prefs.getKeys()) {
        var v = prefs.getString(k);
        if (v != null) {
          transforms[k] = v;
        }
      }
      setState(() {
        this.transforms = transforms;
      });
      while (true) {
        await Future.delayed(Duration(milliseconds: 500));
        var s = await FlutterClipboard.paste();
        setState(() {
          this.str = s;
        });
      }
    }));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: ListView(
          children: <Widget>[
            Text("Clipboard:\n$str"),
            for (var e in transforms.entries) ElevatedButton(
              child: Text("`${e.key}` -> `${e.value}`"),
              onPressed: () async {
                final newString = await cs.replace(e.key, e.value, all: true).bind(Stream.value(str)).first;
                await FlutterClipboard.copy(newString);
                setState(() {
                  str = newString;
                });
              }, onLongPress: () async {
                FastOverlays.showGeneralDialog(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                    AlertDialog(
                      title: const Text('Remove transform?'),
                      actions: [
                        TextButton(
                          child: const Text('Cancel'),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        TextButton(
                          child: const Text('Remove'),
                          onPressed: () async {
                            transforms.remove(e.key);
                            await prefs.remove(e.key);
                            Navigator.of(context).pop();
                            setState(() { // pop probaly already does this
                            });
                          },
                        )
                      ],
                    ),
                );
              },
            ),
            TextFormField(onChanged: (value) => (newKey = value),), //DUMMY Hint
            TextFormField(onChanged: (value) => (newValue = value),), //DUMMY Hint
            Row(children: [
              ElevatedButton(child: Text("Test"), onPressed: () async {
                final newString = await cs.replace(newKey, newValue, all: true).bind(Stream.value(str)).first;
                setState(() {
                  testResult = newString;
                });
              },),
              ElevatedButton(child: Text("Save"), onPressed: () async {
                await prefs.setString(newKey, newValue);
                setState(() {
                  transforms[newKey] = newValue;
                });
              },),
            ],),
            Text(testResult),
          ],
        ),
      ),
    );
  }
}
