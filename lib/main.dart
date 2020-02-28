import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:audioplayers/audio_cache.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:esense_flutter/esense.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';


///
/// Entry Point of the Program
///
void main() => runApp(MainApp());

///
/// Parent Widget to the entire App
///
class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

///
/// State of the Parent Widget
///
class _MyAppState extends State<MyApp> {
  String _deviceName = 'Unknown';
  double _voltage = -1;
  String _deviceStatus = '';
  bool sampling = false;
  String _event = '';
  DateTime lastImageUpdate = new DateTime(2000);
  int changedPicture = 0;
  // the name of the eSense device to connect to -- change this to your own device.
  String eSenseName = 'eSense-0058';
  String _button = '';
  bool deviceConnected = false;
  bool playing = false;
  Image img;
  bool charDecided = false;

  static AudioCache cache = AudioCache();
  AudioPlayer player = new AudioPlayer();

  bool up = false;
  int counter = 0;

  void _playFile() async {
    this.player =
    await cache.loop('Drum-roll-sound-effect.mp3'); // assign player here
  }


  ///
  // / Initializes the State of the app at the start
  ///
  @override
  void initState() {
    super.initState();
    _connectToESense();
    this.img = Image.asset('assets/main-page.jpg');
  }

  ///
  /// Method which connects to the ESense Device and
  /// starts the process of listening to Events coming from the device
  Future<void> _connectToESense() async {
    bool con = false;

    // if you want to get the connection events when connecting, set up the listener BEFORE connecting...
    ESenseManager.connectionEvents.listen((event) {
      print('CONNECTION event: $event');

      // when we're connected to the eSense device, we can start listening to events from it
      if (event.type == ConnectionType.connected) {
        _listenToESenseEvents();
        deviceConnected = true;
      }

      setState(() {
        switch (event.type) {
          case ConnectionType.connected:
            _deviceStatus = 'connected';
            deviceConnected = true;
            break;
          case ConnectionType.unknown:
            _deviceStatus = 'unknown';
            deviceConnected = false;
            break;
          case ConnectionType.disconnected:
            _deviceStatus = 'disconnected';
            deviceConnected = false;

            break;
          case ConnectionType.device_found:
            _deviceStatus = 'device_found';

            break;
          case ConnectionType.device_not_found:
            _deviceStatus = 'device_not_found';
            deviceConnected = false;

            break;
        }
      });
    });

    con = await ESenseManager.connect(eSenseName);

    setState(() {
      print(con);
      _deviceStatus = con ? 'connecting' : 'connection failed';

      print(con);
    });
  }

  ///
  /// This method reads out all events from the connected ESense device
  ///
  void _listenToESenseEvents() async {
    ESenseManager.eSenseEvents.listen((event) {
      print('ESENSE event: $event');

      setState(() {
        switch (event.runtimeType) {
          case DeviceNameRead:
            _deviceName = (event as DeviceNameRead).deviceName;
            break;
          case BatteryRead:
            _voltage = (event as BatteryRead).voltage;
            break;
          case ButtonEventChanged:
            _button = (event as ButtonEventChanged).pressed
                ? 'pressed'
                : 'not pressed';
            break;
          case AccelerometerOffsetRead:
          // TODO

            break;
          case AdvertisementAndConnectionIntervalRead:
          // TODO
            break;
          case SensorConfigRead:
          // TODO

            break;
        }
      });
    });

    _getESenseProperties();
  }

  ///
  /// method reads out all the Properties from the Esense device
  ///
  void _getESenseProperties() async {
    // get the battery level every 10 secs
    Timer.periodic(Duration(seconds: 10),
            (timer) async => await ESenseManager.getBatteryVoltage());

    // wait 2, 3, 4, 5, ... secs before getting the name, offset, etc.
    // it seems like the eSense BTLE interface does NOT like to get called
    // several times in a row -- hence, delays are added in the following calls
    Timer(
        Duration(seconds: 2), () async => await ESenseManager.getDeviceName());
    Timer(Duration(seconds: 3),
            () async => await ESenseManager.getAccelerometerOffset());
    Timer(
        Duration(seconds: 4),
            () async =>
        await ESenseManager.getAdvertisementAndConnectionInterval());
    Timer(Duration(seconds: 5),
            () async => await ESenseManager.getSensorConfig());
  }


  StreamSubscription subscription;

  ///
  /// Method to continuously read the data from the ESense device
  /// Interprets the gyro data to find out in which direction the head was moving
  ///
  void _startListenToSensorEvents() {
    setState(() {
      sampling = true;
    });
    // subscribe to sensor event from the eSense device
    subscription = ESenseManager.sensorEvents.listen((event) {
      //print('SENSOR event: $event');
      setState(() {
        _event = event.toString();

        var accX = event.accel[0] / 2048.0;
        var accY = event.accel[1] / 2048.0;
        var accZ = event.accel[2] / 2048.0;

        var accAngleX = (atan(accY / sqrt(pow(accX, 2) + pow(accZ, 2))) * 180 /
            pi) - 0.58; // accError;
        var accAngleY = (atan(-1 * accX / sqrt(pow(accY, 2) + pow(accZ, 2))) *
            180 * pi) + 1.58;

        var gyroX = event.gyro[0] / 131.0;
        var gyroY = event.gyro[1] / 131.0;
        var gyroZ = event.gyro[2] / 131.0;

        gyroX = gyroX + 0.56; // gyroErrorX ~ 0.56
        gyroY = gyroY - 2; // gyroErrorY ~ 2
        gyroZ = gyroZ + 0.79; // gyroErrorZ ~ 0.79

        var previousTime = new DateTime.now().millisecondsSinceEpoch;
        var currentTime = new DateTime.now().millisecondsSinceEpoch;
        var eplasedTime = (currentTime - previousTime) / 1000;

        var gyroAngleX = gyroX * eplasedTime;
        var gyroAngleY = gyroY * eplasedTime;

        var yaw = gyroZ * eplasedTime;

        var roll = 0.96 * gyroAngleX + 0.04 * accAngleX;
        var pitch = 0.96 * gyroAngleY + 0.04 * accAngleY;

        print('roll: ' + roll.toString() + '  pitch: ' + pitch.toString());


        if (pitch >= 25) {
          print(counter);
          this.counter++;
          if (!this.up && this.sampling) {
            print('UP DETECTED');
            this.up = true;
            if (this.sampling) {
              this._playFile();
            }
            this.img = Image.asset('assets/drum_roll.gif');
          }
        }
        else if (counter >= 5 && pitch <= 20) {
          this.counter = 0;
          if (this.up && this.sampling) {
            print('DOWN DETECTED');
            this.player?.stop();
            var rng = new Random().nextInt(15);
            this.img = Image.asset('assets/characters/$rng.jpg');
            this.sampling = false;
            this.up = false;
            this.charDecided = true;
          }
        }

      });
    });

  }


  ///
  /// pauses the continuously data reading
  ///
  void _pauseListenToSensorEvents() async {
    this.player?.stop();
    subscription.cancel();
    setState(() {
      sampling = false;
    });
  }

  ///
  /// disconnects the device
  ///
  void dispose() {
    _pauseListenToSensorEvents();
    ESenseManager.disconnect();
    super.dispose();
  }

  ///
  /// Creates the bluetooth icon with
  /// the bluetooth settings
  ///
  Widget bluetoothStatus() {
    return IconButton(
      icon: deviceConnected
          ? Icon(
        Icons.bluetooth_connected,
        color: Colors.white,
      )
          : Icon(
        Icons.bluetooth,
        color: Colors.white,
      ),
      onPressed: () {
        showBluetoothConnection();
      },
    );
  }

  ///
  /// Builds the AppBar of the app
  Widget ownAppBar() {
    return AppBar(
      title: const Text('Your Office Character'),
      centerTitle: true,
      backgroundColor: Colors.blueGrey[900],
      actions: <Widget>[bluetoothStatus()],
    );
  }

  ///
  /// Builds the body of the app,
  /// the body contains all the actual content of the app
  ///
  Widget ownColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.all(16.0),
          child: Container(
              height: 80,
              child: Text(
                sampling
                    ? 'Move your head up to initiate the drum roll and down for the result!'
                    : 'Press the play button to find out your Office character!',
                style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
              )),
        ),
        GestureDetector(
            onPanUpdate: (details) {
              if (details.delta.dy < -20) {
                setState(() {
                  print('naber abi');
                });
              } else if (details.delta.dy > 20) {
                setState(() {
                  print('NABER ABI');
                });
              }
            },
            child: Container(
              height: 300,
              child: Center(
                child: ClipRRect(
                    borderRadius: new BorderRadius.circular(8.0),
                    child: img
                ),
              ),
            )),
        IconButton(
          onPressed: (!ESenseManager.connected)
              ? null
              : (!sampling)
              ? _startListenToSensorEvents
              : _pauseListenToSensorEvents,
          icon: (!sampling) ? Icon(Icons.play_arrow) : Icon(Icons.pause),
          iconSize: 80,
          color: Colors.blueGrey[900],
        ),
      ],
    );
  }

  String getFootText() {
    if (sampling && up) {
      return "Wait for the drum roll ...";
    } else if (charDecided) {
      return "Your character has been decided!";
    }
    else
      return "";
  }

  ///
  /// Build the BottomBar of the app
  ///
  Widget ownBottomBar() {
    return BottomAppBar(
        color: Colors.blueGrey[900],
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 25, vertical: 10),
          child: Text(this.getFootText(),
            style: TextStyle(fontSize: 18, color: Colors.white),
          ),
        ));
  }

  ///
  /// creates the alerts that displays
  /// the bluetooth connection details
  ///
  void showBluetoothConnection() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: new Text('Connection status'),
          content: new Container(
            height: 400,
            child: new Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                new Container(
                  height: 150,
                  width: 300,
                  child: new ListView(
                    children: <Widget>[
                      new ListTile(
                        leading: new Text(
                            deviceConnected ? 'connected' : 'No connection'),
                      ),
                      new ListTile(
                        leading: Text(deviceConnected
                            ? _deviceName
                            : 'No device connected'),
                      ),
                    ],
                  ),
                ),
                new Text(
                  'Help',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                new Text(
                  'Check if bluetooth is turned on.',
                  textAlign: TextAlign.left,
                  style: TextStyle(color: Colors.blueGrey),
                ),
                new Text(
                  'Hold down the Button on both devices until they blink blue and red and connect your device.',
                  textAlign: TextAlign.left,
                  style: TextStyle(color: Colors.blueGrey),
                ),
                new Text(
                  '\nPress Connect.',
                  textAlign: TextAlign.left,
                  style: TextStyle(color: Colors.blueGrey),
                ),
              ],
            ),
          ),
          elevation: 24.0,
          actions: <Widget>[
            new FlatButton(
                onPressed: () {
                  if (deviceConnected) {
                    Navigator.of(context).pop();
                  } else {
                    _connectToESense();
                    Navigator.of(context).pop();
                  }
                },
                child: Text(deviceConnected ? 'Close' : 'Connect'))
          ],
        );
      },
    );
  }

  ///
  /// Builds the app layout
  ///
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ownAppBar(),
      body: ownColumn(),
      bottomNavigationBar: ownBottomBar(),
    );
  }
}

///
/// Parent Widget to app
///
class MainApp extends StatelessWidget {
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    return MaterialApp(
      title: 'Your Office Character',
      home: MyApp(),
    );
  }
}