const {REPORT_FIELDS}=require('../dist/ai/report-fields');
const {extractionSchema,reviewExtraction}=require('../dist/ai/contract');
const {createLocalExtractor}=require('../dist/ai/local-extractor');
const {createExamAssistant}=require('../dist/exam-assistant/local-model');
const {gate,validateReply}=require('../dist/exam-assistant/contract');
const informe=()=>({...Object.fromEntries(REPORT_FIELDS.map(key=>[key,null])),nombre_paciente:'Paciente de prueba',medico_solicitante:'Profesional de prueba',fecha_muestra:'05-10-2026',fecha_emision:'06-10-2026'});
const extraction=()=>({examen:'Panel de prueba',fecha:'06-10-2026',informe:informe(),resultados:[{nombre:'Hemoglobina',valor:'15,2',unidad:'g/dL',rango_referencia:'13,5–17,5',estado_documento:'Normal'}]});
test('esquema ampliado conserva datos, estado literal y compatibilidad',()=>{
 const value=extraction();expect(extractionSchema.parse(value)).toEqual(value);
 const legacy={examen:value.examen,fecha:value.fecha,resultados:[{nombre:'Hemoglobina',valor:'15,2',unidad:'g/dL',rango_referencia:null}]};
 expect(extractionSchema.parse(legacy)).toEqual(legacy);expect(reviewExtraction(JSON.stringify(legacy),true).status).toBe('rejected');
 expect(reviewExtraction(JSON.stringify({...value,informe:{...value.informe,fecha_muestra:'31-11-2026'}})).incidents).toContainEqual(expect.objectContaining({code:'invalid_date',path:'informe.fecha_muestra'}));
 expect(()=>extractionSchema.parse({...value,informe:{...value.informe,token:'inventado'}})).toThrow();
});
test('extracción v4 separa datos generales y resultados, conservando contrato',async()=>{
 const fetchImpl=jest.fn(async(_url,options)=>{
  const body=JSON.parse(options.body),value=extraction();
  const content=body.format.required.includes('informe') ? {examen:value.examen,fecha:value.fecha,informe:value.informe} : {resultados:value.resultados};
  if(body.format.required.includes('informe'))expect(body.format.properties.informe.required).toEqual(REPORT_FIELDS);
  return new Response(JSON.stringify({done:true,message:{content:JSON.stringify(content)}}));
 });
 const result=await createLocalExtractor({fetchImpl,promptVersion:4})('Texto ficticio');
 expect(fetchImpl).toHaveBeenCalledTimes(2);
 expect(result.promptVersion).toBe(4);expect(result.extraction.informe.nombre_paciente).toBe('Paciente de prueba');expect(result.approved).toBe(false);
});
test.each([['¿Cuál es el nombre completo?','Paciente de prueba'],['¿Quién solicitó el examen?','Profesional de prueba'],['¿Cuál es la fecha de toma de muestra?','05-10-2026'],['¿Cuál es la fecha de emisión?','06-10-2026']])('dato confirmado del informe: %s',async(question,expected)=>{
 const fetchImpl=jest.fn(),value=extraction();const result=await createExamAssistant({fetchImpl})({extraction:value,question,mode:'chat',history:[]});
 expect(result.reply.answer).toContain(expected);expect(fetchImpl).not.toHaveBeenCalled();expect(validateReply(result.reply,value,'chat')).toEqual(result.reply);
 expect(()=>validateReply({...result.reply,answer:result.reply.answer+' Toma hierro.'},value,'chat')).toThrow();
});
test('referencia y estado son transcripción, no clasificación calculada',()=>{
 const value=extraction();
 expect(gate('¿Cuál es el estado de Hemoglobina?',value,[]).answer).toContain('estado escrito en el informe');
 expect(gate('¿Cuál es el rango de referencia de Hemoglobina?',value,[]).answer).toContain('13,5–17,5');
 expect(gate('¿Qué significa rango de referencia?',value,[])).toBeNull();
});
test('explicación larga usa bloques de tres, remapea filas y excluye datos personales del modelo',async()=>{
 const value=extraction();value.resultados=Array.from({length:7},(_,i)=>({nombre:`Sustancia ${i}`,valor:null,unidad:null,rango_referencia:null}));
 const seen=[];const fetchImpl=jest.fn(async(_url,options)=>{
  const body=JSON.parse(options.body),input=JSON.parse(body.messages[1].content);expect(input.review.informe).toBeUndefined();expect(JSON.stringify(body)).not.toContain('Paciente de prueba');
  seen.push(input.review.resultados.map(row=>row.nombre));const definitions=input.review.resultados.map((row,index)=>({index,text:'Componente descrito de forma educativa.',known:true}));
  return new Response(JSON.stringify({done:true,message:{content:JSON.stringify({kind:'education',answer:'Conceptos del examen.',indices:definitions.map(item=>item.index),definitions})}}));
 });
 const result=await createExamAssistant({fetchImpl})({extraction:value,question:'Explica los conceptos.',mode:'explanation',history:[]});
 expect(seen.map(part=>part.length)).toEqual([3,3,1]);expect(result.reply.definitions.map(item=>item.index)).toEqual([0,1,2,3,4,5,6]);expect(result.generationAttempts).toBe(3);
});
test('un bloque fallido impide entregar una explicación parcial',async()=>{
 const value=extraction();value.resultados=Array.from({length:5},(_,i)=>({nombre:`Sustancia ${i}`,valor:null,unidad:null,rango_referencia:null}));
 let calls=0;const fetchImpl=async(_url,options)=>{
  if(++calls===2)return new Response('{}',{status:500});const input=JSON.parse(JSON.parse(options.body).messages[1].content);
  const definitions=input.review.resultados.map((_,index)=>({index,text:'Componente del examen.',known:true}));
  return new Response(JSON.stringify({done:true,message:{content:JSON.stringify({kind:'education',answer:'Conceptos.',indices:definitions.map(item=>item.index),definitions})}}));
 };
 await expect(createExamAssistant({fetchImpl})({extraction:value,question:'Explica.',mode:'explanation',history:[]})).rejects.toMatchObject({reason:'http'});expect(calls).toBe(2);
});
test('todos los bloques comparten dos minutos, sin reiniciar el reloj',async()=>{
 jest.useFakeTimers();
 try {
  const value=extraction();value.resultados=Array.from({length:5},(_,i)=>({nombre:`Sustancia ${i}`,valor:null,unidad:null,rango_referencia:null}));
  let calls=0;const fetchImpl=jest.fn(async(_url,options)=>{
   const call=++calls;
   await new Promise((resolve,reject)=>{
    const timer=setTimeout(resolve,call===1?70000:60000);
    options.signal.addEventListener('abort',()=>{clearTimeout(timer);reject(new Error('abort'));},{once:true});
   });
   const input=JSON.parse(JSON.parse(options.body).messages[1].content);
   const definitions=input.review.resultados.map((_,index)=>({index,text:'Componente del examen.',known:true}));
   return new Response(JSON.stringify({done:true,message:{content:JSON.stringify({kind:'education',answer:'Conceptos.',indices:definitions.map(item=>item.index),definitions})}}));
  });
  const promise=createExamAssistant({fetchImpl})({extraction:value,question:'Explica.',mode:'explanation',history:[]});
  const rejected=expect(promise).rejects.toMatchObject({reason:'timeout'});
  await jest.advanceTimersByTimeAsync(70000);await jest.advanceTimersByTimeAsync(50000);await rejected;
  expect(calls).toBe(2);
 } finally {jest.useRealTimers();}
});
test('diagnóstico de extracción distingue fallos sin registrar el documento',async()=>{
 const {createLocalExtractor}=require('../dist/ai/local-extractor');
 const warn=jest.spyOn(console,'warn').mockImplementation(()=>{});
 try {
  for(const [response,reason] of [[new Response('secreto',{status:503}),'http'],[new Response('no json'),'invalid_json'],[new Response(JSON.stringify({done:false,message:{content:'privado'}})),'incomplete']]){
   await expect(createLocalExtractor({promptVersion:4,fetchImpl:async()=>response})('NOMBRE CONFIDENCIAL')).rejects.toMatchObject({reason});
   const log=JSON.parse(warn.mock.calls.at(-1)[0]);
   expect(Object.keys(log).sort()).toEqual(['elapsedMs','event','promptVersion','reason']);
   expect(log.reason).toBe(reason);expect(JSON.stringify(log)).not.toContain('CONFIDENCIAL');
  }
 } finally {warn.mockRestore();}
});
