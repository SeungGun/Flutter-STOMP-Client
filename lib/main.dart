import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';

void main() {
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
      home: const MyHomePage(title: 'Flutter STOMP-Client Demo'),
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
  StompClient? stompClient;
  String content = "";
  String host = ""; // 서버 Host
  List<Map<String, dynamic>> chats = [];

  init() {
    stompClient = StompClient(
        config: StompConfig(
      url: "ws://$host:8080/chat", // 소켓 연결 URL (에뮬레이터 테스트 시 localhost 사용 불가능)
      onConnect: (StompFrame frame) { // STOMP 연결 콜백
        print("Connection Command: ${frame.command}");

        stompClient?.subscribe( // 클라이언트가 소켓 구독
            destination: "/exchange/chat.exchange/*.room.1", // 대상 경로
            callback: (frame) { // 수신 받은 frame(데이터)
              print("Payload: ${frame.body}");
              var json = jsonDecode(frame.body!); // json decode
              setState(() {
                content = json["content"];
                chats.add(json);
              });
            });
      },
      beforeConnect: () async {
        print("연결 중입니다.");
      },
      onWebSocketError: (error) => print(error.toString()),
      onWebSocketDone: () {
        print('연결됐음');
      },
    ));
    stompClient?.activate(); // STOMP 연결 활성화
  }

  @override
  void initState() {
    init();
    super.initState();
  }

void _sendMessage() {
    Map<String, String> map = {"title": "me", "content": "안녕하세요."};
    stompClient?.send(destination: "/pub/chat.talk.1", body: jsonEncode(map));
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: ListView.builder(
        padding: EdgeInsets.all(size.width * 0.01),
        itemBuilder: (context, index){
          return Column(
            children: [
              Align(
                alignment: chats[index]['title'] == "me" ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  child: Text(chats[index]['content']!),
                  padding: EdgeInsets.all(size.width * 0.02),
                  decoration: BoxDecoration(
                    border: Border.all(width: 1),
                    borderRadius: BorderRadius.circular(8),
                    color: chats[index]['title'] == "me" ? Colors.grey[300] : Colors.orange[300]
                  ),
                ),
              ),
            ],
          );
        },
        itemCount: chats.length,
        // shrinkWrap: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _sendMessage,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
