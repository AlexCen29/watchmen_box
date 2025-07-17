import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import 'package:flutter/material.dart';
import 'package:watchmen_box/entities/user.entity.dart';
import 'package:watchmen_box/errors/general_errors.dart';
import 'package:watchmen_box/services/key_value_storage_service.dart';
import 'package:watchmen_box/services/key_value_storage_service.impl.dart';
import 'package:watchmen_box/services/render_auth_service.dart';

part 'auth_event.dart';
part 'auth_state.dart';


class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final RenderAuthService _authService;
  final KeyValueStorageService _keyValueStorageService;

  AuthBloc({
    RenderAuthService? authService,
    KeyValueStorageService? keyValueStorageService,
    })
    : _authService = authService ?? RenderAuthService(),
      _keyValueStorageService = keyValueStorageService ?? KeyValueStorageServiceImpl(),
      super(AuthState()) {

    Future<void> setLoggedUser({ required User user, required Emitter<AuthState> emit}) async {
      await _keyValueStorageService.setKeyValue('accessToken', user.accessToken);

      emit(state.copyWith(
        authStatus: AuthStatus.authenticated,
        errorMessage: '',
        user: user,
      ));
      // print('AuthBloc: state: ${ state.authStatus}');
    }

    Future<void> logout({String? errorMessage, required Emitter<AuthState> emit}) async {
      await _keyValueStorageService.removeKey('accessToken');
      //TODO: Implementar el logout en el backend Y ejecutar la ruta desde aquí.
      emit(state.copyWith(
        authStatus: AuthStatus.notAuthenticated,
        user: null,
        errorMessage: errorMessage,
      ));
      // print('AuthBloc: state: ${ state.authStatus}');
    }

    on<CheckAuthStatus>((event, emit) async { //* Check if the user is authenticated every time the app starts
      // print('AuthBloc: state: ${state.authStatus}');
      final accessToken = await _keyValueStorageService.getValue<String>('accessToken');

      if (accessToken == null ) {
        return await logout(emit: emit);
      }

      try {
        final User user = await _authService.checkAuthStatus(accessToken);
        await setLoggedUser(user: user, emit: emit);
      } on InvalidToken {
        await logout(emit: emit, errorMessage: 'Token inválido');
      } catch (e) {
        await logout(emit: emit, errorMessage: 'Error not controlled');
      }
    });

    on<LoginEvent>((event, emit) async {
      try {
        final User user = await _authService.login(event.email, event.password);
        await setLoggedUser(user: user, emit: emit);
      } on WrongCredentials catch (e) {
        await logout(
          errorMessage: '${e.message} ${UniqueKey().toString()}', 
          emit: emit
          );
      } on CustomError catch (e) {
        await logout(
          errorMessage: '${e.message} ${UniqueKey().toString()}',
          emit: emit
          );
      } on MappingError catch (e) {
        await logout(
          errorMessage: '${e.message} ${UniqueKey().toString()}', 
          emit: emit
          );
      } on ConnectionTimeout {
        await logout(
          errorMessage: 'Timeout de conexión ${UniqueKey().toString()}', 
          emit: emit
          );
      } catch (e) {
        await logout(
          emit: emit,
          errorMessage: 'Erorr not controlled ${UniqueKey().toString()}', 
        );
      }
    });

  }
}
