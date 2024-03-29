import 'dart:typed_data';
import 'dart:io' show Platform;

import 'package:clv_nhacvo_print/src/bluetooth_print_model.dart';
import 'package:clv_nhacvo_print/src/bluetooth_code.dart';
import 'package:clv_nhacvo_print/src/event_print_pos.dart';
import 'package:clv_nhacvo_print/src/flutter_scan_bluetooth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:measure_size/measure_size.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';

import 'DevicesModel.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Nhạc Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver{
  // BluetoothPrint bluetoothPrint = BluetoothPrint.instance;
  String _data = '';
  bool _scanning = false;
  int _currentItem = 0;
  FlutterScanBluetooth _bluetooth = FlutterScanBluetooth();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      bool state = await _bluetooth.onState();
      if(state){
        print('bluetooth turn on !!!!!!');
      }else{
        print('bluetooth turn off !!!!!!');
      }
    }
  }

  @override
  void initState() {
    WidgetsBinding.instance?.addObserver(this);
    super.initState();
    if (_connected) {
      tips = 'Đã kết nối';
    } // Khi vào trang sẽ check xem đã kết nối trước đó hay chưa
    WidgetsBinding.instance?.addPostFrameCallback((_) => initBluetooth());

    // get tín hiệu đầu tiên
    // _getMessage().then((message) {
    //   print('message: $message');
    //   setState(() {
    //     _message = message;
    //   });
    // });

    _bluetooth.devices.listen((device) {
      _data = device.name;
      setState(() {
        if (device.name.endsWith("_noDevice")) {
          print('No Device !!!!!');
        } else {
          if (list.isEmpty) {
            DevicesModel model =
                DevicesModel(device.name, device.address, device.paired);
            list.add(model);
          } else {
            bool check = false;
            for (int i = 0; i < list.length; i++) {
              if (list[i].address.endsWith(device.address)) {
                check = true;
                return;
              }
            }
            if (!check) {
              DevicesModel model =
                  DevicesModel(device.name, device.address, device.paired);
              list.add(model);
            }
          }
        }
      });
      print(_data);
    });
    _bluetooth.checkConnected.listen((event) {
      bool check = event;
      if(check){
        print('Printer connected !!!!!!');
      }
    });

    // _bluetooth.scanStopped.listen((device) {
    //   setState(() {
    //     _scanning = false;
    //     _data += 'scan stopped\n';
    //   });
    // });
  }

  Future<void> initBluetooth() async {
    // bluetoothPrint.startScan(
    //     timeout: const Duration(seconds: 4)); // scan trong 4s, tìm device

    bool isConnected = await _bluetooth.isConnected;
    _bluetooth.state.listen((state) {
      print('cur device status: $state');
      switch (state) {
        case BluetoothCode.CONNECTED:
          setState(() {
            _connected = true;
            print("bluetooth device state: connected");
            tips = 'bluetooth device state: connected';
          });
          break;
        case BluetoothCode.DISCONNECTED:
          setState(() {
            _connected = false;
            print("bluetooth device state: disconnected");
            tips = "bluetooth device state: disconnected";
          });
          break;
        case BluetoothCode.DISCONNECT_REQUESTED:
          setState(() {
            _connected = false;
            print("bluetooth device state: disconnect requested");
            tips = "bluetooth device state: disconnect requested";
          });
          break;
        case BluetoothCode.STATE_TURNING_OFF:
          setState(() {
            _connected = false;
            print("bluetooth device state: bluetooth turning off");
            tips = "bluetooth device state: bluetooth turning off";
          });
          break;
        case BluetoothCode.STATE_OFF:
          setState(() {
            _connected = false;
            print("bluetooth device state: bluetooth off");
            tips = "bluetooth device state: bluetooth off";
          });
          break;
        case BluetoothCode.STATE_ON:
          setState(() {
            _connected = false;
            print("bluetooth device state: bluetooth on");
            tips = "bluetooth device state: bluetooth on";
          });
          break;
        case BluetoothCode.STATE_TURNING_ON:
          setState(() {
            _connected = false;
            print("bluetooth device state: bluetooth turning on");
            tips = "bluetooth device state: bluetooth turning on";
          });
          break;
        case BluetoothCode.ERROR:
          setState(() {
            _connected = false;
            print("bluetooth device state: error");
            tips = "bluetooth device state: error";
          });
          break;
        default:
          print(state);
          break;
      }
    });

    if (!mounted) return; // nếu chưa kết nối thì không làm gì

    if (isConnected) {
      setState(() {
        _connected = true;
      });
    }
    // bluetoothPrint.stopScan();
  }

  List<DevicesModel> list = [];
  bool isCheckState = false;

  void _onConnect(String nameDevice, String addressDevice) async {
    // chỗ này đọc lệnh chắc mọi người cũng hiểu được :v
    _device = BluetoothDevice();
    _device.name = nameDevice;
    _device.address = addressDevice;

    if (_device?.address != null) {
      await _bluetooth.connect(_device);
    } else {
      setState(() {
        tips = 'Vui lòng chọn thiết bị';
      });
      print('please select device');
    }
  }

  void _onConnectIOS(String id) async {
    String index = id;
    bool check = await _bluetooth.connectIOS(index);
    print(check);
    setState(() {
        tips = 'Vui lòng chọn thiết bị';
      });
      print('please select device');
  }

  void _onDisconnect() async {
    // await bluetoothPrint.disconnect();
    setState(() {
      _connected = false;
    });
  }

  void _onBluetooth() async {
    // var value = await EventPrintPos.onBluetooth();
    await _bluetooth.startScan();
  }

  void _offBluetooth() async {
    await _bluetooth.offBluetooth();
    // int value = await _bluetooth.checkBluetooth();
    // print(value);
  }

  bool isChoose = false;
  void onChangeStateBlue(value) async {
    if (value) {
      String scan = await EventPrintPos.onBluetooth();
      if (scan.endsWith("scan")) {
        list = [];
        await _bluetooth.startScan();
        debugPrint("scanning started");
      }
      // print('Fail !!!');
      // bluetoothPrint.startScan(timeout: Duration(seconds: 4));
      setState(() {
        isChoose = value;
      });
      return;
    }
    // list = [];
    await EventPrintPos.offBluetooth();
    setState(() {
      isChoose = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: RefreshIndicator(
        onRefresh: () {},
        child: SizedBox(
          width: double.infinity,
          // Center is a layout widget. It takes a single child and positions it
          // in the middle of the parent.
          child: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 10),
                      child: Text(tips),
                    ),
                  ],
                ),
                const Divider(),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 5, 20, 10),
                  child: Column(
                    children: <Widget>[
                      const SizedBox(width: 10.0),
                      Container(
                        child: Switch(
                          onChanged: onChangeStateBlue,
                          value: isCheckState,
                        ),
                      ),
                      deviceBluetooth(),
                      // Row(
                      //   mainAxisAlignment: MainAxisAlignment.center,
                      //   children: <Widget>[
                      //     // OutlineButton(
                      //     //   child: const Text('Kết nối'),
                      //     //   onPressed: _connected ? null : _onConnect,
                      //     // ),
                      //   //   const SizedBox(width: 10.0),
                      //   //   OutlineButton(
                      //   //     child: const Text('Ngắt kết nối'),
                      //   //   ),
                      //   // ],   onPressed: _connected ? _onDisconnect : null,
                      //
                      // ),

                      // OutlineButton(
                      //   child: Text('In hóa đơn'),
                      //   onPressed: _connected ? _sendData : null,
                      // ),
                      Text(_message),
                      const SizedBox(width: 10.0),
                      OutlineButton(
                        child: const Text("Print QR"),
                        onPressed: _sendMessage,
                      ),
                      OutlineButton(
                        child: const Text("ON Bluetooth"),
                        onPressed: _onBluetooth,
                      ),
                      OutlineButton(
                        child: const Text("Printer"),
                        onPressed: _offBluetooth,
                      ),
                      // OutlineButton(
                      //   child: const Text("Check"),
                      //   onPressed: _scanDevice,
                      // ),
                    ],
                  ),
                ),
                // Transform.rotate(angle: 90 * math.pi / 180, child: ScreenTest())
                ScreenTest()
              ],
            ),
          ),
        ),
      ),
      // floatingActionButton: StreamBuilder<bool>(
      //   stream: bluetoothPrint.isScanning,
      //   initialData: false,
      //   builder: (c, snapshot) {
      //     if (snapshot.data) {
      //       return FloatingActionButton(
      //         child: const Icon(Icons.stop),
      //         onPressed: () => bluetoothPrint.stopScan(),
      //         backgroundColor: Colors.red,
      //       );
      //     } else {
      //       return FloatingActionButton(
      //           child: const Icon(Icons.search),
      //           onPressed: () => bluetoothPrint.startScan(
      //               timeout: const Duration(seconds: 4)));
      //     }
      //   },
      // ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  bool _connected = false;
  BluetoothDevice _device;
  String tips = 'Không có thiết bị được kết nối';

  Map<String, String> arrState = <String, String>{};
  // static const platform = MethodChannel("com.clv.demo/print");
  String _message = "No message yet";

  Future<String> _getMessage() async {
    String value = "";
    try {
      value = await EventPrintPos.getMessage();
      print("NHACVO_DEMO: $value || F.E");
    } catch (e) {
      print(e);
    }
    return value;
  }

  Future<dynamic> _sendMessage() async {
    // kích thước ảnh bitmapInput
    //printerDpi - printerWidthMM -printerNbrCharactersPerLine -widthMax - heightMax
    screenshotController
        .capture(delay: const Duration(milliseconds: 10))
        .then((capturedImage) async {
      final originalImage = img.decodeImage(capturedImage);
      img.Image fixedImage;
      fixedImage = img.copyRotate(originalImage, -90);
      var result =
          await EventPrintPos.sendSignalPrint(capturedImage, 1);
      // var _sendData = <String, dynamic>{
      //   "bitmapInput": result,
      //   "printerDpi": 190, //190
      //   "printerWidthMM": int.parse('80'),
      //   "printerNbrCharactersPerLine": 32,
      //   "widthMax": 580, //580
      //   "heightMax": 400, //400
      // };
      print('TEXT: ' + result["message"]);
      print(result);
    }).catchError((onError) {
      print(onError);
    });
  }

  ScreenshotController screenshotController = ScreenshotController();
  Size screenTestSize = Size.zero;

  Widget ScreenTest() {
    return MeasureSize(
        onChange: (size) {
          screenTestSize = size;
          print("ScreenTest height ${size.height} / width ${size.width}");
        },
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Screenshot(
                controller: screenshotController,
                child: Container(
                    padding: const EdgeInsets.all(10.0),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                    ),
                    child: RenderFormTable()),
              ),
              const SizedBox(
                height: 25,
              ),
            ],
          ),
        ));
  }

  Widget deviceBluetooth() {
    return Row(
      children: <Widget>[
        Expanded(
          child: SizedBox(
            child: list.isEmpty
                ? Center(child: Text("No printer !!!"))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      String id = "${index.toString()}";
                      return Card(
                        child: list[index].state == true
                            ? ListTile(
                                title: Text(
                                    list[index].name == "null"
                                        ? " Unknown"
                                        : " " + list[index].name,
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 13)),
                                leading: Icon(Icons.check_circle),
                                trailing: Icon(Icons.check_circle),
                                onTap: () {
                                  if(Platform.isIOS){
                                    _onConnectIOS(id);
                                  }else if(Platform.isAndroid){
                                    _onConnect(list[index].name, list[index].address);
                                  }
                                },
                              )
                            : ListTile(
                                title: Text(
                                    list[index].name == "null"
                                        ? " Unknown"
                                        : " " + list[index].name,
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 13)),
                                leading: Icon(Icons.print),
                                trailing: Icon(Icons.check_circle),
                                onTap: () {
                                  if(Platform.isIOS){
                                    _onConnectIOS(id);
                                  }else if(Platform.isAndroid){
                                    _onConnect(list[index].name, list[index].address);
                                  }
                                },
                              ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  TableBorder BoderCustom() {
    return TableBorder.all(
      color: Colors.black,
      //style: BorderStyle.solid,
      width: 0.5,
    );
  }

  Future<dynamic> ShowCapturedWidget(
      BuildContext context, Uint8List capturedImage) {
    return showDialog(
      useSafeArea: false,
      context: context,
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: const Text("Captured widget screenshot"),
        ),
        body: Center(
            child: capturedImage != null
                ? Image.memory(capturedImage)
                : Container()),
      ),
    );
  }

  Size heightCol = Size.zero;
  Size heigthItemCd = Size.zero;
  Size heigthPKG = Size.zero;
  Size heigthCQTY = Size.zero;
  Size heigthCNO = Size.zero;
  Size heigthColor = Size.zero;
  Size heigthAOPO = Size.zero;

  Widget RenderFormTable() {
    double width = MediaQuery.of(context).size.width;
    var widthCol = width * 0.75;
    return Column(
      children: [
        Row(
          children: <Widget>[
            MeasureSize(
              onChange: (size) {
                setState(() {
                  heightCol = size;
                });
                // print("heigth : ${size.height}");
                // print("width : ${size.width}");
              },
              child: Column(children: [
                SizedBox(
                  width: widthCol,
                  child: Table(
                    border: BoderCustom(),
                    children: [
                      TableRow(children: [
                        Container(
                            padding: const EdgeInsets.all(10),
                            child: Column(children: const [
                              Text("WH-PKS2 (PKS2-C)",
                                  style: TextStyle(
                                      color: Colors.black87,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold)
                                  //
                                  // Theme.of(context)
                                  //     .textTheme
                                  //     .headline4
                                  //     .copyWith(
                                  //         color: Colors.black87,
                                  //         fontWeight: FontWeight.bold),
                                  ),
                              Text("HoChiMinh,VietNam",
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 12,
                                  )),
                            ])),
                      ]),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Container(
                        width: width - widthCol,
                        alignment: Alignment.topRight,
                        child: Table(
                          border: BoderCustom(),
                          children: [
                            TableRow(children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                child: const Text("DO No.",
                                    style: TextStyle(
                                        color: Colors.black87,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold)

                                    // Theme.of(context)
                                    //     .textTheme
                                    //     .subtitle1
                                    //     .copyWith(
                                    //         color: Colors.black87,
                                    //         fontWeight: FontWeight.bold),
                                    ),
                              ),
                            ]),
                          ],
                        )),
                    Container(
                        width: widthCol - (width - widthCol),
                        alignment: Alignment.topRight,
                        child: Table(
                          border: BoderCustom(),
                          children: [
                            TableRow(children: [
                              Container(
                                  padding: const EdgeInsets.all(10),
                                  child: const Center(
                                    child: Text("DO_20211123_W46_0059",
                                        style: TextStyle(
                                            color: Colors.black87, fontSize: 14)
                                        // Theme.of(context)
                                        //     .textTheme
                                        //     .subtitle1
                                        //     .copyWith(color: Colors.black87)
                                        ),
                                  )),
                            ]),
                          ],
                        )),
                  ],
                ),
                Row(
                  children: [
                    SizedBox(
                        width: width - widthCol,
                        child: Table(
                          border: BoderCustom(),
                          children: [
                            TableRow(children: [
                              Container(
                                height: heigthAOPO.height,
                                padding: const EdgeInsets.all(10),
                                alignment: Alignment.center,
                                child: const Text("AO /PO No.",
                                    style: TextStyle(
                                        color: Colors.black87,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ]),
                          ],
                        )),
                    MeasureSize(
                      onChange: (size) {
                        heigthAOPO = size;
                      },
                      child: Container(
                        width: widthCol - (width - widthCol),
                        // height: heigthAOPO.height,
                        alignment: Alignment.topRight,
                        child: Table(
                          border: BoderCustom(),
                          children: [
                            TableRow(children: [
                              Container(
                                  padding: const EdgeInsets.all(10),
                                  child: const Center(
                                    child:
                                        Text("AD-OSP-0433 / PN-20210708-3194",
                                            style: TextStyle(
                                              color: Colors.black87,
                                              fontSize: 14,
                                            )),
                                  )),
                            ]),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ]),
            ),
            SizedBox(
                height: heightCol.height,
                width: width - widthCol - 20,
                child: Table(
                  border: BoderCustom(),
                  children: [
                    TableRow(children: [
                      Container(
                        child: QrImage(
                          data: "1234567890",
                          version: QrVersions.auto,
                          size: heightCol.height - 40,
                        ),
                        padding: const EdgeInsets.only(
                          top: 40,
                        ),
                      ),
                    ]),
                  ],
                )),
          ],
        ),
        Row(children: <Widget>[
          SizedBox(
            width: width - widthCol,
            child: Table(
              border: BoderCustom(),
              children: [
                TableRow(children: [
                  Container(
                    alignment: Alignment.center,
                    height: heigthItemCd.height,
                    padding: const EdgeInsets.all(10),
                    child: const Text("ITEMCODE",
                        style: TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                  ),
                ]),
              ],
            ),
          ),
          MeasureSize(
            onChange: (size) {
              setState(() {
                heigthItemCd = size;
              });
            },
            child: SizedBox(
              width: widthCol - 20,
              child: Table(
                border: BoderCustom(),
                children: [
                  TableRow(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      child: const Text(
                          "PSTOSP0000132 /ACETAL MALE BUCKLE PLASTIC WOOJIN 3210-20mm PICCO SINGLE SR",
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                          )),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ]),
        Row(children: <Widget>[
          MeasureSize(
              onChange: (size) {
                setState(() {
                  heigthColor = size;
                });
              },
              child: SizedBox(
                width: width - widthCol,
                child: Table(
                  border: BoderCustom(),
                  children: [
                    TableRow(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        child: const Text("COLOR",
                            style: TextStyle(
                                color: Colors.black87,
                                fontSize: 14,
                                fontWeight: FontWeight.bold)),
                      ),
                    ]),
                  ],
                ),
              )),
          SizedBox(
            width: widthCol - 20,
            child: Table(
              border: BoderCustom(),
              children: [
                TableRow(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    height: heigthColor.height,
                    child: const Text("002/425C GREY",
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                        )),
                  ),
                ]),
              ],
            ),
          ),
        ]),
        Row(children: <Widget>[
          MeasureSize(
            onChange: (size) {
              setState(() {
                heigthPKG = size;
              });
            },
            child: SizedBox(
              width: width / 4,
              child: Table(
                border: BoderCustom(),
                children: [
                  TableRow(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      child: const Text("PKG#CARTON QTY",
                          style: TextStyle(
                              color: Colors.black87,
                              fontSize: 14,
                              fontWeight: FontWeight.bold)),
                    ),
                  ]),
                ],
              ),
            ),
          ),
          SizedBox(
            width: width / 4,
            child: Table(
              border: BoderCustom(),
              children: [
                TableRow(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    alignment: Alignment.center,
                    height: heigthPKG.height,
                    child: const Text("15760",
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                        )),
                  ),
                ]),
              ],
            ),
          ),
          SizedBox(
            // height: 64,
            width: width / 4,
            child: Table(
              border: BoderCustom(),
              children: [
                TableRow(children: [
                  Container(
                    height: heigthPKG.height,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(10),
                    child: const Text("CARGO CLS DATE",
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                        )),
                  ),
                ]),
              ],
            ),
          ),
          SizedBox(
            // height: 64,
            width: width / 4 - 20,
            child: Table(
              border: BoderCustom(),
              children: [
                TableRow(children: [
                  Container(
                    height: heigthPKG.height,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(10),
                    child: const Text("2021-12-01",
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                        )),
                  ),
                ]),
              ],
            ),
          ),
        ]),
        Row(children: <Widget>[
          MeasureSize(
            onChange: (size) {
              setState(() {
                heigthCQTY = size;
              });
            },
            child: SizedBox(
              width: width / 4,
              child: Table(
                border: BoderCustom(),
                children: [
                  TableRow(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      child: const Text("CARTON QTY",
                          style: TextStyle(
                              color: Colors.black87,
                              fontSize: 14,
                              fontWeight: FontWeight.bold)),
                    ),
                  ]),
                ],
              ),
            ),
          ),
          SizedBox(
            // height: 64,
            width: width / 4,
            child: Table(
              border: BoderCustom(),
              children: [
                TableRow(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    alignment: Alignment.center,
                    height: heigthCQTY.height,
                    child: const Text("2700",
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                        )),
                  ),
                ]),
              ],
            ),
          ),
          SizedBox(
            width: width / 4,
            child: Table(
              border: BoderCustom(),
              children: [
                TableRow(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    alignment: Alignment.center,
                    height: heigthCQTY.height,
                    child: const Text("LOT NO.",
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                        )),
                  ),
                ]),
              ],
            ),
          ),
          SizedBox(
            // height: 64,
            width: width / 4 - 20,
            child: Table(
              border: BoderCustom(),
              children: [
                TableRow(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    alignment: Alignment.center,
                    height: heigthCQTY.height,
                    child: const Text("",
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                        )),
                  )
                ]),
              ],
            ),
          ),
        ]),
        Row(children: <Widget>[
          SizedBox(
            // height: 64,
            width: width / 4,
            child: Table(
              border: BoderCustom(),
              children: [
                TableRow(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    child: const Text("CARTON NO.",
                        style: TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                  )
                ]),
              ],
            ),
          ),
          SizedBox(
            // height: 64,
            width: width / 4,
            child: Table(
              border: BoderCustom(),
              children: [
                TableRow(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    alignment: Alignment.center,
                    height: heigthCQTY.height,
                    child: const Text("11360353",
                        style: TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                  )
                ]),
              ],
            ),
          ),
          SizedBox(
            // height: 64,
            width: width / 4 * 2 - 20,
            child: Table(
              border: BoderCustom(),
              children: [
                TableRow(children: [
                  Container(
                      padding: const EdgeInsets.all(10),
                      alignment: Alignment.center,
                      height: heigthCQTY.height,
                      child: Column(
                        children: const [
                          Text("Made In VietNam",
                              style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                          Text("Woo JIN PLASTIC CO.",
                              style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ],
                      )),
                ]),
              ],
            ),
          ),
        ])
      ],
    );
  }
}
