
class WrongCredentials implements Exception {
  final String? message;
  final int? statusCode;
  WrongCredentials({
    this.message,
    this.statusCode
    });
}
class InvalidToken implements Exception {
  final String? message;
  final int? statusCode;
  InvalidToken({
    this.message, 
    this.statusCode
    });
}
class ConnectionTimeout implements Exception {}
class CustomError implements Exception {
  final String message;
  final int statusCode;
  CustomError(
    this.message,
    this.statusCode
    );
}
class MappingError implements Exception {
  final String message;
  MappingError(this.message);
}
class InvalidRefreshToken implements Exception {
  final String? message;
  InvalidRefreshToken({this.message});
}