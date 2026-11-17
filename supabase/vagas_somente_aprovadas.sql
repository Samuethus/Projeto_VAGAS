-- Site público: só vagas APROVADAS aparecem e recebem candidatura.
--
-- Regra de validação do CDLOAD (Projeto_CDLOAD/supabase/schema_vagas.sql):
--   Pendente ............ linha em solicitacoes_vagas (nunca chega ao site)
--   Aprovada ............ linha em vagas com status_validacao vazio
--   Reprovada/Desativada  status_validacao preenchido ('Reprovada' ou 'Desativada')
-- Além disso, ativa = false continua tirando a vaga do ar.
--
-- Rode SÓ este arquivo em: Supabase > SQL Editor > New query > colar > Run. Pode rodar de novo.
-- Não rode o schema.sql inteiro de novo: o "revoke all" dele apaga os privilégios que o CDLOAD
-- concede ao papel authenticated. Este arquivo só troca as duas regras do site.

alter table public.vagas add column if not exists status_validacao text;

drop policy if exists "ver vagas ativas" on public.vagas;
create policy "ver vagas ativas" on public.vagas
  for select to anon, authenticated
  using (ativa and coalesce(btrim(status_validacao), '') = '');

drop policy if exists "candidatar" on public.candidaturas;
create policy "candidatar" on public.candidaturas
  for insert to anon, authenticated
  with check (exists (select 1 from public.vagas v
                       where v.id = vaga_id and v.ativa and coalesce(btrim(v.status_validacao), '') = ''));

-- Conferência: deve listar só vagas aprovadas (o SQL Editor ignora o RLS, por isso o filtro repete a regra).
select id, cargo, empresa, status_validacao, ativa
  from public.vagas
 where ativa and coalesce(btrim(status_validacao), '') = ''
 order by created_at desc;
