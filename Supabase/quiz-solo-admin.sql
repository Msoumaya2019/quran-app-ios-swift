begin;
-- Remove only the source-title requirement; preserve all other question checks.
do $$ declare c record;begin
 for c in select conname from pg_constraint where conrelid='public.quiz_questions'::regclass and contype='c' and pg_get_constraintdef(oid) like '%source_title%' loop
 execute format('alter table public.quiz_questions drop constraint %I',c.conname);end loop;
end $$;
alter table public.quiz_questions alter column source_title drop not null;
alter table public.quiz_questions alter column explanation drop not null;
create table if not exists public.quiz_solo_runs(id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id),questions jsonb not null,created_at timestamptz not null default now());
create table if not exists public.quiz_solo_answers(run_id uuid not null references public.quiz_solo_runs(id),question_id uuid not null,answer_id text not null,is_correct boolean not null,answered_at timestamptz not null default now(),primary key(run_id,question_id));
alter table public.quiz_solo_runs enable row level security;
alter table public.quiz_solo_answers enable row level security;
revoke all on public.quiz_solo_runs,public.quiz_solo_answers from anon,authenticated;
create or replace function public.quiz_start_solo() returns jsonb language plpgsql security definer set search_path='' as $$
declare questions jsonb;run_id uuid;
begin
 if auth.uid() is null then raise exception 'Connexion requise';end if;
 select jsonb_agg(private.quiz_question_json(q)) into questions from(select * from public.quiz_questions where is_active and not is_deleted order by random() limit 10) q;
 if questions is null then raise exception 'Aucune question active disponible';end if;
 insert into public.quiz_solo_runs(user_id,questions) values(auth.uid(),questions) returning id into run_id;
 return jsonb_build_object('id',run_id,'questions',(select jsonb_agg(private.quiz_public_question(q)) from jsonb_array_elements(questions) q));
end $$;
create or replace function public.quiz_answer_solo(p_run uuid,p_question uuid,p_answer text) returns jsonb language plpgsql security definer set search_path='' as $$
declare q jsonb;a public.quiz_solo_answers;
begin
 if auth.uid() is null then raise exception 'Connexion requise';end if;
 select question into q from public.quiz_solo_runs r cross join jsonb_array_elements(r.questions) question where r.id=p_run and r.user_id=auth.uid() and question->>'id'=p_question::text;
 if q is null then raise exception 'Question ou session indisponible';end if;
 if not exists(select 1 from jsonb_array_elements(q->'answers') x where x->>'id'=p_answer) then raise exception 'Réponse invalide';end if;
 insert into public.quiz_solo_answers(run_id,question_id,answer_id,is_correct) values(p_run,p_question,p_answer,p_answer=q->>'correctAnswerId') on conflict do nothing;
 select * into a from public.quiz_solo_answers where run_id=p_run and question_id=p_question;
 return jsonb_build_object('question',q,'selectedAnswerId',a.answer_id,'isCorrect',a.is_correct);
end $$;
create or replace function public.quiz_admin_responses(p_question uuid default null,p_offset integer default 0) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if not private.is_app_admin() then raise exception 'Accès administrateur refusé';end if;
 return (select coalesce(jsonb_agg(to_jsonb(r) order by r.answered_at desc,r.user_id,r.quiz_id,r.question_id),'[]') from (
 select a.*,coalesce(p.display_name,'Compte sans profil') as user_name from (
 select d.user_id,d.day::text as quiz_id,'Question du jour'::text as mode,d.question_id,d.answer_id,d.is_correct,d.answered_at,d.question_snapshot as question from public.quiz_daily_responses d
 union all select a.user_id,a.challenge_id::text,'Défi entre amis',a.question_id,a.answer_id,a.is_correct,a.answered_at,q.question_snapshot from public.quiz_challenge_answers a join public.quiz_challenge_questions q on q.challenge_id=a.challenge_id and q.question_id=a.question_id
 union all select r.user_id,a.run_id::text,'Solo',a.question_id,a.answer_id,a.is_correct,a.answered_at,q from public.quiz_solo_answers a join public.quiz_solo_runs r on r.id=a.run_id cross join jsonb_array_elements(r.questions) q where q->>'id'=a.question_id::text
 ) a left join public.friend_profiles p on p.id=a.user_id where p_question is null or a.question_id=p_question order by a.answered_at desc,a.user_id,a.quiz_id,a.question_id limit 50 offset greatest(0,p_offset)
 ) r);
end $$;
revoke all on function public.quiz_start_solo(),public.quiz_answer_solo(uuid,uuid,text),public.quiz_admin_responses(uuid,integer) from public,anon;
grant execute on function public.quiz_start_solo(),public.quiz_answer_solo(uuid,uuid,text),public.quiz_admin_responses(uuid,integer) to authenticated;
commit;
