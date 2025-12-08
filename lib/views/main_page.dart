import 'dart:convert';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:watchmen_box/entities/iot_data.dart';
import 'package:watchmen_box/entities/gas_alarm_data.dart';
import 'package:watchmen_box/services/iot_data_service.dart';
import 'package:watchmen_box/services/gas_alarm_service.dart';
import 'package:watchmen_box/providers/auth_bloc/auth_bloc.dart';
import 'package:watchmen_box/views/wifi_config_page.dart';

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

  // Servicios para IoT
  late IoTDataService _iotDataService;
  late GasAlarmService _gasAlarmService;
  List<IoTData> _pendingIoTData = [];
  List<GasAlarmData> _pendingGasAlarmData = [];
  bool _isSyncing = false;

  // Variables para mostrar progreso
  int _totalToSync = 0;
  int _currentSyncing = 0;
  int _successfulUploads = 0;
  String _currentSyncStatus = "";

  void _getDevices() async {
    var res = await _bluetooth.getBondedDevices();
    setState(() => _devices = res);
  }

  void _receiveData() {
    String buffer = "";

    _connection?.input?.listen(
      (event) {
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
                    _saveIoTDataTemporarily();
                    break;
                  case "HUM":
                    humidityValue = value;
                    _checkHumidityRange(value);
                    _saveIoTDataTemporarily();
                    break;
                  case "GAS":
                    gasValue = value;
                    break;
                  case "ALERTA":
                    if (value == "GAS") {
                      if (!alertaGas) {
                        // Solo si la alarma no estaba activa
                        alertaGas = true;
                        _saveGasAlarmData(true); // Guardar activación de alarma
                      }
                    } else if (value == "APAGAR_ALARMA") {
                      // Apagar alarma cuando se presiona el botón en el Arduino
                      alertaGas = false;
                    }
                    break;
                }
              });
            }
          }
        }
      },
      onDone: () {
        // Conexión terminada - limpiar estado
        print("🔴 Conexión Bluetooth perdida");
        setState(() {
          _deviceConnected = null;
          _connection = null;
          temperatureValue = "--";
          humidityValue = "--";
          gasValue = "--";
          alertaGas = false;
          tempAlert = false;
          humAlert = false;
        });
        
        // Mostrar notificación al usuario
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.bluetooth_disabled, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Conexión Bluetooth perdida'),
                ],
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      },
      onError: (error) {
        // Error en la conexión - limpiar estado
        print("❌ Error en conexión Bluetooth: $error");
        setState(() {
          _deviceConnected = null;
          _connection = null;
          temperatureValue = "--";
          humidityValue = "--";
          gasValue = "--";
          alertaGas = false;
          tempAlert = false;
          humAlert = false;
        });
        
        // Mostrar notificación al usuario
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Error en conexión: ${error.toString()}')),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      },
    );
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
    String title =
        type == "temp" ? "Configurar Temperatura" : "Configurar Humedad";
    String unit = type == "temp" ? "°C" : "%";
    double currentMin = type == "temp" ? tempMin : humMin;
    double currentMax = type == "temp" ? tempMax : humMax;

    TextEditingController minController = TextEditingController(
      text: currentMin.toString(),
    );
    TextEditingController maxController = TextEditingController(
      text: currentMax.toString(),
    );

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
                    SnackBar(
                      content: Text(
                        "Por favor ingresa valores válidos (mínimo < máximo)",
                      ),
                    ),
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

  void _saveIoTDataTemporarily() {
    // Solo guardar si tenemos valores válidos de temperatura y humedad y no estamos sincronizando
    if (temperatureValue != "--" && humidityValue != "--" && !_isSyncing) {
      final temp = double.tryParse(temperatureValue);
      final hum = double.tryParse(humidityValue);

      if (temp != null && hum != null) {
        // Verificar si ya tenemos un dato muy reciente (últimos 10 segundos) para evitar duplicados
        final now = DateTime.now();
        final hasRecentData = _pendingIoTData.any(
          (data) =>
              now.difference(data.timestamp).inSeconds < 10 &&
              (data.temperature - temp).abs() < 0.1 &&
              (data.humidity - hum).abs() < 0.1,
        );

        if (!hasRecentData) {
          final iotData = IoTData(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            timestamp: now,
            temperature: temp,
            humidity: hum,
          );

          setState(() {
            _pendingIoTData.add(iotData);
            // Limitar a los últimos 999 registros para no saturar la memoria
            if (_pendingIoTData.length > 999) {
              _pendingIoTData.removeAt(0);
            }
          });

          // _savePendingDataToStorage();
        }
      }
    }
  }

  void _saveGasAlarmData(bool isAlarmActive) {
    // Solo guardar si tenemos un valor de gas válido y no estamos sincronizando
    if (gasValue != "--" && !_isSyncing) {
      final gasLevel = double.tryParse(gasValue);

      if (gasLevel != null) {
        final gasAlarmData = GasAlarmData(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          timestamp: DateTime.now(),
          gasLevel: gasLevel,
          isAlarmActive: isAlarmActive,
        );

        setState(() {
          _pendingGasAlarmData.add(gasAlarmData);
          // Limitar a los últimos 50 registros de alarma para no saturar la memoria
          if (_pendingGasAlarmData.length > 50) {
            _pendingGasAlarmData.removeAt(0);
          }
        });

        print(
          'Guardada alarma de gas: ${isAlarmActive ? "ACTIVADA" : "DESACTIVADA"} - Nivel: $gasLevel',
        );
      }
    }
  }

  // Future<void> _savePendingDataToStorage() async {
  //   try {
  //     final jsonList = _pendingIoTData.map((data) => data.toJson()).toList();
  //     await _storageService.setKeyValue('pendingIoTData', jsonEncode(jsonList));
  //   } catch (e) {
  //     print('Error al guardar datos pendientes: $e');
  //   }
  // }

  // Future<void> _loadPendingDataFromStorage() async {
  //   try {
  //     final jsonString = await _storageService.getValue<String>('pendingIoTData');
  //     if (jsonString != null) {
  //       final List<dynamic> jsonList = jsonDecode(jsonString);
  //       setState(() {
  //         _pendingIoTData = jsonList.map((json) => IoTData.fromJson(json)).toList();
  //       });
  //     }
  //   } catch (e) {
  //     print('Error al cargar datos pendientes: $e');
  //   }
  // }

  void _showSyncDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Cambio: siempre false para evitar que se cierre accidentalmente
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return WillPopScope(
              onWillPop: () async {
                // Evitar que se cierre el diálogo mientras se sincroniza
                return !_isSyncing;
              },
              child: AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Row(
                  children: [
                    Icon(Icons.cloud_sync, color: Colors.blue.shade600, size: 28),
                    const SizedBox(width: 12),
                    const Text(
                      'Sincronizar Datos',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_isSyncing) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.data_usage,
                                  color: Colors.blue.shade600,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Datos pendientes:',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.blue.shade200,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.thermostat,
                                          color: Colors.blue.shade600,
                                          size: 20,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${_pendingIoTData.length}',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                        Text(
                                          'Temp/Hum',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.orange.shade200,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.warning,
                                          color: Colors.orange.shade600,
                                          size: 20,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${_pendingGasAlarmData.length}',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange.shade700,
                                          ),
                                        ),
                                        Text(
                                          'Alarmas',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        '¿Qué tipo de datos deseas sincronizar?',
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ] else ...[
                      _buildSyncProgressWidget(),
                    ],
                  ],
                ),
                actions:
                    _isSyncing
                        ? []
                        : [
                          ElevatedButton.icon(
                                onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.cancel),
                            label: const Text('Cancelar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed:
                                _pendingIoTData.isEmpty
                                    ? null
                                    : () {
                                      setDialogState(() {});
                                      _syncIoTDataWithProgress(setDialogState);
                                    },
                            icon: const Icon(Icons.thermostat),
                            label: const Text('Temperatura/Humedad'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed:
                                _pendingGasAlarmData.isEmpty
                                    ? null
                                    : () {
                                      setDialogState(() {});
                                      _syncGasAlarmDataWithProgress(
                                        setDialogState,
                                      );
                                    },
                            icon: const Icon(Icons.warning),
                            label: const Text('Alarmas'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSyncProgressWidget() {
    double progress = _totalToSync > 0 ? _currentSyncing / _totalToSync : 0.0;

    return Column(
      children: [
        // Header con icono animado
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              'Sincronizando...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Barra de progreso principal
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progreso:',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '$_currentSyncing / $_totalToSync',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                minHeight: 8,
              ),
              const SizedBox(height: 12),

              // Status actual
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.upload, size: 16, color: Colors.blue.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _currentSyncStatus.isEmpty
                            ? 'Preparando sincronización...'
                            : _currentSyncStatus,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Estadísticas
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green.shade600,
                      size: 20,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_successfulUploads',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                    Text(
                      'Exitosos',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.pending,
                      color: Colors.orange.shade600,
                      size: 20,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_totalToSync - _currentSyncing}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
                      ),
                    ),
                    Text(
                      'Pendientes',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _syncGasAlarmDataWithProgress(StateSetter setDialogState) async {
    if (_isSyncing || _pendingGasAlarmData.isEmpty) return;

    setState(() {
      _isSyncing = true;
    });

    setDialogState(() {
      _totalToSync =
          _pendingGasAlarmData.where((data) => !data.isSynced).length;
      _currentSyncing = 0;
      _successfulUploads = 0;
      _currentSyncStatus = "Preparando sincronización de alarmas...";
    });

    try {
      final List<GasAlarmData> dataToSync = List.from(
        _pendingGasAlarmData.where((data) => !data.isSynced),
      );
      final List<String> successfullyUploadedIds = [];

      for (int i = 0; i < dataToSync.length; i++) {
        final data = dataToSync[i];

        setDialogState(() {
          _currentSyncing = i + 1;
          _currentSyncStatus =
              "Subiendo alarma ${i + 1}/${dataToSync.length} (${data.alarmStatus} - ${data.displayDateTime})";
        });

        // Pequeña pausa para mostrar el progreso
        await Future.delayed(const Duration(milliseconds: 300));

        try {
          final success = await _gasAlarmService.uploadGasAlarmData(
            date: data.formattedDate,
            gasLevel: data.gasLevel,
          );

          if (success) {
            successfullyUploadedIds.add(data.id);
            setDialogState(() {
              _successfulUploads++;
              _currentSyncStatus =
                  "✅ Alarma ${i + 1} subida (${data.alarmStatus} - ${data.displayDateTime})";
            });
          } else {
            setDialogState(() {
              _currentSyncStatus = "❌ Error en alarma ${i + 1}";
            });
          }
        } catch (e) {
          print('Error al sincronizar alarma ${data.id}: $e');
          setDialogState(() {
            _currentSyncStatus = "❌ Error en alarma ${i + 1}: ${e.toString()}";
          });
        }
      }

      // Remover datos sincronizados exitosamente
      if (successfullyUploadedIds.isNotEmpty) {
        setState(() {
          _pendingGasAlarmData.removeWhere(
            (data) => successfullyUploadedIds.contains(data.id),
          );
        });
      }

      // Mostrar resultado final
      setDialogState(() {
        _currentSyncStatus = "🎉 Sincronización de alarmas completada!";
      });

      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  successfullyUploadedIds.length == dataToSync.length
                      ? Icons.check_circle
                      : Icons.warning,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${successfullyUploadedIds.length} de ${dataToSync.length} alarmas sincronizadas exitosamente',
                  ),
                ),
              ],
            ),
            backgroundColor:
                successfullyUploadedIds.length == dataToSync.length
                    ? Colors.green.shade600
                    : Colors.orange.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      setDialogState(() {
        _currentSyncStatus = "❌ Error general: $e";
      });

      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error en sincronización de alarmas: $e')),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  Future<void> _syncIoTDataWithProgress(StateSetter setDialogState) async {
    if (_isSyncing || _pendingIoTData.isEmpty) return;

    setState(() {
      _isSyncing = true;
    });

    setDialogState(() {
      _totalToSync = _pendingIoTData.where((data) => !data.isSynced).length;
      _currentSyncing = 0;
      _successfulUploads = 0;
      _currentSyncStatus = "Preparando sincronización...";
    });

    try {
      final List<IoTData> dataToSync = List.from(
        _pendingIoTData.where((data) => !data.isSynced),
      );
      final List<String> successfullyUploadedIds = [];

      for (int i = 0; i < dataToSync.length; i++) {
        final data = dataToSync[i];

        setDialogState(() {
          _currentSyncing = i + 1;
          _currentSyncStatus =
              "Subiendo registro ${i + 1}/${dataToSync.length} (${data.displayDateTime})";
        });

        // Pequeña pausa para mostrar el progreso
        await Future.delayed(const Duration(milliseconds: 300));

        try {
          final success = await _iotDataService.uploadIoTData(
            date: data.formattedDate,
            temperature: data.temperature,
            humidity: data.humidity,
          );

          if (success) {
            successfullyUploadedIds.add(data.id);
            setDialogState(() {
              _successfulUploads++;
              _currentSyncStatus =
                  "✅ Registro ${i + 1} subido (${data.displayDateTime})";
            });
          } else {
            setDialogState(() {
              _currentSyncStatus = "❌ Error en registro ${i + 1}";
            });
          }
        } catch (e) {
          print('Error al sincronizar dato ${data.id}: $e');
          setDialogState(() {
            _currentSyncStatus =
                "❌ Error en registro ${i + 1}: ${e.toString()}";
          });
        }
      }

      // Remover datos sincronizados exitosamente
      if (successfullyUploadedIds.isNotEmpty) {
        setState(() {
          _pendingIoTData.removeWhere(
            (data) => successfullyUploadedIds.contains(data.id),
          );
        });
      }

      // Mostrar resultado final
      setDialogState(() {
        _currentSyncStatus = "🎉 Sincronización completada!";
      });

      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  successfullyUploadedIds.length == dataToSync.length
                      ? Icons.check_circle
                      : Icons.warning,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${successfullyUploadedIds.length} de ${dataToSync.length} registros sincronizados exitosamente',
                  ),
                ),
              ],
            ),
            backgroundColor:
                successfullyUploadedIds.length == dataToSync.length
                    ? Colors.green.shade600
                    : Colors.orange.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      setDialogState(() {
        _currentSyncStatus = "❌ Error general: $e";
      });

      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error en sincronización: $e')),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
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

    // Inicializar servicios
    _iotDataService = IoTDataService();
    _gasAlarmService = GasAlarmService();

    // Cargar datos pendientes
    // _loadPendingDataFromStorage();

    _requestPermission();

    _bluetooth.state.then((state) {
      setState(() => _bluetoothState = state.isEnabled);
    });

    _bluetooth.onStateChanged().listen((state) {
      switch (state) {
        case BluetoothState.STATE_OFF:
          setState(() {
            _bluetoothState = false;
            // Limpiar la conexión y datos cuando se apaga el Bluetooth
            _deviceConnected = null;
            _connection = null;
            _devices = [];
            temperatureValue = "--";
            humidityValue = "--";
            gasValue = "--";
            alertaGas = false;
            tempAlert = false;
            humAlert = false;
          });
          break;
        case BluetoothState.STATE_ON:
          setState(() => _bluetoothState = true);
          break;
      }
    });

    // Verificar si ya hay una conexión activa
    _checkExistingConnection();
  }

  void _checkExistingConnection() async {
    try {
      // Verificar si hay una conexión activa
      if (_connection?.isConnected ?? false) {
        print('Conexión existente detectada');
        setState(() {
          // Si ya estamos conectados, no mostrar lista de dispositivos
          _devices = [];
        });
        _receiveData();
        // Enviar comando para asegurar que el LED esté encendido
        _sendData("LED_CONECTADO");
      } else {
        print('No hay conexión activa');
        // Si no hay conexión, asegurar que el estado esté limpio
        setState(() {
          _deviceConnected = null;
          _connection = null;
          temperatureValue = "--";
          humidityValue = "--";
          gasValue = "--";
          alertaGas = false;
          tempAlert = false;
          humAlert = false;
        });
      }
    } catch (e) {
      print('Error verificando conexión existente: $e');
      // En caso de error, limpiar el estado
      setState(() {
        _deviceConnected = null;
        _connection = null;
        temperatureValue = "--";
        humidityValue = "--";
        gasValue = "--";
        alertaGas = false;
        tempAlert = false;
        humAlert = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Color oscuro de fondo como la web
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            // Logo
            Image.asset(
              'assets/img/logo.png',
              height: 32,
              width: 32,
            ),
            const SizedBox(width: 12),
            const Text(
              'WatchBox',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          // Botón de configuración WiFi
          IconButton(
            icon: Icon(
              Icons.settings_input_antenna,
              color: (_connection?.isConnected ?? false) ? Colors.white : Colors.grey.shade500,
            ),
            onPressed: (_connection?.isConnected ?? false)
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WifiConfigPage(
                          connection: _connection,
                        ),
                      ),
                    );
                  }
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.bluetooth_disabled, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Necesitas conectarte a un dispositivo Bluetooth primero'),
                          ],
                        ),
                        backgroundColor: Colors.orange,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
            tooltip: (_connection?.isConnected ?? false)
                ? 'Configurar WiFi ESP32'
                : 'Conecta un dispositivo Bluetooth primero',
          ),
          // Botón de logout
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              // Mostrar diálogo de confirmación
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Cerrar Sesión'),
                    content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancelar'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          // Desconectar Bluetooth si hay conexión activa
                          if (_connection?.isConnected ?? false) {
                            try {
                              _sendData("LED_DESCONECTADO");
                              await Future.delayed(const Duration(milliseconds: 300));
                              await _connection?.finish();
                            } catch (e) {
                              print('Error al desconectar Bluetooth: $e');
                            }
                          }
                          
                          // Ejecutar logout
                          context.read<AuthBloc>().add(LogoutEvent());
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Cerrar Sesión'),
                      ),
                    ],
                  );
                },
              );
            },
            tooltip: 'Cerrar sesión',
          ),
          Stack(
            children: [
              IconButton(
                icon:
                    _isSyncing
                        ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Icon(Icons.sync, color: Colors.white),
                onPressed: _isSyncing ? null : _showSyncDialog,
                tooltip: 'Sincronizar datos',
              ),
              if (_pendingIoTData.isNotEmpty || _pendingGasAlarmData.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 14,
                      minHeight: 14,
                    ),
                    child: Text(
                      '${_pendingIoTData.length + _pendingGasAlarmData.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 8),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
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
      tileColor: const Color(0xFF1E293B),
      title: Text(
        _bluetoothState ? "Bluetooth encendido" : "Bluetooth apagado",
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _infoDevice() {
    return ListTile(
      tileColor: const Color(0xFF1E293B),
      title: Text(
        "Conectado a: ${_deviceConnected?.name ?? "ninguno"}",
        style: const TextStyle(color: Colors.white),
      ),
      trailing:
          _connection?.isConnected ?? false
              ? TextButton(
                onPressed: () async {
                  try {
                    // Enviar comando para apagar LED de conexión antes de desconectar
                    _sendData("LED_DESCONECTADO");
                    await Future.delayed(const Duration(milliseconds: 500)); // Pequeña pausa
                    await _connection?.finish();
                    setState(() {
                      _deviceConnected = null;
                      _connection = null;
                      // Resetear valores de sensores
                      temperatureValue = "--";
                      humidityValue = "--";
                      gasValue = "--";
                      alertaGas = false;
                      tempAlert = false;
                      humAlert = false;
                    });
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Desconectado del dispositivo'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  } catch (e) {
                    print('Error al desconectar: $e');
                    // Forzar desconexión local aunque haya error
                    setState(() {
                      _deviceConnected = null;
                      _connection = null;
                      temperatureValue = "--";
                      humidityValue = "--";
                      gasValue = "--";
                      alertaGas = false;
                      tempAlert = false;
                      humAlert = false;
                    });
                  }
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                ),
                child: const Text("Desconectar"),
              )
              : TextButton(
                onPressed: _bluetoothState
                    ? _getDevices
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Row(
                              children: [
                                Icon(Icons.bluetooth_disabled, color: Colors.white),
                                SizedBox(width: 8),
                                Text('Activa el Bluetooth primero'),
                              ],
                            ),
                            backgroundColor: Colors.orange,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                style: TextButton.styleFrom(
                  foregroundColor: _bluetoothState ? Colors.white : Colors.grey,
                ),
                child: const Text("Ver dispositivos"),
              ),
    );
  }

  Widget _listDevices() {
    // Si ya estamos conectados, mostrar un mensaje en lugar de la lista
    // if (_connection?.isConnected ?? false) {
    //   return Container(
    //     color: Colors.green.shade50,
    //     padding: const EdgeInsets.all(16),
    //     child: Column(
    //       mainAxisAlignment: MainAxisAlignment.center,
    //       children: [
    //         Icon(
    //           Icons.bluetooth_connected,
    //           size: 48,
    //           color: Colors.green.shade600,
    //         ),
    //         const SizedBox(height: 16),
    //         Text(
    //           'Conectado exitosamente',
    //           style: TextStyle(
    //             fontSize: 18,
    //             fontWeight: FontWeight.bold,
    //             color: Colors.green.shade700,
    //           ),
    //         ),
    //         const SizedBox(height: 8),
    //         Text(
    //           'Dispositivo: ${_deviceConnected?.name ?? "Desconocido"}',
    //           style: TextStyle(
    //             fontSize: 14,
    //             color: Colors.green.shade600,
    //           ),
    //         ),
    //       ],
    //     ),
    //   );
    // }

    return _isConnecting
        ? const Center(child: CircularProgressIndicator(color: Colors.white))
        : SingleChildScrollView(
          child: Container(
            color: const Color(0xFF0F172A),
            child: Column(
              children: [
                ...[
                  for (final device in _devices)
                    ListTile(
                      title: Text(
                        device.name ?? device.address,
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blue.shade400,
                        ),
                        child: const Text('conectar'),
                        onPressed: () async {
                          // Verificar si ya estamos conectados antes de intentar conectar
                          if (_connection?.isConnected ?? false) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Ya tienes una conexión activa'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }

                          setState(() => _isConnecting = true);
                          
                          try {
                            _connection = await BluetoothConnection.toAddress(
                              device.address,
                            ).timeout(
                              const Duration(seconds: 10),
                              onTimeout: () {
                                throw Exception('Tiempo de conexión agotado');
                              },
                            );
                            
                            _deviceConnected = device;
                            _devices = [];
                            _isConnecting = false;
                            _receiveData();
                            // Enviar comando para encender LED de conexión
                            _sendData("LED_CONECTADO");
                            setState(() {});
                            
                            // Mostrar mensaje de éxito
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.check_circle, color: Colors.white),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text('Conectado a ${device.name ?? device.address}'),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: Colors.green,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          } catch (e) {
                            setState(() {
                              _isConnecting = false;
                              _connection = null;
                              _deviceConnected = null;
                            });
                            
                            // Determinar mensaje de error más amigable
                            String errorMessage;
                            if (e.toString().contains('Tiempo de conexión agotado')) {
                              errorMessage = 'No se pudo conectar. El dispositivo no responde.';
                            } else if (e.toString().contains('socket might closed or timeout')) {
                              errorMessage = 'Dispositivo no disponible o apagado';
                            } else if (e.toString().contains('read failed')) {
                              errorMessage = 'Error de lectura. Dispositivo desconectado';
                            } else {
                              errorMessage = 'No se pudo conectar al dispositivo';
                            }
                            
                            // Mostrar error de forma amigable
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.bluetooth_disabled, color: Colors.white),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(errorMessage)),
                                    ],
                                  ),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            }
                            
                            print('Error de conexión: $e');
                          }
                        },
                      ),
                    ),
                ],
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
        color: const Color(0xFF0F172A),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Monitoreo en tiempo real',
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 16),

            _buildDataCard(
              "Temperatura",
              "°C",
              temperatureValue,
              tempAlert,
              tempAlertType,
              () => _showConfigDialog("temp"),
            ),
            const SizedBox(height: 12),
            _buildDataCard(
              "Humedad",
              "%",
              humidityValue,
              humAlert,
              humAlertType,
              () => _showConfigDialog("hum"),
            ),
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
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          // Enviar comando al dispositivo IoT
                          _sendData("APAGAR_ALARMA");

                          // Esperar 2 segundos y luego quitar la alarma automáticamente
                          Future.delayed(const Duration(seconds: 2), () {
                            if (mounted) {
                              setState(() {
                                alertaGas = false;
                              });
                              // _saveGasAlarmData(false);
                            }
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
  const MyButtonLed({
    super.key,
    required this.titulo,
    required this.data,
    required this.data2,
    required this.color,
    required this.connection,
  });
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
            color: widget.color,
            borderRadius: BorderRadius.circular(8.0),
          ),
          width: screenSize.width * 0.3,
          height: screenSize.height * 0.08,
          child: Center(
            child: Text(
              widget.titulo,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _buildDataCard(
  String label,
  String unidad,
  String value,
  bool hasAlert,
  String alertType,
  VoidCallback? onConfigTap,
) {
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
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (hasAlert) ...[
                const SizedBox(width: 8),
                Icon(
                  alertType == "low"
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_up,
                  color:
                      alertType == "low"
                          ? Colors.blue.shade700
                          : Colors.red.shade700,
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
