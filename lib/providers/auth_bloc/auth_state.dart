part of 'auth_bloc.dart';

enum AuthStatus { authenticated, notAuthenticated, checking }

class AuthState extends Equatable {
  final AuthStatus? authStatus;
  final User? user;
  final String? errorMessage;
  const AuthState({
    this.authStatus = AuthStatus.checking,
    this.errorMessage = '',
    this.user,
    });

    AuthState copyWith({
    AuthStatus? authStatus,
    User? user,
    String? errorMessage,
  }) => AuthState(
    authStatus: authStatus ?? this.authStatus,
    user: user ?? this.user,
    errorMessage: errorMessage ?? this.errorMessage
  );
  
  @override
  List<Object?> get props => [authStatus, user, errorMessage];
}

