import 'dart:convert' show AsciiDecoder;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:isolate_agents/isolate_agents.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:flutter/services.dart' show rootBundle;

/// State held by the [Agent].  It just stores the last decoded message and the
/// number decoded so far.  There is no need to cache previously decoded
/// messages since they are stored in the widgets.
class _DecoderState {
  _DecoderState(this.decodedMessages, this.stillDecoding);
  final List<String> decodedMessages;
  final bool stillDecoding;
}

// This is the agent that is used to seed the fake messages and decrypt them.
Agent<_DecoderState>? _agent;

Future<Agent<_DecoderState>> _getAgent() async {
  _agent ??= await Agent.create(_DecoderState(<String>[], true));
  return _agent!;
}

String _rot13Encode(String input) {
  List<int> output = [];

  for (int codeUnit in input.codeUnits) {
    if (codeUnit >= 32 && codeUnit <= 126) {
      int normalized = codeUnit - 32;
      int rot = (normalized + 13);
      if (rot > 94) {
        rot -= 94;
      }
      output.add(rot + 32);
    } else {
      output.add(codeUnit);
    }
  }

  return const AsciiDecoder().convert(output);
}

String _rot13Decode(String input) {
  List<int> output = [];

  for (int codeUnit in input.codeUnits) {
    if (codeUnit >= 32 && codeUnit <= 126) {
      int normalized = codeUnit - 32;
      int rot = normalized - 13;
      if (rot < 0) {
        rot += 94;
      }
      output.add(rot + 32);
    } else {
      output.add(codeUnit);
    }
  }

  return const AsciiDecoder().convert(output);
}

Future<void> _loadMessage(Agent<_DecoderState> agent, int index) async {
  Directory documentsPath =
      await path_provider.getApplicationDocumentsDirectory();
  agent.send((state) {
    File file = File('${documentsPath.path}/$index.rot');
    if (file.existsSync()) {
      String encoded = file.readAsStringSync();
      state.decodedMessages.add(_rot13Decode(encoded));
      return _DecoderState(state.decodedMessages, true);
    } else {
      return _DecoderState(state.decodedMessages, false);
    }
  });
}

/// Store on disk all of the fake text messages encrypted so we can load
/// then from the Agent.  We execute this on the [Agent] to make sure that
/// it is done before we start decrypting messages.
Future<void> _encodeMessages() async {
  Directory documentsPath =
      await path_provider.getApplicationDocumentsDirectory();
  Agent<_DecoderState> agent = await _getAgent();
  String text = await rootBundle.loadString('assets/romeojuliet.txt');
  agent.send((state) {
    List<String> lines = text.split('\n\n');
    int i = 0;
    for (String line in lines) {
      String encoded = _rot13Encode(line.trim());
      File('${documentsPath.path}/$i.rot').writeAsStringSync(encoded);
      i += 1;
    }
    // Leave in init state.
    return state;
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _encodeMessages();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Romeo Juliet'),
    );
  }
}

class _Message extends StatefulWidget {
  const _Message(this.alignment, this.index);

  final TextAlign alignment;
  final int index;

  @override
  State<StatefulWidget> createState() {
    return _MessageState();
  }
}

Future<String?> _queryMessage(int index) async {
  Agent<_DecoderState> agent = await _getAgent();
  return agent.query((state) => state.decodedMessages[index]);
}

class _MessageState extends State<_Message> {
  String? _text;

  @override
  void initState() {
    super.initState();
    _getAgent().then((agent) async {
      _queryMessage(widget.index).then((decoded) {
        if (mounted) {
          setState(() {
            _text = decoded;
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets margin = widget.alignment == TextAlign.left
        ? const EdgeInsets.fromLTRB(10, 10, 30, 30)
        : const EdgeInsets.fromLTRB(30, 10, 10, 30);
    final String name = widget.alignment == TextAlign.left ? 'Romeo' : 'Juliet';
    final Color color =
        widget.alignment == TextAlign.left ? Colors.lightBlue : Colors.grey;
    return _text == null
        ? Container()
        : Column(children: [
            SizedBox(
                width: double.infinity,
                height: 20,
                child: Text(
                  name,
                  style: _textStyle,
                  textAlign: widget.alignment,
                )),
            SizedBox(
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.all(Radius.circular(20))),
                margin: margin,
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                child: Text(
                  _text!,
                  textAlign: TextAlign.left,
                  style: _textStyle,
                ),
              ),
            )
          ]);
  }
}

const TextStyle _textStyle = TextStyle(fontSize: 16);

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() {
    return _MyHomePageState();
  }
}

class _MyHomePageState extends State<MyHomePage> {
  int _count = 0;

  Future<void> startCounting() async {
    bool keepLoading = true;
    while (keepLoading) {
      final Agent<_DecoderState> agent = await _getAgent();
      await _loadMessage(agent, _count);
      final int count =
          await agent.query((state) => state.decodedMessages.length);
      setState(() {
        _count = count;
      });
      keepLoading = await agent.query((state) => state.stillDecoding);
      await Future.delayed(const Duration(milliseconds: 1000));
    }
  }

  @override
  void initState() {
    startCounting();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: ListView.builder(
          padding: const EdgeInsets.fromLTRB(0, 25, 0, 25),
          itemCount: _count,
          itemBuilder: ((context, index) {
            if (index % 2 == 0) {
              return _Message(TextAlign.left, index);
            } else {
              return _Message(TextAlign.right, index);
            }
          })),
    );
  }
}
