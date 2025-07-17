import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:watchmen_box/providers/auth_bloc/auth_bloc.dart';

class AppBlocProviders extends StatelessWidget {
  final Widget main;
  const AppBlocProviders({super.key, required this.main});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => AuthBloc()..add(CheckAuthStatus())),
        
      ],
      child: main,
    );
  }
}
