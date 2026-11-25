-- Corrige o erro 42501 ("permission denied for table vagas") ao enviar candidatura pelo site.
--
-- Causa: a tabela vagas também tem uma coluna "vaga_id" (criada pelo CDLOAD). Na regra "candidatar", o
-- "vaga_id" sem prefixo dentro de "select ... from public.vagas v" era lido como v.vaga_id, e não como
-- candidaturas.vaga_id. Depois de privacidade_portal.sql o público não lê mais vagas.vaga_id -> erro 42501.
-- (Antes disso a regra comparava v.id = v.vaga_id, o que também estava errado.)
--
-- Rode este arquivo INTEIRO em: Supabase > SQL Editor > New query > colar > Run. Pode rodar de novo.
-- Só troca a regra "candidatar"; não mexe em privilégios nem nas outras regras.

drop policy if exists "candidatar" on public.candidaturas;
create policy "candidatar" on public.candidaturas
  for insert to anon, authenticated
  with check (exists (select 1 from public.vagas v
                       where v.id = candidaturas.vaga_id and v.ativa and coalesce(btrim(v.status_validacao), '') = ''));

notify pgrst, 'reload schema';

-- Conferência: a expressão deve citar "candidaturas.vaga_id".
select policyname, with_check from pg_policies
 where schemaname = 'public' and tablename = 'candidaturas' and policyname = 'candidatar';
