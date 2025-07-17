import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:watchmen_box/providers/auth_bloc/auth_bloc.dart';
import 'package:watchmen_box/providers/go_router_notifier.dart';
import 'package:watchmen_box/views/check_status_screend.dart';
import 'package:watchmen_box/views/login.dart';
import 'package:watchmen_box/views/main_page.dart';
GoRouter createAppRouter(BuildContext context) {
  final goRouterNotifier = GoRouterNotifier(context.read<AuthBloc>()); // Instancia del notifier
  final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
  return GoRouter(
    navigatorKey: rootNavigatorKey, // Se asigna la clave del navegador raíz
    refreshListenable: goRouterNotifier, // Se pasa el notifier al router
    redirect: (context, state) {
      final authState = context.read<AuthBloc>().state;
      print('GoRouter redirect: Current authStatus is ${authState.authStatus}');

      final isAuthenticated = authState.authStatus == AuthStatus.authenticated;
      final isChecking = authState.authStatus == AuthStatus.checking;
      final isOnAuthPages = _isOnAuthPages(state.matchedLocation);

      // Validaciones del redirect
      if (isChecking) return null; // No redirigir mientras se verifica el estado de autenticación
      if (!isAuthenticated && !isOnAuthPages) return '/login'; // Redirigir al login si no está autenticado
      if (isAuthenticated && isOnAuthPages) return '/'; // Redirigir al home si está autenticado y en páginas de login
      if (isAuthenticated && state.matchedLocation == '/loading') return '/'; // Redirigir al home desde la pantalla de carga

      return null; // Mantener la ruta actual si no se cumplen las condiciones
    },
    initialLocation: '/loading',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/loading',
        builder: (context, state) => const CheckAuthStatusScreen(), // Pantalla de carga
      ),

      GoRoute(
        path: '/',
        builder: (context, state) => const MainPage(),
      )
      
    ],
  );
}

// Función auxiliar para verificar si la ubicación actual está en las páginas de autenticación
bool _isOnAuthPages(String? matchedLocation) {
  return matchedLocation == '/login' || matchedLocation == '/register';
}