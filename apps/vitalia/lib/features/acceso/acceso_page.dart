import 'package:flutter/material.dart';
import '../roles/seleccion_roles_page.dart';

/// Maqueta de acceso: valida formato, pero no autentica ni envía credenciales.
class AccesoPage extends StatefulWidget {
  const AccesoPage({super.key});
  @override
  State<AccesoPage> createState() => _AccesoPageState();
}
class _AccesoPageState extends State<AccesoPage> {
  final _form = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  bool _ocultar = true;

  @override
  void dispose() {
    _correo.dispose();
    _clave.dispose();
    super.dispose();
  }

  void _validar() {
    if (!_form.currentState!.validate()) return;
    // No persiste ni transmite los campos. Evita aparentar autenticación.
    _clave.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Formato válido. Inicio de sesión pendiente del backend. '
        'Usa Explorar demostración para revisar las pantallas.')));
  }

  void _aviso(String titulo, String mensaje) {
    showDialog<void>(context: context, builder: (context) => AlertDialog(
      title: Text(titulo), content: Text(mensaje),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(),
        child: const Text('Entendido'))],
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: SizedBox(width: 500, child: Card(child: Padding(
        padding: const EdgeInsets.all(32), child: Form(key: _form,
          child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.health_and_safety_outlined, size: 64,
                color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text('Vitalia Health', textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              const Text('Accede a tus exámenes e historial',
                textAlign: TextAlign.center),
              const SizedBox(height: 24),
              const Text('Prototipo visual: utiliza correo y contraseña ficticios. '
                'No se envían ni almacenan.'),
              const SizedBox(height: 20),
              TextFormField(
                controller: _correo,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico', border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.mail_outline)),
                validator: (valor) {
                  final correo = (valor ?? '').trim();
                  if (correo.isEmpty) return 'Escribe tu correo.';
                  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(correo)) {
                    return 'Escribe un correo con formato válido.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _clave, obscureText: _ocultar,
                enableSuggestions: false, autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Contraseña', border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _ocultar ? 'Mostrar contraseña' : 'Ocultar contraseña',
                    onPressed: () => setState(() => _ocultar = !_ocultar),
                    icon: Icon(_ocultar ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  ),
                ),
                validator: (valor) => (valor ?? '').isEmpty
                  ? 'Escribe una contraseña ficticia.' : null,
                onFieldSubmitted: (_) => _validar(),
              ),
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _aviso('Recuperar acceso',
                    'La recuperación de contraseña todavía no está conectada. '
                    'No se enviará ningún correo en esta demostración.'),
                  child: const Text('Olvidé mi contraseña'),
                )),
              FilledButton(onPressed: _validar,
                child: const Text('Validar formulario de acceso')),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  _correo.clear();
                  _clave.clear();
                  Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => const SeleccionRolesPage()));
                },
                icon: const Icon(Icons.preview_outlined),
                label: const Text('Explorar demostración'),
              ),
              const SizedBox(height: 16),
              const Text('La autenticación y los permisos se integrarán más adelante. '
                'Esta pantalla no crea sesiones.', textAlign: TextAlign.center),
            ],
          ),
        ),
      ))),
    ))),
  );
}
