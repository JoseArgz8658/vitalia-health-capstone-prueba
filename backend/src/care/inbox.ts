import {randomUUID} from 'node:crypto';
import {isDeepStrictEqual} from 'node:util';
import {extractionSchema,type Extraction} from '../ai/contract';
import {processingResultSchema} from '../processing/result';
import {reviewedExtractionValid} from '../reviews/validation';
import {type Pool} from 'pg';
import {z} from 'zod';
import {type AccountSummary} from '../accounts/repository';
import {type DocumentDatabase,type DocumentStorage} from '../documents/service';
import {identifyDocument,MAX_FILE_BYTES} from '../documents/file-validation';
type DB=Pick<Pool,'query'>;
export class CareInboxError extends Error {
 constructor(public readonly status:number,public readonly code:string){super(code);}
}
const joins=`FROM public.vitalia_exam_care c
 JOIN public.vitalia_documents d ON d.id=c.document_id AND d.patient_id=c.patient_id AND d.status='stored' AND d.care_flow
 JOIN public.vitalia_clinic_memberships m ON m.id=c.responsible_membership_id AND m.clinic_id=c.clinic_id AND m.active
 JOIN public.vitalia_people p ON p.id=m.professional_person_id
 JOIN public.vitalia_account_roles g ON g.account_id=p.account_id AND g.role_code='profesional' AND g.active
 JOIN public.vitalia_professional_profiles f ON f.person_id=p.id AND f.verification_status='verified'
 JOIN public.vitalia_credential_audit a ON a.request_id=f.verification_request_id AND a.person_id=p.id AND a.decision='verified'
 JOIN public.vitalia_clinics cl ON cl.id=c.clinic_id AND cl.active
 JOIN public.vitalia_branches b ON b.id=c.branch_id AND b.clinic_id=c.clinic_id AND b.active
 JOIN public.vitalia_branch_memberships bm ON bm.membership_id=m.id AND bm.branch_id=b.id AND bm.clinic_id=cl.id
 JOIN public.vitalia_specialties s ON s.id=c.specialty_id AND s.active
 JOIN public.vitalia_membership_specialties ms ON ms.membership_id=m.id AND ms.specialty_id=s.id AND ms.clinic_id=cl.id
 JOIN public.vitalia_people patient ON patient.account_id=c.patient_id
 JOIN public.vitalia_care_contacts contact ON contact.document_id=d.id AND contact.patient_id=c.patient_id`;
const scope=`p.account_id=$1 AND c.status IN ('requested','active','completed')
 AND f.registration_reference=a.after_state->>'registrationReference'
 AND f.verification_revision::text=a.after_state->>'revision'
 AND f.verification_decided_by=a.actor_id AND f.verification_decided_at=a.created_at`;
const columns=`c.id,c.status,c.revision,c.document_id,c.patient_id,c.responsible_membership_id,c.specialty_id,c.branch_id,
 cl.name AS clinic_name,b.name AS branch_name,s.name AS specialty_name,
 concat_ws(' ',patient.first_name,patient.additional_names,patient.first_surname,patient.second_surname) AS patient_name,
 d.exam_name,d.exam_type,d.exam_date::text,d.original_name,d.content_type,d.size_bytes,d.storage_key`;
interface Row {
 id:string;status:string;revision:number;document_id:string;patient_id:string;responsible_membership_id:string;specialty_id:string;branch_id:string;
 clinic_name:string;branch_name:string;specialty_name:string;patient_name:string;
 exam_name:string;exam_type:string;exam_date:string;original_name:string;content_type:string;size_bytes:number;storage_key:string;
 phone:string;email:string;street:string;address_number:string;residence_commune:string;consultation_commune:string;confirmed_at:Date;
}
function professional(a:AccountSummary){if(a.role!=='profesional')throw new CareInboxError(403,'FORBIDDEN');}
function summary(r:Row){return {id:r.id,status:r.status,revision:r.revision,clinicName:r.clinic_name,branchName:r.branch_name,
 specialtyName:r.specialty_name,patientName:r.patient_name,document:{id:r.document_id,examName:r.exam_name,examType:r.exam_type,
 examDate:r.exam_date,originalName:r.original_name,contentType:r.content_type,sizeBytes:r.size_bytes}};}
function translate(e:unknown):never{
 if(e instanceof CareInboxError)throw e;
 const code=(e as {code?:string})?.code;
 if(['42P01','42703','42501'].includes(code??''))throw new CareInboxError(503,'CARE_INBOX_UNAVAILABLE');
 if(code==='P0001')throw new CareInboxError(404,'CARE_NOT_FOUND');
 if(['40001','40P01'].includes(code??''))throw new CareInboxError(409,'CARE_CHANGED');
 throw e;
}
async function load(tx:DB,a:AccountSummary,id:string,update=false){
 const result=await tx.query<Row>(`SELECT ${columns},contact.phone,contact.email,contact.street,contact.address_number,
 residence.name AS residence_commune,zone.name AS consultation_commune,contact.created_at AS confirmed_at
 ${joins} JOIN public.vitalia_communes residence ON residence.code=contact.residence_commune_code
 JOIN public.vitalia_communes zone ON zone.code=contact.consultation_commune_code
 WHERE ${scope} AND c.id=$2 ${update?'FOR UPDATE OF c':'FOR SHARE OF c'} FOR SHARE OF d`,[a.id,id]);
 const row=result.rows[0];if(!row)throw new CareInboxError(404,'CARE_NOT_FOUND');
 // Mantener elegibilidad y relaciones bloqueadas mientras se expone contenido o se inicia la atención.
 await tx.query('SELECT public.vitalia_lock_care_selection($1,$2,$3)',[row.responsible_membership_id,row.specialty_id,row.branch_id]);
 return row;
}
async function audit(tx:DB,a:AccountSummary,action:'list'|'view'|'download'|'view_review',id:string|null){
 await tx.query('INSERT INTO public.vitalia_care_access_audit(care_id,actor_id,action) VALUES($1,$2,$3)',[id,a.id,action]);
}
interface CareReview {id:string;processing_id:string;reviewer_id:string;reviewer_email:string;reviewed_extraction:Extraction;observations:string;created_at:Date}
async function savedReview(tx:DB,id:string){
 return (await tx.query<CareReview>(`SELECT r.id,r.processing_id,r.reviewer_id,a.email AS reviewer_email,
  r.reviewed_extraction,r.observations,r.created_at FROM public.vitalia_care_reviews r
  JOIN public.vitalia_accounts a ON a.id=r.reviewer_id WHERE r.care_id=$1`,[id])).rows[0]??null;
}
function reviewSummary(r:CareReview){return {id:r.id,processingId:r.processing_id,reviewerId:r.reviewer_id,
 reviewerEmail:r.reviewer_email,extraction:extractionSchema.parse(r.reviewed_extraction),observations:r.observations,reviewedAt:r.created_at,approved:true};}
const careReviewInput=z.object({processingId:z.uuid(),extraction:extractionSchema,observations:z.string().trim().max(2000),
 confirmedOriginal:z.literal(true),expectedRevision:z.number().int().min(0).max(2147483646)}).strict();
export function createCareInboxService(db:DocumentDatabase,storage:Pick<DocumentStorage,'read'>){return {
 async list(a:AccountSummary,input:unknown){professional(a);
  const schema=z.object({offset:z.string().regex(/^(0|[1-9]\d*)$/).transform(Number).pipe(z.number().int().max(100000)).optional().default(0)}).strict();
  const parsed=schema.safeParse(input);if(!parsed.success)throw new CareInboxError(400,'INVALID_CARE_INPUT');
  try{return await db.transaction(async tx=>{
   const rows=(await tx.query<Row>(`SELECT ${columns} ${joins} WHERE ${scope}
    ORDER BY c.created_at DESC,c.id DESC LIMIT 21 OFFSET $2`,[a.id,parsed.data.offset])).rows;
   await audit(tx,a,'list',null);
   return {items:rows.slice(0,20).map(summary),nextOffset:rows.length>20?parsed.data.offset+20:null};
  });}catch(e){translate(e);}
 },
 async details(a:AccountSummary,id:string){professional(a);if(!z.uuid().safeParse(id).success)throw new CareInboxError(404,'CARE_NOT_FOUND');
  try{return await db.transaction(async tx=>{
   const r=await load(tx,a,id);await audit(tx,a,'view',id);
   return {care:summary(r),contact:{phone:r.phone,email:r.email,street:r.street,addressNumber:r.address_number,
    residenceCommune:r.residence_commune,consultationCommune:r.consultation_commune,confirmedAt:r.confirmed_at}};
  });}catch(e){translate(e);}
 },
 async begin(a:AccountSummary,id:string,input:unknown){professional(a);if(!z.uuid().safeParse(id).success)throw new CareInboxError(404,'CARE_NOT_FOUND');
  const parsed=z.object({expectedRevision:z.number().int().min(0).max(2147483646)}).strict().safeParse(input);
  if(!parsed.success)throw new CareInboxError(400,'INVALID_CARE_INPUT');
  try{return await db.transaction(async tx=>{
   const r=await load(tx,a,id,true),expected=parsed.data.expectedRevision;
   if(r.status==='active'&&r.revision===expected+1)return {started:true,replayed:true};
   if(r.status!=='requested'||r.revision!==expected)throw new CareInboxError(409,'CARE_CHANGED');
   await tx.query(`UPDATE public.vitalia_exam_care SET status='active',updated_by=$2,revision=revision+1 WHERE id=$1`,[id,a.id]);
   return {started:true,replayed:false};
  });}catch(e){translate(e);}
 },
 async review(a:AccountSummary,id:string){professional(a);if(!z.uuid().safeParse(id).success)throw new CareInboxError(404,'CARE_NOT_FOUND');
  try{return await db.transaction(async tx=>{
   const r=await load(tx,a,id),review=await savedReview(tx,id);
   const job=(await tx.query<{id:string;status:string;result:unknown}>(
    'SELECT id,status,result FROM public.vitalia_document_processing WHERE document_id=$1',[r.document_id])).rows[0];
   const value=job?.result==null?null:processingResultSchema.parse(job.result),original=value?.ai?.extraction??null;
   await audit(tx,a,'view_review',id);
   return {processingId:job?.id??null,processingStatus:job?.status??'not_requested',expectedRevision:r.revision,
    originalExtraction:original,sourceText:value?.inputText??null,
    canReview:r.status==='active'&&job?.status==='requires_review'&&original!==null&&!review,
    review:review?reviewSummary(review):null};
  });}catch(e){translate(e);}
 },
 async approve(a:AccountSummary,id:string,input:unknown){professional(a);if(!z.uuid().safeParse(id).success)throw new CareInboxError(404,'CARE_NOT_FOUND');
  const parsed=careReviewInput.safeParse(input);
  if(!parsed.success||Buffer.byteLength(JSON.stringify(parsed.data),'utf8')>24*1024)throw new CareInboxError(400,'INVALID_CARE_REVIEW');
  const v=parsed.data;
  try{return await db.transaction(async tx=>{
   const r=await load(tx,a,id,true),existing=await savedReview(tx,id);
   if(existing){
    if(r.status==='completed'&&r.revision===v.expectedRevision+1&&existing.processing_id===v.processingId&&
      existing.reviewer_id===a.id&&existing.observations===v.observations&&isDeepStrictEqual(existing.reviewed_extraction,v.extraction))return reviewSummary(existing);
    throw new CareInboxError(409,'CARE_CHANGED');
   }
   if(r.status!=='active'||r.revision!==v.expectedRevision)throw new CareInboxError(409,'CARE_CHANGED');
   await tx.query('SELECT public.vitalia_lock_review_processing($1,$2)',[v.processingId,r.document_id]);
   const job=(await tx.query<{id:string;status:string;result:unknown}>(
    'SELECT id,status,result FROM public.vitalia_document_processing WHERE document_id=$1',[r.document_id])).rows[0];
   if(!job||job.id!==v.processingId||job.status!=='requires_review')throw new CareInboxError(409,'CARE_CHANGED');
   const original=processingResultSchema.parse(job.result).ai?.extraction;
   if(!original)throw new CareInboxError(409,'CARE_CHANGED');
   if(!reviewedExtractionValid(v.extraction,original,v.observations))throw new CareInboxError(400,'INVALID_CARE_REVIEW');
   await tx.query(`INSERT INTO public.vitalia_care_reviews(id,care_id,document_id,patient_id,processing_id,reviewer_membership_id,
    reviewer_id,original_extraction,reviewed_extraction,observations,confirmed_original)
    VALUES($1,$2,$3,$4,$5,$6,$7,$8::jsonb,$9::jsonb,$10,true)`,
    [randomUUID(),id,r.document_id,r.patient_id,job.id,r.responsible_membership_id,a.id,JSON.stringify(original),JSON.stringify(v.extraction),v.observations]);
   await tx.query("UPDATE public.vitalia_exam_care SET status='completed',updated_by=$2,revision=revision+1 WHERE id=$1",[id,a.id]);
   const saved=await savedReview(tx,id);if(!saved)throw new Error('Revisión no disponible.');return reviewSummary(saved);
  });}catch(e){translate(e);}
 },
 async download(a:AccountSummary,id:string){professional(a);if(!z.uuid().safeParse(id).success)throw new CareInboxError(404,'CARE_NOT_FOUND');
  try{
   const before=await db.transaction(tx=>load(tx,a,id));
   if(before.storage_key!==`patients/${before.patient_id}/documents/${before.document_id}`||before.size_bytes<1||before.size_bytes>MAX_FILE_BYTES)throw new Error('Objeto inconsistente.');
   const body=await storage.read(before.storage_key);
   if(body.length!==before.size_bytes)throw new Error('Objeto incompleto.');
   identifyDocument(body,before.content_type,before.original_name);
   return await db.transaction(async tx=>{
    const after=await load(tx,a,id);
    if(['document_id','storage_key','size_bytes','content_type','original_name'].some(k=>after[k as keyof Row]!==before[k as keyof Row]))throw new CareInboxError(409,'CARE_CHANGED');
    await audit(tx,a,'download',id);return {item:summary(after).document,body};
   });
  }catch(e){translate(e);}
 }
};}
export type CareInboxServices=ReturnType<typeof createCareInboxService>;
