import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  void initState() {
    super.initState();
    _loadSavedConfiguration();
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Cargar configuración guardada
  Future<void> _loadSavedConfiguration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedSsid = prefs.getString('wifi_ssid') ?? '';
      final savedPassword = prefs.getString('wifi_password') ?? '';
      
      setState(() {
        _ssidController.text = savedSsid;
        _passwordController.text = savedPassword;
      });
    } catch (e) {
      print('Error al cargar configuración: $e');
    }
  }

  // Guardar configuración
  Future<void> _saveConfiguration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('wifi_ssid', _ssidController.text.trim());
      await prefs.setString('wifi_password', _passwordController.text.trim());
    } catch (e) {
      print('Error al guardar configuración: $e');
    }
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

      // Guardar la configuración para uso futuro
      await _saveConfiguration();

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
              'La configuración WiFi fue enviada a la WatchBox.\n\n'
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
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Configuración WiFi'),
        backgroundColor: const Color(0xFF6366F1),
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
                    ? const Color(0xFF1E293B)
                    : const Color(0xFF1E293B),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        widget.connection?.isConnected == true
                            ? Icons.bluetooth_connected
                            : Icons.bluetooth_disabled,
                        color: widget.connection?.isConnected == true
                            ? Colors.green.shade400
                            : Colors.red.shade400,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.connection?.isConnected == true
                            ? 'Conectado vía Bluetooth'
                            : 'Sin conexión Bluetooth',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: widget.connection?.isConnected == true
                              ? Colors.green.shade400
                              : Colors.red.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Información
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Configura la red WiFi para que tu WatchBox pueda enviar datos a la página web.',
                      style: TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                  ),
                  if (_ssidController.text.isNotEmpty || _passwordController.text.isNotEmpty)
                    Tooltip(
                      message: 'Datos cargados desde configuración guardada',
                      child: Icon(
                        Icons.save,
                        size: 18,
                        color: Colors.green.shade600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // Campo SSID
              TextFormField(
                controller: _ssidController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Nombre de la red (SSID)',
                  labelStyle: const TextStyle(color: Colors.white70),
                  hintText: 'Ej: MiWiFi_2.4GHz',
                  hintStyle: TextStyle(color: Colors.grey.shade600),
                  prefixIcon: Icon(Icons.wifi, color: Colors.blue.shade400),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade700),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
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
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Contraseña WiFi',
                  labelStyle: const TextStyle(color: Colors.white70),
                  hintText: 'Contraseña de tu red',
                  hintStyle: TextStyle(color: Colors.grey.shade600),
                  prefixIcon: Icon(Icons.lock, color: Colors.blue.shade400),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.grey.shade400,
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
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade700),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
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
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Botón para limpiar datos guardados
              TextButton.icon(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Limpiar datos guardados'),
                      content: const Text(
                        '¿Quieres borrar el SSID y contraseña guardados?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Limpiar'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('wifi_ssid');
                    await prefs.remove('wifi_password');
                    setState(() {
                      _ssidController.clear();
                      _passwordController.clear();
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Datos guardados eliminados'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Limpiar datos guardados'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade400,
                ),
              ),
              const SizedBox(height: 8),

              // Mensaje de estado
              if (_statusMessage.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _statusColor),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _statusColor == Colors.green
                            ? Icons.check_circle
                            : _statusColor == Colors.red
                                ? Icons.error
                                : Icons.info,
                        color: _statusColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusMessage,
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),

              // Ayuda
              ExpansionTile(
                title: const Text(
                  '¿Cómo funciona esto?',
                  style: TextStyle(color: Colors.white),
                ),
                leading: Icon(Icons.help_outline, color: Colors.blue.shade400),
                iconColor: Colors.white,
                collapsedIconColor: Colors.grey.shade400,
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
                          'Al presionar "Enviar", se enviará la configuración a la WatchBox vía Bluetooth',
                        ),
                        _buildHelpItem(
                          '3.',
                          'La WatchBox se desconectará de la red actual e intentará conectarse a la nueva',
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
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}
