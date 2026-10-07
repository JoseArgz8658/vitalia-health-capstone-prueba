import {isCalendarDate,type Extraction} from '../ai/contract';
import type {Reply} from './contract';
// El esquema conserva una fecha, sin distinguir el evento.
export function reviewedDateReply(extraction:Extraction):Reply|null{
 if(!extraction.fecha||!isCalendarDate(extraction.fecha))return null;
 return {kind:'education',answer:`La fecha registrada en la copia revisada de este examen es ${extraction.fecha}.`,indices:[],definitions:[]};
}
export function isReviewedDateReply(reply:Reply,extraction:Extraction):boolean{
 const expected=reviewedDateReply(extraction);
 return expected!==null&&reply.kind==='education'&&reply.answer===expected.answer&&reply.indices.length===0&&reply.definitions.length===0;
}
