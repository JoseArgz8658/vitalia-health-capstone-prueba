import 'dart:async';
import 'revision_panel.dart';
import 'package:flutter/material.dart';
import '../../core/auth_api.dart';
import '../documentos_reales/documento.dart';
import '../documentos_reales/guardar_documento.dart';
import 'profesional_api.dart';
import 'extraccion_panel.dart';

class ProfesionalDocumentosPage extends StatefulWidget {
  const ProfesionalDocumentosPage({super.key, required this.auth, required this.patientId,
    required this.patientEmail, required this.onExpired, required this.onBack,
    required this.onLogout, this.sessionBusy = false});
  final AuthApi auth;
  final String patientId;
  final String patientEmail;
  final VoidCallback onExpired;
  final VoidCallback onBack;
  final VoidCallback onLogout;
  final bool sessionBusy;
  @override
  State<ProfesionalDocumentosPage> createState() => _ProfesionalDocumentosPageState();
}
class _ProfesionalDocumentosPageState extends State<ProfesionalDocumentosPage> {
  Timer? _pollTimer;
  int _pollCount = 0;
  void _stopPolling() { _pollTimer?.cancel(); _pollTimer = null; }
  void _startPolling() {
    _stopPolling();
    _pollCount = 0;
    if (_detail?.status != 'queued' && _detail?.status != 'processing') return;
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || ++_pollCount > 120) { _stopPolling(); return; }
      if (!_blocked) _refreshExtraction();
    });
  }
  @override
  void dispose() { _stopPolling(); super.dispose(); }
  List<Documento> _items = [];
  ExtraccionPendiente? _detail;
  String? _detailName;
  String? _detailId;
  bool _reviewSaving = false;
  bool get _blocked => _busy || _reviewSaving;
  String? _error;
  bool _busy = false;
  int _offset = 0;
  ProfesionalApi get _api => ProfesionalApi(widget.auth);
  @override
  void initState() { super.initState(); _load(0); }
  void _failure(AuthFailure error) {
    if (!mounted) return;
    _stopPolling();
    if (error.status == 401) { widget.onExpired(); return; }
    setState(() {
      _error = error.message; _reviewSaving = false;
      _detail = null;
      _detailName = null; _detailId = null;
      if (error.status == 403 || error.status == 404) _items = [];
    });
  }
  Future<void> _load(int offset) async {
    if (_blocked) return;
    _stopPolling();
    setState(() { _busy = true; _error = null; _items = []; _detail = null; _detailName = null; _detailId = null; });
    try {
      final items = await _api.listar(widget.patientId, offset: offset);
      if (mounted) setState(() { _items = items; _offset = offset; });
    } on AuthFailure catch (error) { _failure(error); }
    catch (_) { if (mounted) setState(() => _error = 'No se pudo cargar el historial.'); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _consult(Documento item) async {
    if (_blocked) return;
    _stopPolling();
    setState(() { _busy = true; _error = null; _detail = null; _detailName = null; _detailId = null; });
    try {
      final detail = await _api.consultar(widget.patientId, item.id);
      if (mounted) setState(() { _detail = detail; _detailName = item.nombre; _detailId = item.id; });
      if (mounted) _startPolling();
    } on AuthFailure catch (error) { _failure(error); }
    catch (_) { if (mounted) setState(() => _error = 'No se pudo consultar la extracción.'); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _refreshExtraction() async {
    final id = _detailId;
    if (_blocked || id == null) return;
    setState(() { _busy = true; _error = null; });
    try {
      final detail = await _api.consultar(widget.patientId, id);
      if (mounted && _detailId == id) {
        setState(() => _detail = detail);
        if (detail.status != 'queued' && detail.status != 'processing') _stopPolling();
        else if (_pollTimer == null) _startPolling();
      }
    } on AuthFailure catch (error) { _failure(error); }
    catch (_) { if (mounted) setState(() => _error = 'No se pudo actualizar la extracción.'); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _download(Documento item) async {
    if (_blocked) return;
    setState(() { _busy = true; _error = null; });
    try {
      final bytes = await _api.descargar(widget.patientId, item);
      if (!mounted || !widget.auth.hasSession) return;
      final saved = await guardarDocumento(item, bytes);
      if (mounted && saved) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Descarga solicitada. Revisa el archivo original.')));
    } on AuthFailure catch (error) { _failure(error); }
    catch (_) { if (mounted) setState(() => _error = 'No se pudo guardar el archivo.'); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Exámenes del paciente'),
      leading: IconButton(onPressed: _blocked ? null : widget.onBack,
        icon: const Icon(Icons.arrow_back), tooltip: 'Volver a mis pacientes'),
      actions: [TextButton(onPressed: _blocked || widget.sessionBusy ? null : widget.onLogout,
        child: const Text('Cerrar sesión'))]),
    body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(24),
      child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Paciente', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(widget.patientEmail, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          const Text('Consulta el archivo original y compara la extracción antes de registrar tu revisión.'),
          const SizedBox(height: 16),
          TextButton(onPressed: _blocked ? null : () => _load(_offset), child: const Text('Actualizar historial')),
          if (_busy) const Center(child: CircularProgressIndicator()),
          if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          if (!_busy && _items.isEmpty && _error == null) const Text('No hay exámenes en esta página.'),
          ..._items.map((item) => Card(
            margin: const EdgeInsets.only(bottom: 16), elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.nombre, style: Theme.of(context).textTheme.titleMedium),
              Text('${item.tipo} · ${item.fechaVisible}'),
              const SizedBox(height: 8),
              Text(item.archivo),
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: [
                OutlinedButton(onPressed: _blocked || !descargaDisponible ? null : () => _download(item),
                  child: const Text('Descargar original')),
                TextButton(onPressed: _blocked ? null : () => _consult(item),
                  child: const Text('Consultar extracción')),
              ]),
            ])))),
          Wrap(spacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('Página ${_offset ~/ 20 + 1}'),
            TextButton(onPressed: _blocked || _offset == 0 ? null : () => _load(_offset - 20), child: const Text('Anterior')),
            TextButton(onPressed: _blocked || _items.length < 20 || _offset >= 10000 ? null : () => _load(_offset + 20), child: const Text('Siguiente')),
          ]),
          if (_detail != null) Card(child: Padding(padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(_detailName ?? '', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextButton(onPressed: _blocked ? null : () { _stopPolling(); setState(() { _detail = null; _detailName = null; _detailId = null; }); },
                child: const Text('Cerrar consulta')),
              TextButton(onPressed: _blocked ? null : _refreshExtraction,
                child: const Text('Actualizar extracción')),
              const Divider(),
              const SizedBox(height: 16),
              ExtraccionPanel(value: _detail!),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              if (_detailId != null) RevisionPanel(key: ValueKey('review-$_detailId-${_detail!.status}'),
                auth: widget.auth, patientId: widget.patientId, documentId: _detailId!,
                processingStatus: _detail!.status, onFailure: _failure,
                onSaving: (saving) { if (mounted) setState(() => _reviewSaving = saving); }),
            ]))),
        ]),
      )),
    )),
  );
}
