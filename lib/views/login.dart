import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:watchmen_box/providers/auth_bloc/auth_bloc.dart';
import 'package:watchmen_box/providers/register_form_bloc/register_form_bloc.dart';
import 'package:watchmen_box/widgets/login_form.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: BlocProvider(
        create: (context) => RegisterFormBloc(authBloc: context.read<AuthBloc>()),
        child: Stack(
          children: [
            // Cabecera naranja Fija
            Container(
              height: size.height * 0.5,
              width: double.infinity,
              color: const Color(0xFF1E293B),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  LoginIcon(size: size)
                ],
              ),
            ),

            // Cuerpo scrollable con formulario, fondo blanco
            Align(
              alignment: Alignment.bottomCenter,
              child: FormContainer(
                height: size.height * 0.68,
                loginForm: LoginForm()
                )
            ),
          ],
        ),
      ),
    );
  }
}

class FormContainer extends StatelessWidget {
  final Widget loginForm;
  final double height;
  const FormContainer({super.key, required this.loginForm, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height, // altura fija, no se mueve con teclado
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(100),
          topRight: Radius.circular(100),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min, //?
          children: [
            SizedBox(height: 20),
            loginForm,
          ],
        ),
      ),
    );
  }
}

class LoginIcon extends StatelessWidget {
  const LoginIcon({
    super.key,
    required this.size,
  });

  final Size size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: size.height * 0.09),
      child: Center(
        child: AnimatedScale(
          scale: 1.15,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(24),
                  spreadRadius: 5,
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(5.0),
              child: const Icon(
                Icons.person_pin,
                color: Colors.white,
                size: 100,
              ),
            ),
          ),
        ),
      ),
    );
  }
}