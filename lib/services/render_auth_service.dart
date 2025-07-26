import 'package:dio/dio.dart';
import 'package:watchmen_box/config/constants/enviroment.dart';
import 'package:watchmen_box/entities/user.entity.dart';
import 'package:watchmen_box/errors/general_errors.dart';



class RenderAuthService {

  final Dio dio; //!Dio is a coupled dependency Datasources

  RenderAuthService()
      : dio = Dio(
        BaseOptions(
          baseUrl: Environment.apiUrl,
          ),
        );

  Future<User> login(String email, String password) async {
    await Future.delayed(Duration(milliseconds: 500));
    try {
      final response = await dio.post(
        '/auth/login',
        data: {
          "email": email,
          "password": password,
        },
      );
      final User user = User.mapJsonToUserEntity(response.data);
      return user;
    } on DioException catch (e) {
      if( e.response?.statusCode == 404 || e.response?.statusCode == 400) throw WrongCredentials( message: e.response?.data['error']);
      if( e.type == DioExceptionType.connectionTimeout ) throw ConnectionTimeout();
      throw CustomError('Unexpected DioException', 500);
    }
  }
  
  Future<User> checkAuthStatus(String accessToken) async {
    try{
      final response = await dio.post(
        '/auth/check-auth-status',
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
          }
        )
      );

      final Map<String, dynamic> data = {
        ...response.data,
        "token": accessToken
      };

      final user = User.mapJsonToUserEntity(data);

      return user;

    } on DioException catch (e) {
      if( e.response?.statusCode == 401 ) throw InvalidToken();
      if( e.type == DioExceptionType.connectionTimeout ) throw ConnectionTimeout();
      throw CustomError('Unexpected DioException', 500);
    }
  }
  
}