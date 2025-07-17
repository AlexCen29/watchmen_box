import 'package:flutter/material.dart';
import 'package:watchmen_box/app_bloc_providets.dart';
import 'package:watchmen_box/config/app.router.dart';
import 'package:watchmen_box/config/constants/enviroment.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Environment.initEnviroment();
  runApp(AppBlocProviders(main: MainApp()));
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final router = createAppRouter(context);
        return MaterialApp.router(
          theme: ThemeData(useMaterial3: true),
          debugShowCheckedModeBanner: false,
          routerConfig: router,
        );
      },
    );
  }
}