class IoTData {
  final String id;
  final DateTime timestamp;
  final double temperature;
  final double humidity;
  final bool isSynced;

  IoTData({
    required this.id,
    required this.timestamp,
    required this.temperature,
    required this.humidity,
    this.isSynced = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'temperature': temperature,
      'humidity': humidity,
      'isSynced': isSynced,
    };
  }

  factory IoTData.fromJson(Map<String, dynamic> json) {
    return IoTData(
      id: json['id'],
      timestamp: DateTime.parse(json['timestamp']),
      temperature: json['temperature'].toDouble(),
      humidity: json['humidity'].toDouble(),
      isSynced: json['isSynced'] ?? false,
    );
  }

  String get formattedDate {
    // Formato ISO 8601 completo con fecha y hora
    return timestamp.toIso8601String();
  }

  String get displayDateTime {
    // Formato para mostrar en la UI de manera más legible
    return "${timestamp.day.toString().padLeft(2, '0')}/${timestamp.month.toString().padLeft(2, '0')}/${timestamp.year} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}";
  }

  IoTData copyWith({
    String? id,
    DateTime? timestamp,
    double? temperature,
    double? humidity,
    bool? isSynced,
  }) {
    return IoTData(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      temperature: temperature ?? this.temperature,
      humidity: humidity ?? this.humidity,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
