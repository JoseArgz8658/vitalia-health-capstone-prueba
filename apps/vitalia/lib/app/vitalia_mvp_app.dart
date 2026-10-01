import 'package:flutter/material.dart';
import '../core/tema_vitalia.dart';
import '../features/acceso/acceso_page.dart';

/// Arranque del MVP: no registra rutas protegidas hasta autenticar desde backend.
class VitaliaMvpApp extends StatelessWidget {
  const VitaliaMvpApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Vitalia Health',
    debugShowCheckedModeBanner: false,
    theme: temaVitalia(),
    home: const AccesoPage(),
  );
}
