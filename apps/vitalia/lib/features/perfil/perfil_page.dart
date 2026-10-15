import 'package:flutter/material.dart';
import '../../core/auth_api.dart';

class PerfilPage extends StatefulWidget {
  const PerfilPage({super.key, required this.api, required this.onExpired});
  final AuthApi api;
  final VoidCallback onExpired;
  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  final _form = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{
    for (final key in ['firstName', 'additionalNames', 'firstSurname', 'secondSurname', 'birthDate', 'phone', 'rut']) key: TextEditingController(),
  };
  bool _busy = false, _loaded = false, _verified = false;
  String? _revision, _commune, _message;
  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { for (final controller in _fields.values) { controller.dispose(); } super.dispose(); }
  void _fill(Map<String, dynamic>? profile) {
    for (final entry in _fields.entries) { entry.value.text = profile?[entry.key] as String? ?? ''; }
    _revision = profile?['revision'] as String?;
    _commune = profile?['preferredCommuneCode'] as String?;
    _verified = profile?['rutVerified'] == true;
  }
  void _error(AuthFailure error) {
    if (error.status == 401) { widget.onExpired(); return; }
    if (mounted) setState(() => _message = error.message);
  }
  Future<void> _load() async {
    setState(() { _busy = true; _loaded = false; _message = null; });
    try {
      final profile = await widget.api.profile();
      if (!mounted) return;
      setState(() { _fill(profile); _loaded = true; });
    } on AuthFailure catch (error) { _error(error); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _save() async {
    if (_busy || !_loaded || !_form.currentState!.validate()) return;
    final body = <String, dynamic>{'revision': _revision, 'preferredCommuneCode': _commune};
    for (final entry in _fields.entries) {
      final text = entry.value.text.trim(); body[entry.key] = text.isEmpty ? null : text;
    }
    setState(() { _busy = true; _message = null; });
    try {
      final profile = await widget.api.profile(update: body);
      if (!mounted) return;
      setState(() { _fill(profile); _message = 'Perfil guardado. Estos datos no verifican tu identidad ni cambian tus permisos.'; });
    } on AuthFailure catch (error) { _error(error); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Widget _field(String key, String label, {bool required = false, String? hint, TextInputType? keyboard}) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: TextFormField(controller: _fields[key], enabled: !_busy && _loaded && !(key == 'rut' && _verified),
      keyboardType: keyboard, maxLength: key == 'phone' ? 40 : key == 'rut' ? 20 : key == 'birthDate' ? 10 : 150,
      decoration: InputDecoration(labelText: label, hintText: hint, counterText: '', border: const OutlineInputBorder()),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (required && text.isEmpty) return 'Completa este dato.';
        if (key == 'birthDate' && text.isNotEmpty && !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) return 'Usa AAAA-MM-DD.';
        return null;
      }),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mi perfil')),
    body: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Icon(Icons.account_circle_outlined, size: 56),
        const SizedBox(height: 12),
        Text('Tus datos personales', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        const Text('Completa tus datos cuando quieras. El teléfono y el RUT son opcionales por ahora. No usamos información de tus exámenes para completar este perfil.'),
        const SizedBox(height: 16),
        if (_busy) const LinearProgressIndicator(),
        if (_message != null) Semantics(liveRegion: true, child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(_message!)))),
        Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: _busy ? null : _load,
          icon: const Icon(Icons.refresh), label: const Text('Actualizar perfil'))),
        if (_loaded) Form(key: _form, child: Column(children: [
          _field('firstName', 'Primer nombre', required: true),
          _field('additionalNames', 'Otros nombres (opcional)'),
          _field('firstSurname', 'Primer apellido', required: true),
          _field('secondSurname', 'Segundo apellido (opcional)'),
          _field('birthDate', 'Fecha de nacimiento (opcional)', hint: 'AAAA-MM-DD', keyboard: TextInputType.datetime),
          _field('phone', 'Teléfono (opcional)', keyboard: TextInputType.phone),
          _field('rut', 'RUT (opcional)', hint: 'Sin puntos o con puntos; incluye dígito verificador'),
          Text(_verified ? 'Identificación verificada: la modificación requiere revisión del equipo.' : 'El dígito verificador comprueba el formato; no acredita tu identidad. Una vez registrado, no se puede vaciar el RUT desde esta pantalla.'),
          const SizedBox(height: 20),
          FilledButton.icon(onPressed: _busy ? null : _save, icon: const Icon(Icons.save_outlined), label: const Text('Guardar perfil')),
        ])),
        const SizedBox(height: 24),
        const Text('La selección de comuna y las medidas personales se habilitarán en próximos incrementos. No se envían datos del perfil al asistente.'),
      ]),
    ))),
  );
}
