import 'dart:async';
import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/services.dart';

class EventPrintPos {
  static const MethodChannel channel = MethodChannel('com.clv.demo/print');
  static const MethodChannel channelPrint = MethodChannel('com.clv.demo/print');
  static const MethodChannel channelPrintIos = MethodChannel('flutter_scan_bluetooth');


  // Get battery level.
  static Future<String> getBatteryLevel() async {
    String batteryLevel;
    try {
      final int result = await channel.invokeMethod('getBatteryLevel');
      batteryLevel = 'Battery level: $result%.';
    } on PlatformException {
      batteryLevel = 'Failed to get battery level.';
    }
    return batteryLevel;
  }

  static Future<String> getMessage() async {
    String value = "";
    try {
      value = await channelPrint.invokeMethod("getMessage");
      print(value);
    } catch (e) {
      print(e);
    }
    return value;
  }

  static Future<dynamic> sendSignalPrint(
      Uint8List capturedImage, int countPage) async {
    var _sendData = <String, dynamic>{
      "bitmapInput": capturedImage,
      "printerDpi": 190, //190
      "printerWidthMM": int.parse('80'),
      "printerNbrCharactersPerLine": 32,
      "widthMax": 580, //580
      "heightMax": 400, //400
      "countPage": countPage
    };
    var result;
    if (Platform.isAndroid) {
      result = await channel.invokeMethod("onPrint", _sendData);
    } else if (Platform.isIOS) {
      result = await channelPrintIos.invokeMethod("onPrint", _sendData);
    }

    print(result);
    return result;
  }

  static Future<String> onBluetooth() async {
    var result = await channelPrint.invokeMethod("onBluetooth");
    return result;
  }

  static Future<dynamic> offBluetooth() async {
    var result = await channelPrint.invokeMethod("offBluetooth");
    return result;
  }

}
