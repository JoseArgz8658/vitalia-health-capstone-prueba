import type {Extraction} from '../ai/contract';
import type {Reply} from './contract';
import type {Report} from '../ai/report-fields';
const fields:{key:keyof Report;label:string;pattern:RegExp}[]=[
 {key:'medico_solicitante',label:'Médico solicitante',pattern:/medico solicitante|solicitante|quien solicito|quien pidio/},
 {key:'profesional_validante',label:'Profesional que validó el informe',pattern:/quien valido|profesional validante|validado por|quien firmo/},
 {key:'registro_profesional',label:'Registro profesional del informe',pattern:/registro profesional|cedula profesional|registro sanitario/},
 {key:'fecha_nacimiento',label:'Fecha de nacimiento',pattern:/fecha de nacimiento|cuando naci/},
 {key:'hora_muestra',label:'Hora de toma de muestra',pattern:/hora.{0,25}muestra/},
 {key:'hora_emision',label:'Hora de emisión',pattern:/hora.{0,25}(?:emision|reporte)/},
 {key:'fecha_muestra',label:'Fecha de toma de muestra',pattern:/fecha.{0,25}muestra|cuando.{0,25}muestra/},
 {key:'fecha_emision',label:'Fecha de emisión',pattern:/fecha.{0,25}(?:emision|reporte)|cuando.{0,25}(?:emitio|emision)/},
 {key:'expediente',label:'Expediente',pattern:/expediente/},
 {key:'laboratorio',label:'Laboratorio',pattern:/que laboratorio|cual.{0,15}laboratorio|nombre del laboratorio/},
 {key:'edad',label:'Edad escrita en el informe',pattern:/mi edad|que edad|cual.{0,15}edad|cuantos anos/},
 {key:'sexo',label:'Sexo escrito en el informe',pattern:/mi sexo|que sexo|cual.{0,15}sexo/},
 {key:'observaciones_originales',label:'Observaciones originales del informe',pattern:/observaciones generales|observaciones originales|que dice.{0,20}observacion/},
 {key:'nombre_paciente',label:'Nombre del paciente',pattern:/como me llamo|nombre completo|mi nombre|nombre del paciente|nombre en el examen/},
];
function render(extraction:Extraction,field:typeof fields[number]):Reply{
 const value=extraction.informe?.[field.key]??null;
 return {kind:'education',indices:[],definitions:[],answer:value===null?
  `El campo «${field.label}» no está disponible en la copia revisada de este examen.`:
  `Dato transcrito de la copia revisada — ${field.label}: «${value}».`};
}
export function reportFactReply(question:string,extraction:Extraction):Reply|null{
 const q=question.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
 const field=fields.find(field=>field.pattern.test(q));
 // Las revisiones antiguas mantienen el mensaje de nombre ausente ya registrado.
 if(!field||(!extraction.informe&&field.key==='nombre_paciente'))return null;
 return render(extraction,field);
}
export function isReportFactReply(reply:Reply,extraction:Extraction):boolean{
 return reply.kind==='education'&&!reply.indices.length&&!reply.definitions.length&&fields.some(field=>render(extraction,field).answer===reply.answer);
}
