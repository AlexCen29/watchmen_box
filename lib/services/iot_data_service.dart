import 'package:dio/dio.dart';
import 'package:watchmen_box/config/constants/enviroment.dart';
import 'package:watchmen_box/errors/general_errors.dart';
import 'package:watchmen_box/services/key_value_storage_service.impl.dart';

class IoTDataService {
  final Dio dio;
  final KeyValueStorageServiceImpl _keyValueService;

  IoTDataService()
      : dio = Dio(
          BaseOptions(
            baseUrl: Environment.apiUrl,
          ),
        ),
        _keyValueService = KeyValueStorageServiceImpl();

  Future<bool> uploadIoTData({
    required String date,
    required double temperature,
    required double humidity,
  }) async {
    try {
      // Obtener el token de autenticación
      final token = await _keyValueService.getValue<String>('accessToken');
      if (token == null) {
        throw CustomError('No hay token de autenticación', 401);
      }

      final response = await dio.post(
        '/iotlog/register',
        data: {
          "date": date,
          "temperature": temperature.toInt(),
          "humidity": humidity.toInt(),
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      return response.statusCode == 201 || response.statusCode == 200;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw InvalidToken();
      }
      if (e.response?.statusCode == 400) {
        throw CustomError('Datos inválidos: ${e.response?.data}', 400);
      }
      if (e.type == DioExceptionType.connectionTimeout) {
        throw ConnectionTimeout();
      }
      throw CustomError('Error al subir datos IoT: ${e.message}', 500);
    } catch (e) {
      throw CustomError('Error inesperado: $e', 500);
    }
  }
}