import 'package:flutter/foundation.dart';
import 'package:file_selector/file_selector.dart';
import '../../core/auth_api.dart';
import 'documento.dart';

bool get descargaDisponible => kIsWeb ||
  [TargetPlatform.windows, TargetPlatform.macOS, TargetPlatform.linux].contains(defaultTargetPlatform);

Future<bool> guardarDocumento(Documento item, Uint8List bytes) async {
  final file = XFile.fromData(bytes, name: item.archivo, mimeType: item.mime);
  if (kIsWeb) {
    await file.saveTo(item.archivo);
    return true;
  }
  if (!descargaDisponible) {
    throw const AuthFailure('La descarga aún no está disponible en este dispositivo.');
  }
  final location = await getSaveLocation(suggestedName: item.archivo);
  if (location == null) return false;
  await file.saveTo(location.path);
  return true;
}
