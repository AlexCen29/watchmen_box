class GasAlarmData {
  final String id;
  final DateTime timestamp;
  final double gasLevel;
  final bool isAlarmActive; // true = alarma activada, false = alarma desactivada
  bool isSynced;

  GasAlarmData({
    required this.id,
    required this.timestamp,
    required this.gasLevel,
    required this.isAlarmActive,
    this.isSynced = false,
  });

  String get formattedDate {
    // Formato ISO 8601 completo con fecha y hora
    return timestamp.toIso8601String();
  }
  
  String get displayDateTime {
    // Formato para mostrar en la UI de manera más legible
    return "${timestamp.day.toString().padLeft(2, '0')}/${timestamp.month.toString().padLeft(2, '0')}/${timestamp.year} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}";
  }

  String get alarmStatus => isAlarmActive ? "Activada" : "Desactivada";

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'gasLevel': gasLevel,
      'isAlarmActive': isAlarmActive,
      'isSynced': isSynced,
    };
  }

  factory GasAlarmData.fromJson(Map<String, dynamic> json) {
    return GasAlarmData(
      id: json['id'],
      timestamp: DateTime.parse(json['timestamp']),
      gasLevel: json['gasLevel'].toDouble(),
      isAlarmActive: json['isAlarmActive'],
      isSynced: json['isSynced'] ?? false,
    );
  }
}
