import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';
import 'package:http/http.dart' as http;

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
  String host = "192.168.45.141"; // 서버 Host
  List<Map<String, dynamic>> chats = [];
  TextEditingController _chatController = TextEditingController();
  var scrollController = ScrollController();
  Map<int, String> lastReadStatus = {}; // userId : lastReadMessageId
  Map<String, List<int>> readStateByMessage = {}; // messageId : [userId]
  int userId = 5;

  Future<void> _getMessages() async {
    String url = "http://$host:8080/api/chat/1?size=22";
    var response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      var json = jsonDecode(response.body); // json decode
      print(json);
      for (int i = 0; i < json.length; ++i) {
        // var parsed = jsonDecode(json[i]);
        chats.add(json[i]);
      }
      //print(chats.map((e) => e['id']).toList());
      setState(() {
        // chats.addAll(json);
      });
    }
  }

  Future<void> _getReadStatus() async {
    String url = "http://$host:8080/api/chat/readStatus/1";

    var response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      var json = jsonDecode(response.body) as List; // json decode
      print(json);

      for (var element in json) {
        lastReadStatus[element['userId']] = element['messageId'];
      }
      setState(() {
        lastReadStatus.forEach((key, value) {
          if (readStateByMessage.containsKey(value)) {
            readStateByMessage[value]!.add(key);
          } else {
            readStateByMessage[value] = [key];
          }
        });
        print(lastReadStatus);
      });
    }
  }

  init() {
    // if(stompClient!.isActive)
    stompClient = StompClient(
        config: StompConfig(
      url: "ws://$host:8080/chat",
      stompConnectHeaders: {"userId": userId.toString(), "roomId": '1'},
      // 접속할 때의 헤더
      // 소켓 연결 URL (에뮬레이터 테스트 시 localhost 사용 불가능)
      onConnect: (StompFrame frame) {
        // STOMP 연결 콜백
        print("Connection Command: ${frame.command}");

        _getReadStatus();
        stompClient?.subscribe(
            headers: {"userId": userId.toString()}, // 구독할 때의 헤더
            // 클라이언트가 소켓 구독
            destination: "/exchange/sottie.chat.exchange/*.room.1", // 대상 경로
            callback: (frame) {
              // 수신 받은 frame(데이터)
              print("Payload: ${frame.command}");
              print(frame.body);
              var json = jsonDecode(frame.body!);

              if (json['event'] == 'UPDATE_READ_STATUS') {
                // if (json['data']['userId'] == userId) {
                //   print('본인은 제외');
                //   return;
                // } else {
                print(json['data']['lastReadMessageId']);
                setState(() {
                  print('Before: $readStateByMessage');
                  lastReadStatus[json['data']['userId']] =
                      json['data']['lastReadMessageId'];
                  print('Last: $lastReadStatus');

                  readStateByMessage.clear();
                  lastReadStatus.forEach((key, value) {
                    if (readStateByMessage.containsKey(value)) {
                      readStateByMessage[value]!.add(key);
                    } else {
                      readStateByMessage[value] = [key];
                    }
                  });
                  print('After $readStateByMessage');
                });

                // }
              }
              if (json['event'] == 'SEND_MESSAGE') {
                setState(() {
                  chats.insert(0, json['data']);
                  // chat list의 id랑 messageId 키가 달라서 그럼 -> API 채팅 목록이랑 소켓 통신 포맷 맞춰야됨
                });
                if (json['data']['userId'] != userId)
                  readMessage(json['data']['messageId']);
              }
            });
      },
      onStompError: (frame) {
        print('onStompError: ${frame.command}');
        if (frame.command == 'ERROR') {
          stompClient?.deactivate();
        }
      },
      onDisconnect: (frame) => print("onDisconnect $frame"),
      beforeConnect: () async => print("beforeConnect"),
      onWebSocketError: (error) =>
          print('onWebSocketError: ${error.toString()}'),
      onWebSocketDone: () => print('onWebSocketDone'),
      heartbeatIncoming: Duration(milliseconds: 30000),
      heartbeatOutgoing: Duration(milliseconds: 30000),
    ));
    print('a');
    stompClient?.activate(); // STOMP 연결 활성화
    print('b');
  }

  @override
  void initState() {
    // init();
    _getMessages();
    scrollController.addListener(() async {
      if (scrollController.position.atEdge &&
          scrollController.position.pixels ==
              scrollController.position.maxScrollExtent) {}
    });
    super.initState();
  }

  void _sendMessage(String content) {
    Map<String, dynamic> map = {
      "userId": userId,
      "contents": content,
      "messageType": "TEXT",
      "chatType": "CHAT"
    };
    stompClient?.send(
        destination: "/pub/chat.talk.1",
        body: jsonEncode(map),
        headers: {"userId": userId.toString()});
  }

  void readMessage(String messageId) {
    Map<String, dynamic> map = {"userId": userId, "messageId": messageId};
    stompClient?.send(destination: "/pub/chat.read.1", body: jsonEncode(map));
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: Icon(Icons.exit_to_app),
          onPressed: () {
            setState(() {
              userId = 3;
            });
            init();
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.exit_to_app),
            onPressed: () {
              setState(() {
                userId = 2;
              });
              init();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              child: ListView.builder(
                controller: scrollController,
                padding: EdgeInsets.all(size.width * 0.01),
                reverse: true,
                itemBuilder: (context, index) {
                  // print('Id: ${chats[index]["id"]}');
                  return Column(
                    children: [
                      Align(
                        alignment: chats[index]['userId'] == userId
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          child: Text(
                              "${chats[index]['userId']}: ${chats[index]['contents']}\n"
                              "Read: ${readStateByMessage[chats[index]["messageId"]]}"),
                          padding: EdgeInsets.all(size.width * 0.02),
                          decoration: BoxDecoration(
                              border: Border.all(width: 1),
                              borderRadius: BorderRadius.circular(8),
                              color: chats[index]['userId'] == userId
                                  ? Colors.grey[300]
                                  : Colors.orange[300]),
                        ),
                      ),
                    ],
                  );
                },
                itemCount: chats.length,
                // shrinkWrap: true,
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: size.width * 0.8,
                child: TextField(
                  controller: _chatController,
                ),
                decoration: BoxDecoration(border: Border.all(width: 0.5)),
              ),
              Expanded(
                  child: TextButton(
                      onPressed: () {
                        _sendMessage(_chatController.text);
                      },
                      child: Text('전송')))
            ],
          )
        ],
      ),
    );
  }
}
