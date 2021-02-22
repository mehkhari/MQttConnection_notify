import 'package:mqtt_client/mqtt_client.dart' as mqtt;

class Messages{
  final String topic;
  final String message;
  final mqtt.MqttQos qos;

  Messages({this.topic, this.message, this.qos});
}