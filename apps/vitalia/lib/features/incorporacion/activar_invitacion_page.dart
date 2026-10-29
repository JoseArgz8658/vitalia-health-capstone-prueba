import 'package:flutter/material.dart';
import '../../core/auth_api.dart';

class ActivarInvitacionPage extends StatefulWidget {
  const ActivarInvitacionPage({super.key, required this.api});
  final AuthApi api;
  @override
  State<ActivarInvitacionPage> createState() => _ActivarInvitacionPageState();
}

class _ActivarInvitacionPageState extends State<ActivarInvitacionPage> {
  final _form = GlobalKey<FormState>();
  final _fields = List.generate(5, (_) => TextEditingController());
  bool _busy = false, _done = false;
  String? _message;
  @override
  void dispose() {
    for (final c in _fields) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _activate() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.api.onboarding(
        '/activate',
        body: {
          'token': _fields[0].text.trim(),
          'firstName': _fields[1].text.trim(),
          'firstSurname': _fields[2].text.trim(),
          'password': _fields[3].text,
          'confirmation': _fields[4].text,
        },
      );
      if (mounted) setState(() => _done = true);
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _message = e.message);
    } finally {
      _fields[3].clear();
      _fields[4].clear();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Activar invitación profesional')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: _done
                ? Column(
                    children: [
                      const Text(
                        'Cuenta activada. Inicia sesión con el correo de la invitación y tu nueva contraseña.',
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Volver al inicio de sesión'),
                      ),
                    ],
                  )
                : Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Pega el código recibido por privado. La invitación dura 48 horas y se utiliza una sola vez. Tu contraseña la defines tú.',
                        ),
                        const SizedBox(height: 16),
                        ...List.generate(
                          5,
                          (i) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: TextFormField(
                              controller: _fields[i],
                              enabled: !_busy,
                              obscureText: i >= 3 || i == 0,
                              autocorrect: false,
                              enableSuggestions: false,
                              maxLength: i == 0
                                  ? 64
                                  : i >= 3
                                  ? 1024
                                  : 100,
                              decoration: InputDecoration(
                                labelText: [
                                  'Código de invitación',
                                  'Primer nombre',
                                  'Primer apellido',
                                  'Contraseña (mínimo 12 caracteres)',
                                  'Repetir contraseña',
                                ][i],
                              ),
                              validator: (v) {
                                if (i == 0)
                                  return RegExp(
                                        r'^[a-f0-9]{64}$',
                                      ).hasMatch((v ?? '').trim())
                                      ? null
                                      : 'Pega el código completo.';
                                if (i < 3)
                                  return (v ?? '').trim().isEmpty
                                      ? 'Completa este dato.'
                                      : null;
                                if (i == 3)
                                  return (v ?? '').runes.length < 12
                                      ? 'Usa al menos 12 caracteres.'
                                      : null;
                                return v != _fields[3].text
                                    ? 'Las contraseñas deben coincidir.'
                                    : null;
                              },
                            ),
                          ),
                        ),
                        if (_message != null) Text(_message!),
                        if (_busy) const LinearProgressIndicator(),
                        FilledButton(
                          onPressed: _busy ? null : _activate,
                          child: const Text('Activar mi cuenta'),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    ),
  );
}
