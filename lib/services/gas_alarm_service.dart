import 'package:dio/dio.dart';
import 'package:watchmen_box/config/constants/enviroment.dart';
import 'package:watchmen_box/errors/general_errors.dart';
import 'package:watchmen_box/services/key_value_storage_service.impl.dart';

class GasAlarmService {
  final Dio dio;
  final KeyValueStorageServiceImpl _keyValueService;

  GasAlarmService()
      : dio = Dio(
          BaseOptions(
            baseUrl: Environment.apiUrl,
          ),
        ),
        _keyValueService = KeyValueStorageServiceImpl();

  Future<bool> uploadGasAlarmData({
    required String date,
    required double gasLevel,
  }) async {
    try {
      // Obtener el token de autenticación
      final token = await _keyValueService.getValue<String>('accessToken');
      if (token == null) {
        throw CustomError('No hay token de autenticación', 401);
      }

      final data = {
        'date': date,
        'gasLevel': gasLevel.toInt(),
      };

      print('Enviando datos de alarma de gas: $data');

      final response = await dio.post(
        '/gas-alarm/register',
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      print('Respuesta del servidor: ${response.statusCode} - ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('Datos de alarma de gas enviados exitosamente');
        return true;
      } else {
        print('Error al enviar datos de alarma de gas: ${response.statusCode} - ${response.data}');
        return false;
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw InvalidToken();
      }
      if (e.response?.statusCode == 400) {
        throw CustomError('Datos inválidos para la alarma de gas', 400);
      }
      print('Error en uploadGasAlarmData: $e');
      return false;
    } catch (e) {
      print('Error en uploadGasAlarmData: $e');
      return false;
    }
  }
}
