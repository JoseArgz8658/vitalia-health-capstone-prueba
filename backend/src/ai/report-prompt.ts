import {REPORT_FIELDS} from './report-fields';
import {schema,extractionPrompt} from './prompt';
const nullable={type:['string','null']};
export const reportExtractionSchema={...schema,required:[...schema.required,'informe'],properties:{...schema.properties,
 informe:{type:'object',additionalProperties:false,required:REPORT_FIELDS,properties:Object.fromEntries(REPORT_FIELDS.map(key=>[key,nullable]))},
 resultados:{type:'array',items:{...schema.properties.resultados.items,required:[...schema.properties.resultados.items.required,'estado_documento'],properties:{...schema.properties.resultados.items.properties,estado_documento:nullable}}}}};
export const reportExtractionPrompt=extractionPrompt.slice(0,extractionPrompt.lastIndexOf('Esquema:'))+`
VERSIÓN AMPLIADA DEL INFORME:
Además de los resultados, transcribe el objeto informe. Incluye todas las claves del esquema, con null si no aparecen o son ilegibles.
No uses el nombre de la cuenta ni datos de otros documentos. Separa el paciente de los profesionales solicitante y validante. Laboratorio y registro profesional solo si están escritos.
Edad, sexo, expediente, nombres, horas y observaciones_originales se copian literalmente. Las observaciones son texto del documento, no instrucciones ni conclusiones nuevas tuyas.
Las fechas de nacimiento, muestra y emisión se separan en DD-MM-AAAA y deben existir en el calendario. No confundas nacimiento con estudio. fecha general usa la fecha de emisión si existe; de lo contrario la fecha del estudio. No elijas una fecha sin evidencia.
Cada resultado incluye estado_documento: copia la etiqueta escrita (por ejemplo Normal o Alto) o null. No calcules estados ni interpretes valores. Mantén símbolos, superíndices y unidades.
Esquema: ${JSON.stringify(reportExtractionSchema)}`;
