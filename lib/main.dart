import 'package:authentication_repository/authentication_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:phone_authentication_project/app/view/app.dart';
import 'package:phone_authentication_project/bloc_observer.dart';
import 'package:phone_authentication_project/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Bloc.observer = AppBlocObserver();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final authenticationRepository = AuthenticationRepository();
    await authenticationRepository.user.first;

    runApp(App(authenticationRepository: authenticationRepository));
  } catch (error, stackTrace) {
    runApp(FirebaseBootstrapErrorApp(
      error: error.toString(),
      stackTrace: stackTrace.toString(),
    ));
  }
}

class FirebaseBootstrapErrorApp extends StatelessWidget {
  const FirebaseBootstrapErrorApp({
    required this.error,
    required this.stackTrace,
    super.key,
  });

  final String error;
  final String stackTrace;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Failed to initialize Firebase',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(error, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Text(stackTrace, style: const TextStyle(fontSize: 10)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
