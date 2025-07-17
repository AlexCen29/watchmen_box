import 'package:watchmen_box/errors/general_errors.dart';

const List<String> validRoles = ['ADMIN', 'OPERATOR', 'DELIVERY', 'SUPER_ADMIN'];

class User {
  final int id;
  final String fullName;
  final String email;
  final String accessToken;
  final String role;
  final bool? emailVerified;

  User({
    required this.id,
    required this.fullName,
    required this.email,
    required this.accessToken,
    required this.role,
    this.emailVerified = false,
  });

  static User mapJsonToUserEntity(Map<String, dynamic> json) {
    final user = json['user'];
    final id = user['userId'];
    final fullName = user['name'];
    final email = user['email'];
    final emailVerified = user['emailVerified'];
    final acessToken = json['token'];
    final role = user['rol'];

    if(id is! int) throw MappingError('Invalid or missing "userId"');
    if(fullName is! String) throw MappingError('Invalid or missing "name"');
    if(email is! String) throw MappingError('Invalid or missing "email"');
    if(emailVerified is! bool?) throw MappingError('Invalid or missing "emailVerified"');
    if(acessToken is! String) throw MappingError('Invalid or missing "token"');
    if(role is! String) throw MappingError('Invalid or missing "rol"');

    return User(
      id: id,
      fullName: fullName,
      email: email,
      emailVerified: emailVerified,
      accessToken: acessToken,
      role: role,
    );

  }

}