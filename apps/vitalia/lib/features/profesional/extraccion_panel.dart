import 'package:flutter/material.dart';
import 'profesional_api.dart';

class ExtraccionPanel extends StatelessWidget {
  const ExtraccionPanel({super.key, required this.value});
  final ExtraccionPendiente value;
  String visible(dynamic value) => value == null ? 'No extraído' : value.toString();
  String get status => switch (value.status) {
    'not_requested' => 'Procesamiento no solicitado',
    'queued' => 'Procesamiento pendiente',
    'processing' => 'Documento en procesamiento',
    'requires_review' => 'Extracción pendiente de revisión profesional',
    'rejected' => 'Documento rechazado para extracción',
    _ => 'El procesamiento no se pudo completar',
  };
  @override
  Widget build(BuildContext context) {
    final extraction = value.extraction;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(status, style: Theme.of(context).textTheme.titleMedium),
      const Text('Información sin aprobación. Compara cada dato con el documento original. Esta pantalla todavía no permite corregir ni aprobar.'),
      const SizedBox(height: 12),
      if (extraction != null) ...[
        SelectableText('Examen: ${visible(extraction['examen'])}'),
        SelectableText('Fecha extraída: ${visible(extraction['fecha'])}'),
        ...((extraction['resultados'] as List?) ?? []).map((item) {
          final row = item as Map<String, dynamic>;
          return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              SelectableText(visible(row['nombre'])),
              SelectableText('Valor: ${visible(row['valor'])}'),
              SelectableText('Unidad: ${visible(row['unidad'])}'),
              SelectableText('Referencia: ${visible(row['rango_referencia'])}'),
            ])));
        }),
      ],
      const SizedBox(height: 12),
      const Text('Incidencias de lectura y extracción'),
      if (value.incidents.isEmpty) const Text('Sin incidencias registradas. Esto no garantiza exactitud.'),
      ...value.incidents.map((issue) => SelectableText(issue)),
      if (value.sourceText != null) ...[
        const SizedBox(height: 12),
        const Text('Texto usado para la extracción'),
        const Text('Puede contener errores de lectura u OCR; el archivo original es la referencia.'),
        SelectableText(value.sourceText!),
      ],
    ]);
  }
}
