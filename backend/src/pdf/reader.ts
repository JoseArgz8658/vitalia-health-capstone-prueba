import { Worker } from 'node:worker_threads';
import { join } from 'node:path';
export type PdfReadResult = {
  status: 'text_ready' | 'needs_ocr' | 'rejected';
  text: string | null;
  pageCount: number | null;
  incidents: { code: string; page?: number; message: string }[];
};
export const PDF_LIMITS = { bytes: 10 * 1024 * 1024, pages: 10, textBytes: 12000, timeoutMs: 15000 } as const;
export async function readPdfText(input: Uint8Array): Promise<PdfReadResult> {
  const reject = (code: string, message: string): PdfReadResult => ({status:'rejected',text:null,pageCount:null,incidents:[{code,message}]});
  if (!(input instanceof Uint8Array) || input.byteLength === 0 || input.byteLength > PDF_LIMITS.bytes) return reject('invalid_size','PDF vacío o mayor de 10 MiB.');
  if (Buffer.from(input.subarray(0,5)).toString('ascii') !== '%PDF-') return reject('invalid_signature','El contenido no comienza con la firma PDF.');
  return new Promise(resolve => {
    const worker = new Worker(join(__dirname,'reader-worker.js'), {workerData:{data:new Uint8Array(input)},resourceLimits:{maxOldGenerationSizeMb:128}});
    let settled=false;
    const finish=(result:PdfReadResult)=>{
      if(settled) return;
      settled=true;clearTimeout(timer);
      void worker.terminate();resolve(result);
    };
    const timer=setTimeout(()=>finish(reject('read_timeout','La lectura excedió 15 segundos.')),PDF_LIMITS.timeoutMs);
    worker.once('message',finish);
    worker.once('error',()=>finish(reject('reader_error','No se pudo leer el PDF.')));
    worker.once('exit',()=>{if(!settled)finish(reject('reader_error','El lector terminó sin resultado.'));});
  });
}
