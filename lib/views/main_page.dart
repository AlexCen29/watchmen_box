import 'dart:convert';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:animate_do/animate_do.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final _bluetooth = FlutterBluetoothSerial.instance;
  bool _bluetoothState = false;
  bool _isConnecting = false;
  BluetoothConnection? _connection;
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _deviceConnected;

  String temperatureValue = "--";
  String humidityValue = "--";
  String gasValue = "--";
  bool alertaGas = false;

  // Configuración de rangos
  double tempMin = 15.0;
  double tempMax = 30.0;
  double humMin = 30.0;
  double humMax = 70.0;

  // Estados de alerta
  bool tempAlert = false;
  bool humAlert = false;
  String tempAlertType = ""; // "low" o "high"
  String humAlertType = ""; // "low" o "high"

  void _getDevices() async {
    var res = await _bluetooth.getBondedDevices();
    setState(() => _devices = res);
  }

void _receiveData() {
  String buffer = "";

  _connection?.input?.listen((event) {
    buffer += String.fromCharCodes(event);

    // dividir en líneas si hay uno o más saltos de línea
    while (buffer.contains('\n')) {
      int index = buffer.indexOf('\n');
      String line = buffer.substring(0, index).trim();
      buffer = buffer.substring(index + 1);

      print("Received line: $line");

      if (line.contains(":")) {
        final parts = line.split(":");
        if (parts.length == 2) {
          final key = parts[0];
          final value = parts[1];

          setState(() {
            switch (key) {
              case "TEMP":
                temperatureValue = value;
                _checkTemperatureRange(value);
                break;
              case "HUM":
                humidityValue = value;
                _checkHumidityRange(value);
                break;
              case "GAS":
                gasValue = value;
                break;
              case "ALERTA":
                if (value == "GAS") {
                  alertaGas = true;
                } else if (value == "APAGAR_ALARMA") {
                  alertaGas = false; 
                }
                break;
            }
          });
        }
      }
    }
  });
}

  void _sendData(String data) {
    if (_connection?.isConnected ?? false) {
      _connection?.output.add(ascii.encode(data));
    }
  }

  void _checkTemperatureRange(String value) {
    if (value == "--") return;
    
    double? temp = double.tryParse(value);
    if (temp != null) {
      if (temp < tempMin) {
        tempAlert = true;
        tempAlertType = "low";
      } else if (temp > tempMax) {
        tempAlert = true;
        tempAlertType = "high";
      } else {
        tempAlert = false;
        tempAlertType = "";
      }
    }
  }

  void _checkHumidityRange(String value) {
    if (value == "--") return;
    
    double? hum = double.tryParse(value);
    if (hum != null) {
      if (hum < humMin) {
        humAlert = true;
        humAlertType = "low";
      } else if (hum > humMax) {
        humAlert = true;
        humAlertType = "high";
      } else {
        humAlert = false;
        humAlertType = "";
      }
    }
  }

  void _showConfigDialog(String type) {
    String title = type == "temp" ? "Configurar Temperatura" : "Configurar Humedad";
    String unit = type == "temp" ? "°C" : "%";
    double currentMin = type == "temp" ? tempMin : humMin;
    double currentMax = type == "temp" ? tempMax : humMax;
    
    TextEditingController minController = TextEditingController(text: currentMin.toString());
    TextEditingController maxController = TextEditingController(text: currentMax.toString());

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: minController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Valor Mínimo ($unit)",
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: maxController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Valor Máximo ($unit)",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () {
                double? min = double.tryParse(minController.text);
                double? max = double.tryParse(maxController.text);
                
                if (min != null && max != null && min < max) {
                  setState(() {
                    if (type == "temp") {
                      tempMin = min;
                      tempMax = max;
                      _checkTemperatureRange(temperatureValue);
                    } else {
                      humMin = min;
                      humMax = max;
                      _checkHumidityRange(humidityValue);
                    }
                  });
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Por favor ingresa valores válidos (mínimo < máximo)")),
                  );
                }
              },
              child: Text("Guardar"),
            ),
          ],
        );
      },
    );
  }

  void _requestPermission() async {
    await Permission.location.request();
    await Permission.bluetooth.request();
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
  }

  @override
  void initState() {
    super.initState();

    _requestPermission();

    _bluetooth.state.then((state) {
      setState(() => _bluetoothState = state.isEnabled);
    });

    _bluetooth.onStateChanged().listen((state) {
      switch (state) {
        case BluetoothState.STATE_OFF:
          setState(() => _bluetoothState = false);
          break;
        case BluetoothState.STATE_ON:
          setState(() => _bluetoothState = true);
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Watchmen Box'),
      ),
      body: Column(
        children: [
          _controlBT(),
          _infoDevice(),
          Expanded(child: _listDevices()),
          _buttons(),
        ],
      ),
    );
  }

  Widget _controlBT() {
    return SwitchListTile(
      value: _bluetoothState,
      onChanged: (bool value) async {
        if (value) {
          await _bluetooth.requestEnable();
        } else {
          await _bluetooth.requestDisable();
        }
      },
      tileColor: Colors.black26,
      title: Text(
        _bluetoothState ? "Bluetooth encendido" : "Bluetooth apagado",
      ),
    );
  }

  Widget _infoDevice() {
    return ListTile(
      tileColor: Colors.black12,
      title: Text("Conectado a: ${_deviceConnected?.name ?? "ninguno"}"),
      trailing: _connection?.isConnected ?? false
          ? TextButton(
              onPressed: () async {
                await _connection?.finish();
                setState(() => _deviceConnected = null);
              },
              child: const Text("Desconectar"),
            )
          : TextButton(
              onPressed: _getDevices,
              child: const Text("Ver dispositivos"),
            ),
    );
  }

  Widget _listDevices() {
    return _isConnecting
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            child: Container(
              color: Colors.grey.shade100,
              child: Column(
                children: [
                  ...[
                    for (final device in _devices)
                      ListTile(
                        title: Text(device.name ?? device.address),
                        trailing: TextButton(
                          child: const Text('conectar'),
                          onPressed: () async {
                            setState(() => _isConnecting = true);
                            _connection = await BluetoothConnection.toAddress(
                                device.address);
                            _deviceConnected = device;
                            _devices = [];
                            _isConnecting = false;
                            _receiveData();
                            setState(() {});
                          },
                        ),
                      )
                  ]
                ],
              ),
            ),
          );
  }
  Widget _buttons() {
  return FadeInUp(
    animate: _connection?.isConnected ?? false,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 8.0),
      color: Colors.black12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text('Monitoreo en tiempo real',
              style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold)),

          const SizedBox(height: 16),

          _buildDataCard("Temperatura", "°C", temperatureValue, tempAlert, tempAlertType, () => _showConfigDialog("temp")),
          const SizedBox(height: 12),
          _buildDataCard("Humedad", "%", humidityValue, humAlert, humAlertType, () => _showConfigDialog("hum")),
          const SizedBox(height: 12),
          _buildDataCard("Gas Detectado", "", gasValue, false, "", null),

          const SizedBox(height: 24),

          // Alerta de gas
          if (alertaGas)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade700,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    "🚨 GAS/HUMO DETECTADO",
                    style: TextStyle(
                      color: Colors.white, 
                      fontSize: 18, 
                      fontWeight: FontWeight.bold
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        _sendData("APAGAR_ALARMA");
                        setState(() {
                          alertaGas = false;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.red.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        "Apagar Alarma",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),

        ],
      ),
    ),
  );
}

}

class MyButtonLed extends StatefulWidget {
  const MyButtonLed(
      {super.key,
      required this.titulo,
      required this.data,
      required this.data2,
      required this.color,
      required this.connection});
  final String titulo;
  final String data;
  final String data2;
  final Color color;
  final BluetoothConnection? connection;

  @override
  State<MyButtonLed> createState() => _MyButtonLedState();
}

class _MyButtonLedState extends State<MyButtonLed> {
  double opacity = 0.5;
  bool onOff = false;

  void _sendData(String data) {
    if (widget.connection?.isConnected ?? false) {
      widget.connection?.output.add(ascii.encode(data));
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    return GestureDetector(
      onTap: () {
        setState(() {
          if (onOff) {
            _sendData(widget.data2);
            opacity = 0.5;
            onOff = false;
          } else {
            _sendData(widget.data);
            opacity = 1.0;
            onOff = true;
          }
        });
      },
      child: Opacity(
        opacity: opacity,
        child: Container(
          decoration: BoxDecoration(
              color: widget.color, borderRadius: BorderRadius.circular(8.0)),
          width: screenSize.width * 0.3,
          height: screenSize.height * 0.08,
          child: Center(
            child: Text(widget.titulo,style: const TextStyle(color: Colors.white),),
          ),
        ),
      ),
    );
  }
}

Widget _buildDataCard(String label, String unidad, String value, bool hasAlert, String alertType, VoidCallback? onConfigTap) {
  // Determinar el color del contenedor según la alerta
  Color borderColor = Colors.blueAccent;
  Color backgroundColor = Colors.white;
  
  if (hasAlert) {
    if (alertType == "low") {
      borderColor = Colors.blue.shade700;
      backgroundColor = Colors.blue.shade50;
    } else if (alertType == "high") {
      borderColor = Colors.red.shade700;
      backgroundColor = Colors.red.shade50;
    }
  }

  return Container(
    padding: const EdgeInsets.all(12),
    margin: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: backgroundColor,
      border: Border.all(color: borderColor, width: 2),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              if (hasAlert) ...[
                const SizedBox(width: 8),
                Icon(
                  alertType == "low" ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                  color: alertType == "low" ? Colors.blue.shade700 : Colors.red.shade700,
                  size: 20,
                ),
              ],
            ],
          ),
        ),
        Row(
          children: [
            Text(
              "$value $unidad",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (onConfigTap != null) ...[
              const SizedBox(width: 8),
              IconButton(
                onPressed: onConfigTap,
                icon: const Icon(Icons.edit, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
            ],
          ],
        ),
      ],
    ),
  );
}

