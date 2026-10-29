import 'package:flutter/material.dart';
import '../../core/auth_api.dart';

class ActivarInvitacionPage extends StatefulWidget {
  const ActivarInvitacionPage({
    super.key,
    required this.api,
    this.ownsApi = false,
  });
  final AuthApi api;
  final bool ownsApi;
  @override
  State<ActivarInvitacionPage> createState() => _ActivarInvitacionPageState();
}

class _ActivarInvitacionPageState extends State<ActivarInvitacionPage> {
  final _form = GlobalKey<FormState>();
  final _fields = List.generate(6, (_) => TextEditingController());
  bool _busy = false,
      _done = false,
      _existing = false,
      _professional = false,
      _confirmed = false;
  String? _message;
  @override
  void dispose() {
    for (final c in _fields) {
      c.dispose();
    }
    if (widget.ownsApi) widget.api.close();
    super.dispose();
  }

  Future<void> _activate() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (_existing && !_confirmed) {
      setState(
        () => _message =
            'Confirma que aceptas incorporarte a la clínica de la invitación.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    bool signed = false;
    try {
      if (_existing) {
        await widget.api.login(
          _fields[5].text.trim(),
          _fields[3].text,
          mode: _professional ? 'profesional' : 'paciente',
        );
        signed = true;
        await widget.api.onboarding(
          '/accept',
          body: {
            'token': _fields[0].text.trim(),
            'firstName': _fields[1].text.trim(),
            'firstSurname': _fields[2].text.trim(),
            'confirmed': true,
          },
        );
      } else {
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
      }
      if (mounted) setState(() => _done = true);
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _message = e.message);
    } finally {
      if (signed) {
        try {
          await widget.api.logout();
        } on AuthFailure {
          widget.api.clear();
        }
      }
      if (mounted) {
        _fields[3].clear();
        _fields[4].clear();
        setState(() => _busy = false);
      }
    }
  }

  Widget _field(int i, String label, {int max = 100}) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: _fields[i],
      enabled: !_busy,
      obscureText: i == 0 || i == 3 || i == 4,
      autocorrect: false,
      enableSuggestions: false,
      maxLength: max,
      decoration: InputDecoration(labelText: label),
      validator: (v) {
        if (i == 0)
          return RegExp(r'^[a-f0-9]{64}$').hasMatch((v ?? '').trim())
              ? null
              : 'Pega el código completo.';
        if (i == 3)
          return _existing
              ? (v ?? '').isEmpty
                    ? 'Escribe tu contraseña actual.'
                    : null
              : (v ?? '').runes.length < 12
              ? 'Usa al menos 12 caracteres.'
              : null;
        if (i == 4)
          return v != _fields[3].text
              ? 'Las contraseñas deben coincidir.'
              : null;
        if (i == 5)
          return RegExp(
                r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
              ).hasMatch((v ?? '').trim())
              ? null
              : 'Escribe tu correo registrado.';
        return (v ?? '').trim().isEmpty ? 'Completa este dato.' : null;
      },
    ),
  );
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
                        'Invitación aceptada. Inicia sesión en modo profesional con el correo invitado y tu contraseña. Tu cuenta y sus datos anteriores se conservan.',
                      ),
                      TextButton(
                        onPressed: () =>
                            Navigator.of(context).popUntil((r) => r.isFirst),
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
                          'Pega el código de la invitación que recibiste. Vence a las 48 horas y se utiliza una sola vez. Conocer esta dirección no habilita una cuenta.',
                        ),
                        SwitchListTile(
                          title: const Text('Ya tengo una cuenta en Vitalia'),
                          value: _existing,
                          onChanged: _busy
                              ? null
                              : (v) => setState(() {
                                  _existing = v;
                                  _fields[3].clear();
                                  _fields[4].clear();
                                  _message = null;
                                  _confirmed = false;
                                }),
                        ),
                        _field(0, 'Código de invitación', max: 64),
                        _field(1, 'Primer nombre'),
                        _field(2, 'Primer apellido'),
                        if (_existing) ...[
                          const Text(
                            'Usa el correo invitado y tu contraseña actual. Los nombres solo se utilizarán si todavía no tienes datos personales registrados.',
                          ),
                          _field(5, 'Correo de tu cuenta', max: 254),
                          SwitchListTile(
                            title: const Text(
                              'Ingresar con mi perfil profesional existente',
                            ),
                            subtitle: const Text(
                              'Desactivado: ingresar como paciente.',
                            ),
                            value: _professional,
                            onChanged: _busy
                                ? null
                                : (v) => setState(() => _professional = v),
                          ),
                          _field(3, 'Contraseña actual', max: 1024),
                          CheckboxListTile(
                            title: const Text(
                              'Acepto incorporarme a la clínica indicada en la invitación recibida.',
                            ),
                            value: _confirmed,
                            onChanged: _busy
                                ? null
                                : (v) => setState(() => _confirmed = v == true),
                          ),
                        ] else ...[
                          _field(
                            3,
                            'Contraseña (mínimo 12 caracteres)',
                            max: 1024,
                          ),
                          _field(4, 'Repetir contraseña', max: 1024),
                        ],
                        if (_message != null)
                          Semantics(liveRegion: true, child: Text(_message!)),
                        if (_busy) const LinearProgressIndicator(),
                        FilledButton(
                          onPressed: _busy ? null : _activate,
                          child: Text(
                            _existing
                                ? 'Iniciar sesión y aceptar invitación'
                                : 'Activar mi cuenta',
                          ),
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
