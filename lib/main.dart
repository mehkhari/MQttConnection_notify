import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mqtt_client/mqtt_client.dart'as mqtt;
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:mqttdemo/message.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin=FlutterLocalNotificationsPlugin();

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  var initializationSettingsAndroid=AndroidInitializationSettings('notify');
  var initializationSettingsIOS=IOSInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
    onDidReceiveLocalNotification: (int id,String title,String body,String payload)async{});
  var initializationSettings=InitializationSettings(android: initializationSettingsAndroid,iOS: initializationSettingsIOS);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings,onSelectNotification: (String payload)async{
    if(payload!=null){
      debugPrint('Notification Payload'+payload);
    }
  });
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'Alert Nofitication'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool isSwitch=false;
  bool isConnection =false;
  String titleBar         = 'MQTT';
  String broker           = 'broker.hivemq.com';
  int port                = 1883;
  String username         = 'wbpwjaso';
  String passwd           = 'eO-kjpnhyvrI';
  String clientIdentifier = 'lamhx';

  mqtt.MqttClient client;
  mqtt.MqttConnectionState connectionState;

  StreamSubscription subscription;

  Set<String> topics = Set<String>();

  List<Messages> messages = <Messages>[];
  ScrollController messageController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            RaisedButton(onPressed: (){
              _connect();
            },child: Text(isConnection?'Online':'Offline'),),
            Switch(value: isConnection, onChanged: (value){
              setState(() {
                isConnection=false;
              });
            },
              activeTrackColor: Colors.lightGreenAccent,
              activeColor: Colors.green,
            ),
          ],
        ),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
  void scheduleAlert(String alertMessage)async{
    var scheduleNotificationDateTime=DateTime.now().add(Duration(
      milliseconds: 500
    ));
    var androidPlatformChannelSpecific=AndroidNotificationDetails(
        'alarm_notify',
        'alarm_notify',
        'channel for alarm_notify',
      icon: 'notify',
      sound: RawResourceAndroidNotificationSound('pikachu'),
      largeIcon: DrawableResourceAndroidBitmap('notify')
    );
    var platformChannelSpecifics=NotificationDetails(android: androidPlatformChannelSpecific);
    await flutterLocalNotificationsPlugin.schedule(
        0,
        'Alert Notification',
        '$alertMessage',
        scheduleNotificationDateTime,
        platformChannelSpecifics);
  }

  void _connect() async {
    /// First create a client, the client is constructed with a broker name, client identifier
    /// and port if needed. The client identifier (short ClientId) is an identifier of each MQTT
    /// client connecting to a MQTT broker. As the word identifier already suggests, it should be unique per broker.
    /// The broker uses it for identifying the client and the current state of the client. If you don’t need a state
    /// to be hold by the broker, in MQTT 3.1.1 you can set an empty ClientId, which results in a connection without any state.
    /// A condition is that clean session connect flag is true, otherwise the connection will be rejected.
    /// The client identifier can be a maximum length of 23 characters. If a port is not specified the standard port
    /// of 1883 is used.
    /// If you want to use websockets rather than TCP see below.
    ///
    MqttServerClient client = MqttServerClient.withPort('broker.hivemq.com', 'clientIdentifier', 1883);
    client.port = port;

    /// A websocket URL must start with ws:// or wss:// or Dart will throw an exception, consult your websocket MQTT broker
    /// for details.
    /// To use websockets add the following lines -:
    /// client.useWebSocket = true;
    /// client.port = 80;  ( or whatever your WS port is)
    /// Note do not set the secure flag if you are using wss, the secure flags is for TCP sockets only.
    /// Set logging on if needed, defaults to off
    client.logging(on: true);

    /// If you intend to use a keep alive value in your connect message that is not the default(60s)
    /// you must set it here
    client.keepAlivePeriod = 30;

    /// Add the unsolicited disconnection callback
    client.onDisconnected = _onDisconnected;

    /// Create a connection message to use or use the default one. The default one sets the
    /// client identifier, any supplied username/password, the default keepalive interval(60s)
    /// and clean session, an example of a specific one below.
    final mqtt.MqttConnectMessage connMess = mqtt.MqttConnectMessage()
        .withClientIdentifier(clientIdentifier)
    // Must agree with the keep alive set above or not set
        .startClean() // Non persistent session for testing
        .keepAliveFor(30)
    // If you set this you must set a will message
        .withWillTopic('test/test')
        .withWillMessage('lamhx message test')
        .withWillQos(mqtt.MqttQos.atMostOnce);
    print('MQTT client connecting....');
    client.connectionMessage = connMess;

    /// Connect the client, any errors here are communicated by raising of the appropriate exception. Note
    /// in some circumstances the broker will just disconnect us, see the spec about this, we however will
    /// never send malformed messages.

    try {
      await client.connect(username, passwd);
    } catch (e) {
      print(e);
      _disconnect();
    }

    /// Check if we are connected
    if (client.connectionState == mqtt.MqttConnectionState.connected) {
      print('MQTT client connected');
      client.subscribe('mqtt/alert', mqtt.MqttQos.exactlyOnce);
      setState(() {
        isConnection=true;
        connectionState = client.connectionState;
      });
    } else {
      print('ERROR: MQTT client connection failed - '
          'disconnecting, state is ${client.connectionState}');
      _disconnect();
    }

    /// The client has a change notifier object(see the Observable class) which we then listen to to get
    /// notifications of published updates to each subscribed topic.
    subscription = client.updates.listen(_onMessage);
  }

  void _disconnect() {
    client.disconnect();
    _onDisconnected();
  }

  void _onDisconnected() {
    setState(() {
      topics.clear();
      connectionState = client.connectionState;
      client = null;
      subscription.cancel();
      subscription = null;
      isConnection=false;
    });
    print('MQTT client disconnected');
  }

  void _onMessage(List<mqtt.MqttReceivedMessage> event) {
    print(event.length);
    final mqtt.MqttPublishMessage recMess =
    event[0].payload as mqtt.MqttPublishMessage;
    final String message =
    mqtt.MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
    print('MQTT message: topic is <${event[0].topic}>, '
        'payload is <-- ${message} -->');
    scheduleAlert(message);
    print(client.connectionState);
  }
}
