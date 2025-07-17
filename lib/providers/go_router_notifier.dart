
import 'package:flutter/material.dart';
import 'package:watchmen_box/providers/auth_bloc/auth_bloc.dart';


class GoRouterNotifier extends ChangeNotifier {

  final AuthBloc _authNotifier; //ocupo una instanciá de mi bloc para escuchar los cambios de estado

  AuthStatus _authStatus = AuthStatus.checking; //creo un AuthStatus que por defecto es checking

  GoRouterNotifier(this._authNotifier) { //constructor que recibe el bloc
    _authNotifier.stream.listen((state) { //*escuchamos todo el tiempo el estado del bloc
      authStatus = state.authStatus!; //utilizamos el setter para cambiar el estado del authStatus
    });
  }

  AuthStatus get authStatus => _authStatus; //getter para obtener el _authStatus

  set authStatus( AuthStatus value ) { //setter para cambiar el _authStatus
    _authStatus = value;
    notifyListeners();
  }

}