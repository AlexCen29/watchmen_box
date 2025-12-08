
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Environment {
  static initEnviroment() async {
    try {
      await dotenv.load(fileName: '.env');
      print('✅ .env cargado correctamente');
      print('API_URL: ${dotenv.env['API_URL']}');
    } catch (e) {
      print('❌ Error cargando .env: $e');
    }
  }
  static String apiUrl = dotenv.env['API_URL'] ?? 'No esta configurado el API_URL';
}