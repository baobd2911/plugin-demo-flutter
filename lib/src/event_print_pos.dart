import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';

class EventPrintPos {
  static const MethodChannel channel = MethodChannel('com.clv.demo/print');
  static const MethodChannel channelPrint = MethodChannel('com.clv.demo/print');
  static const MethodChannel getListBluetoothPrinters =
      MethodChannel('com.clv.demo/getListBluetoothPrinters');
  static const MethodChannel checkState =
      MethodChannel('com.clv.demo/checkState');

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
      "printerDpi": 180, //190
      "printerWidthMM": int.parse('80'),
      "printerNbrCharactersPerLine": 32,
      "widthMax": 580, //580
      "heightMax": 400, //400
      "countPage": countPage
    };
    var result = await channelPrint.invokeMethod("onPrint", _sendData);
    print(result);
    return result;
  }

  static Future<String> onBluetooth() async {
    var result = await channelPrint.invokeMethod("onBluetooth");
    return result;

    // String mList = await getListBluetoothPrinters.invokeMethod("onBluetooth");
    // print(mList);
    // return Future.value(mList);
  }

  static Future<dynamic> offBluetooth() async {
    var result = await channelPrint.invokeMethod("offBluetooth");
    return result;
  }

  static Future<bool> checkStateBluetooth() async {
    bool result = await checkState.invokeMethod("checkStateBluetooth");
    return result;
  }

  static Future<String> scanBluetooth() async {
    String mList =
        await getListBluetoothPrinters.invokeMethod("scanDeviceBluetooth");
    print(mList);
    return Future.value(mList);
  }
}
