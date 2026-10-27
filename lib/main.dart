import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app/app.dart';
import 'firebase_options.dart';
import 'core/utils/app_time.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Enable offline persistence so khosra_entries local queue works offline
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  await AppTime.sync();

  runApp(const App());
}
