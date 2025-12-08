import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:watchmen_box/config/themes/font/font_styles.dart';
import 'package:watchmen_box/providers/auth_bloc/auth_bloc.dart';
import 'package:watchmen_box/providers/register_form_bloc/register_form_bloc.dart';
import 'package:watchmen_box/widgets/custom_filled_button.dart';
import 'package:watchmen_box/widgets/custom_text_form_field.dart';


class LoginForm extends StatelessWidget {
  const LoginForm({super.key});

  void showSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final sizeWidth = MediaQuery.of(context).size.width;
    final registerFormBloc = context.watch<RegisterFormBloc>();
    final email = registerFormBloc.state.email;
    final password = registerFormBloc.state.password;
    return MultiBlocListener(
      listeners: [
        BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {

            if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
              // Si hay un mensaje de error se muestra
              showSnackbar(context, state.errorMessage!);
            }
          },
        ),
        BlocListener<RegisterFormBloc, RegisterFormState>(
          listener: (context, state) {
            if(state.isPosting && state.isValid && !state.isDialogOpen) { //se activa al enviar el formulario
            registerFormBloc.add(const UpdateIsDialogOpen(true)); //abrir el dialogo de carga.
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF6366F1),
                ),
              ),
            );
            } 

            if (!state.isPosting && state.isDialogOpen) { // isDialogOpen no es persistente cuando se vuelve a renderizar el widget.
              // Cerrar el diálogo solo si está abierto
              Navigator.of(context, rootNavigator: true).pop();
              registerFormBloc.add(const UpdateIsDialogOpen(false)); //cerrar el dialogo de carga.
            }

          },
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Form(
          child: Column(
            children: [
              const SizedBox(height: 20),
              Text('Login', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 45),
              CustomTextFormField(
                width: sizeWidth * 0.7,
                label: "Correo",
                hint: "Ingresa tu correo",
                icon: Icons.email,
                keyboardType: TextInputType.emailAddress,
                color: const Color(0xFF6366F1),
                fillColor: const Color(0xFF1E293B),
                textStyle: const TextStyle(fontSize: 14, color: Colors.white),
                onChanged: (value) => registerFormBloc.add(UpdateEmail(value)),
                errorMessage: registerFormBloc.state.isFormPosted
                    ? email.errorMessage
                    : null,
              ),
              const SizedBox(height: 40),
              CustomTextFormField(
                width: sizeWidth * 0.7,
                label: 'Contraseña',
                hint: 'Ingresa tu contraseña',
                icon: Icons.lock,
                keyboardType: TextInputType.visiblePassword,
                color: const Color(0xFF6366F1),
                fillColor: const Color(0xFF1E293B),
                obscureText: true,
                textStyle: const TextStyle(fontSize: 14, color: Colors.white),
                onChanged: (value) =>
                    registerFormBloc.add(UpdatePassword(value)),
                errorMessage: registerFormBloc.state.isFormPosted
                    ? password.errorMessage
                    : null,
              ),
              const SizedBox(height: 35),
              SizedBox(
                width: sizeWidth * 0.7,
                height: 50,
                child: CustomFilledButtomn(
                  text: 'Iniciar Sesión',
                  buttonColor: const Color(0xFF6366F1),
                  onPressed: registerFormBloc.state.isPosting
                  ? null //se desactivo el boton cunado se estan autenticando las credenciales.
                  : () => registerFormBloc.add(SubmitForm())
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
