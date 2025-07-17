import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import 'package:formz/formz.dart';
import 'package:watchmen_box/inputs/index.dart';
import 'package:watchmen_box/providers/auth_bloc/auth_bloc.dart';

part 'register_form_event.dart';
part 'register_form_state.dart';

class RegisterFormBloc extends Bloc<RegisterEvent, RegisterFormState> {
  final AuthBloc authBloc;

  RegisterFormBloc({ required this.authBloc }) : super(RegisterFormState()) {

    void touchEveryField(Emitter<RegisterFormState> emit) {
      final email = Email.dirty(value: state.email.value);
      final password = Password.dirty(value: state.password.value);
        
      emit(state.copyWith(
        email: email,
        password: password,
        isFormPosted: true, //para mostrar los errores del form.
        isValid: Formz.validate([email, password]),
      ));

      // print('state: ${{
      //   "isFormPosted": state.isFormPosted,
      //   "isValid": state.isValid,
      //   "email": state.email,
      //   "password": state.password
      // }}');
    }

    on<SubmitForm>((event, emit) async {
      touchEveryField(emit);

      if (!state.isValid) return;

      emit(state.copyWith(isPosting: true));
      print('state: ${{
        "isFormPosted": state.isFormPosted,
        "isPosting": state.isPosting,
        "isValid": state.isValid,
        "email": state.email,
        "password": state.password
      }}');

      // Crear un Completer para esperar el resultado del AuthBloc
      final completer = Completer<void>();

        // Escuchar el estado del AuthBloc
        final subscription = authBloc.stream.listen((authState) {
        if (authState.authStatus != AuthStatus.checking || //verifica que el estado sea diferente a checking
            (authState.errorMessage != null && authState.errorMessage!.isNotEmpty)) { // y que tenga un error que no sea nulo.
          if (!completer.isCompleted) {
            completer.complete();
          }
        }
      });


        // Enviar el evento al AuthBloc
        authBloc.add(
          LoginEvent(
            state.email.value,
            state.password.value,
          ),
        );

        // Esperar a que el AuthBloc procese el evento
        await completer.future;

        // Cancelar la suscripción al stream
        await subscription.cancel();
        emit(state.copyWith(isPosting: false)); //*Para que legue aquí tiene que salir todo bien en el loginEvent - ya que si no sale bien, no llegará a este punto.
    });

    on<UpdateEmail>((event, emit) {
      final newEmail = Email.dirty(value: event.email);
      emit(state.copyWith(
        email: newEmail,
        isValid: Formz.validate([newEmail, state.password]),
      ));
    });

    on<UpdatePassword>((event, emit) {
      final newPassword = Password.dirty(value: event.password);
      emit(state.copyWith(
        password: newPassword,
        isValid: Formz.validate([state.email, newPassword]),
      ));
    });

    on<UpdateIsDialogOpen>((event, emit) {
      emit(state.copyWith(
        isDialogOpen: event.isDialogOpen,
      ));
    });
  }
}
