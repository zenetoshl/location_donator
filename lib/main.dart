import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:flutter_blue/flutter_blue.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Location Donator',
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
        primarySwatch: Colors.indigo,
      ),
      home: MyHomePage(title: 'Dogled GPS'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  FlutterBlue flutterBlue = FlutterBlue.instance;
  BluetoothDevice device;
  BluetoothCharacteristic writeLatChar;
  Latin1Codec latin = new Latin1Codec();
  Location locationService = new Location();
  String lat = '', lng = '';
  bool loading = false;
  bool scanning = false;
  String id = '';
  final String writeLatCharId = 'e012c323-3e07-4a41-acdd-2bd9cc2c4ffa';
  final String serviceId = '37f64eb3-c25f-449b-ba34-a5f5387fdb6d';

  void initScan() async {
    if (scanning) return;
    setState(() {
      scanning = true;
    });
    FlutterBlue.instance
        .startScan(scanMode: ScanMode.balanced, timeout: Duration(seconds: 20));
    Timer(Duration(seconds: 20), () {
      setState(() {
        scanning = false;
      });
    });
  }

  void sendLocation() async {
    locationService.onLocationChanged().listen((LocationData result) {
      lng = result.longitude.toString();
      lat = result.latitude.toString();
      writeLatChar.write(latin.encode('0$lat'), withoutResponse: true);
      Timer(Duration(milliseconds: 300), () {
        writeLatChar.write(latin.encode('1$lng'), withoutResponse: true);
      });

      print('$lat , $lng');
    });
  }

  @override
  void initState() {
    super.initState();
    initScan();
  }

  Future<void> findChars() async {
    if (loading) return;
    setState(() {
      loading = true;
    });

    List<BluetoothService> services = await device.discoverServices();
    services.forEach((s) async {
      s.characteristics.forEach((c) async {
        String uid = c.uuid.toString();
        print(uid);
        if (uid == writeLatCharId) {
          setState(() {
            writeLatChar = c;
          });
        }
        if (writeLatChar != null) {
          setState(() {
            loading = false;
          });
        }
      });
    });
  }

  void findAndSend() async {
    await findChars();
    sendLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            StreamBuilder<List<ScanResult>>(
              stream: flutterBlue.scanResults,
              initialData: [],
              builder: (c, snapshot) => Column(
                children: snapshot.data.map((r) {
                  return ListTile(
                    title: Text(
                      r.device.name,
                      style: TextStyle(
                        color: (id == r.device.id.toString())
                            ? Colors.green
                            : Colors.grey,
                      ),
                    ),
                    subtitle: Text(r.device.id.toString()),
                    onTap: () async {
                      device = r.device;
                      try {
                        await device.connect();
                      } catch (e) {
                        print("ja conectado");
                      }
                      setState(() {
                        id = r.device.id.toString();
                      });
                      findAndSend();
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
