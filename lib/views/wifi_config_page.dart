import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:watchmen_box/providers/auth_bloc/auth_bloc.dart';

class WifiConfigPage extends StatefulWidget {
  final BluetoothConnection? connection;

  const WifiConfigPage({
    super.key,
    required this.connection,
  });

  @override
  State<WifiConfigPage> createState() => _WifiConfigPageState();
}

class _WifiConfigPageState extends State<WifiConfigPage> {
  final _formKey = GlobalKey<FormState>();
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isSending = false;
  bool _obscurePassword = true;
  String _statusMessage = '';
  Color _statusColor = Colors.grey;

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _sendConfiguration() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (widget.connection == null || !widget.connection!.isConnected) {
      setState(() {
        _statusMessage = '❌ No hay conexión Bluetooth activa';
        _statusColor = Colors.red;
      });
      return;
    }

    setState(() {
      _isSending = true;
      _statusMessage = 'Enviando configuración...';
      _statusColor = Colors.orange;
    });

    try {
      final authState = context.read<AuthBloc>().state;
      final token = authState.user?.accessToken ?? '';

      if (token.isEmpty) {
        setState(() {
          _statusMessage = '❌ No hay token de autenticación';
          _statusColor = Colors.red;
          _isSending = false;
        });
        return;
      }

      final ssid = _ssidController.text.trim();
      final password = _passwordController.text.trim();

      // Enviar SSID
      widget.connection!.output.add(
        Uint8List.fromList('CONFIG:SSID:$ssid\n'.codeUnits),
      );
      await widget.connection!.output.allSent;
      await Future.delayed(const Duration(milliseconds: 500));

      // Enviar Password
      widget.connection!.output.add(
        Uint8List.fromList('CONFIG:PASS:$password\n'.codeUnits),
      );
      await widget.connection!.output.allSent;
      await Future.delayed(const Duration(milliseconds: 500));

      // Enviar Token
      widget.connection!.output.add(
        Uint8List.fromList('CONFIG:TOKEN:$token\n'.codeUnits),
      );
      await widget.connection!.output.allSent;

      setState(() {
        _statusMessage = '✅ Configuración enviada correctamente';
        _statusColor = Colors.green;
        _isSending = false;
      });

      // Mostrar diálogo de éxito
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Éxito'),
              ],
            ),
            content: const Text(
              'La configuración WiFi fue enviada al ESP32.\n\n'
              'El dispositivo intentará conectarse a la red configurada.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _statusMessage = '❌ Error al enviar: $e';
        _statusColor = Colors.red;
        _isSending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración WiFi'),
        backgroundColor: Colors.orange.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Indicador de conexión BT
              Card(
                color: widget.connection?.isConnected == true
                    ? Colors.green.shade50
                    : Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        widget.connection?.isConnected == true
                            ? Icons.bluetooth_connected
                            : Icons.bluetooth_disabled,
                        color: widget.connection?.isConnected == true
                            ? Colors.green
                            : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.connection?.isConnected == true
                            ? 'Conectado vía Bluetooth'
                            : 'Sin conexión Bluetooth',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: widget.connection?.isConnected == true
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Información
              const Text(
                'Configura la red WiFi para que tu ESP32 pueda enviar datos a la nube.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),

              // Campo SSID
              TextFormField(
                controller: _ssidController,
                decoration: InputDecoration(
                  labelText: 'Nombre de la red (SSID)',
                  hintText: 'Ej: MiWiFi_2.4GHz',
                  prefixIcon: const Icon(Icons.wifi),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa el nombre de la red WiFi';
                  }
                  return null;
                },
                enabled: !_isSending,
              ),
              const SizedBox(height: 16),

              // Campo Password
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Contraseña WiFi',
                  hintText: 'Contraseña de tu red',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa la contraseña de la red';
                  }
                  if (value.length < 8) {
                    return 'La contraseña debe tener al menos 8 caracteres';
                  }
                  return null;
                },
                enabled: !_isSending,
              ),
              const SizedBox(height: 24),

              // Botón enviar
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSending ? null : _sendConfiguration,
                  icon: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send),
                  label: Text(
                    _isSending ? 'Enviando...' : 'Enviar configuración',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Mensaje de estado
              if (_statusMessage.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _statusColor),
                  ),
                  child: Row(
                    children: [
                      Icon(_statusColor == Colors.green
                          ? Icons.check_circle
                          : _statusColor == Colors.red
                              ? Icons.error
                              : Icons.info),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusMessage,
                          style: TextStyle(color: _statusColor),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),

              // Ayuda
              ExpansionTile(
                title: const Text('¿Cómo funciona esto?'),
                leading: const Icon(Icons.help_outline),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHelpItem(
                          '1.',
                          'Ingresa el nombre y contraseña de tu red WiFi',
                        ),
                        _buildHelpItem(
                          '2.',
                          'Al presionar "Enviar", se enviará la configuración al ESP32 vía Bluetooth',
                        ),
                        _buildHelpItem(
                          '3.',
                          'El ESP32 se desconectará de la red actual e intentará conectarse a la nueva',
                        ),
                        _buildHelpItem(
                          '4.',
                          'Una vez conectado, comenzará a enviar datos automáticamente',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHelpItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            number,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
