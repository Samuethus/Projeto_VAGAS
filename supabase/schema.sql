-- Banco do portal de vagas (Supabase / Postgres): tabelas, validação dos campos e permissões (RLS).
-- Rodar uma vez em: Supabase > SQL Editor > New query > colar tudo > Run. Pode ser rodado de novo sem perder dados.
--
-- Visitantes (chave publishable, papel "anon") podem: ver vagas ativas, se candidatar e solicitar a publicação de uma vaga.
-- Vagas são gravadas SÓ pelo projeto CDLOAD (com a chave secret, no servidor, que ignora estas permissões)
-- ou pela aprovação de uma solicitação pelo RH (public.aprovar_solicitacao).
-- Candidaturas e solicitações NÃO podem ser lidas pelo site: só pelo painel do Supabase (Table Editor) ou pelo CDLOAD.
-- Ninguém publica vaga, altera nem apaga pelo site.

-- ---------- Tabelas ----------
-- O id é texto para manter os IDs das vagas que vieram do Firestore; vagas novas recebem um UUID.
create table if not exists public.vagas (
  id            text primary key default gen_random_uuid()::text,
  cargo         text not null check (char_length(cargo) between 1 and 80),
  empresa       text not null check (char_length(empresa) between 1 and 80),
  tipo_contrato text not null check (tipo_contrato in ('Temporário', 'CLT', 'PJ', 'Estágio', 'Jovem Aprendiz', 'Freelancer')),
  modalidade    text not null check (modalidade in ('Presencial', 'Híbrido', 'Remoto')),
  local         text not null check (char_length(local) between 1 and 80),
  quantidade    integer not null check (quantidade between 1 and 999),
  remuneracao   text check (char_length(remuneracao) between 1 and 60),
  carga_horaria text check (char_length(carga_horaria) between 1 and 60),
  inicio        date,
  termino       date,
  descricao     text not null check (char_length(descricao) between 1 and 1500),
  requisitos    text check (char_length(requisitos) between 1 and 1000),
  beneficios    text check (char_length(beneficios) between 1 and 200),
  whatsapp      text not null check (whatsapp ~ '^[0-9]{10,13}$'),
  ativa         boolean not null default true,
  created_at    timestamptz not null default now(),
  constraint vagas_periodo check (inicio is null or termino is null or termino >= inicio)
);

create table if not exists public.candidaturas (
  id              uuid primary key default gen_random_uuid(),
  vaga_id         text not null references public.vagas (id),
  nome            text not null check (char_length(nome) between 1 and 100),
  whatsapp        text not null check (whatsapp ~ '^[0-9]{10,13}$'),
  email           text check (char_length(email) between 1 and 120),
  cidade          text check (char_length(cidade) between 1 and 80),
  disponibilidade text not null check (disponibilidade in ('Imediata', 'Em até 15 dias', 'Em até 30 dias')),
  apresentacao    text check (char_length(apresentacao) between 1 and 1000),
  consentimento   boolean not null check (consentimento),
  created_at      timestamptz not null default now()
);

-- CNPJ e link oficial vêm da solicitação aprovada; opcionais para as vagas que o CDLOAD já cadastra.
alter table public.vagas add column if not exists cnpj text check (cnpj ~ '^[0-9]{14}$');
alter table public.vagas add column if not exists link_vaga text check (char_length(link_vaga) <= 300 and link_vaga ~* '^https?://');

-- Fila de aprovação: empresas externas pedem a publicação pelo site (vagas/solicitar-vaga.html).
-- O RH confere e aprova com public.aprovar_solicitacao(id), que copia a solicitação para vagas.
create table if not exists public.solicitacoes_vagas (
  id                uuid primary key default gen_random_uuid(),
  status            text not null default 'pendente' check (status in ('pendente', 'aprovada', 'reprovada')),
  empresa           text not null check (char_length(empresa) between 1 and 80),
  cnpj              text not null check (cnpj ~ '^[0-9]{14}$'),
  responsavel       text not null check (char_length(responsavel) between 1 and 100),
  email_responsavel text check (char_length(email_responsavel) between 3 and 120),
  cargo             text not null check (char_length(cargo) between 1 and 80),
  tipo_contrato     text not null check (tipo_contrato in ('Temporário', 'CLT', 'PJ', 'Estágio', 'Jovem Aprendiz', 'Freelancer')),
  modalidade        text not null check (modalidade in ('Presencial', 'Híbrido', 'Remoto')),
  local             text not null check (char_length(local) between 1 and 80),
  quantidade        integer not null check (quantidade between 1 and 999),
  remuneracao       text check (char_length(remuneracao) between 1 and 60),
  carga_horaria     text check (char_length(carga_horaria) between 1 and 60),
  inicio            date,
  termino           date,
  descricao         text not null check (char_length(descricao) between 1 and 1500),
  requisitos        text check (char_length(requisitos) between 1 and 1000),
  beneficios        text check (char_length(beneficios) between 1 and 200),
  whatsapp          text not null check (whatsapp ~ '^[0-9]{10,13}$'),
  link_vaga         text check (char_length(link_vaga) <= 300 and link_vaga ~* '^https?://'),
  observacao_rh     text check (char_length(observacao_rh) <= 500),
  vaga_id           text references public.vagas (id),
  analisado_em      timestamptz,
  created_at        timestamptz not null default now(),
  constraint solicitacoes_periodo check (inicio is null or termino is null or termino >= inicio)
);

create index if not exists vagas_ativa_created_at on public.vagas (ativa, created_at desc);
create index if not exists candidaturas_vaga_id on public.candidaturas (vaga_id);
create index if not exists solicitacoes_status_created_at on public.solicitacoes_vagas (status, created_at desc);

-- ---------- Data do servidor ----------
-- Quem se candidata pelo site não escolhe created_at (equivale ao serverTimestamp() do Firestore).
-- O painel, o SQL Editor e o CDLOAD ficam livres, para a migração manter as datas originais.
create or replace function public.fixar_dados_do_servidor() returns trigger
language plpgsql set search_path = '' as $$
begin
  if current_user in ('anon', 'authenticated') then
    new.created_at := now();
  end if;
  return new;
end $$;

-- O cadastro de vagas saiu do site; o gatilho que forçava ativa/created_at em vagas não é mais necessário.
drop trigger if exists vagas_dados_do_servidor on public.vagas;

drop trigger if exists candidaturas_dados_do_servidor on public.candidaturas;
create trigger candidaturas_dados_do_servidor before insert on public.candidaturas
  for each row execute function public.fixar_dados_do_servidor();

-- Quem solicita pelo site não escolhe o resultado da análise: toda solicitação nasce pendente.
create or replace function public.fixar_solicitacao_do_servidor() returns trigger
language plpgsql set search_path = '' as $$
begin
  if current_user in ('anon', 'authenticated') then
    new.status := 'pendente';
    new.observacao_rh := null;
    new.vaga_id := null;
    new.analisado_em := null;
    new.created_at := now();
  end if;
  return new;
end $$;

drop trigger if exists solicitacoes_dados_do_servidor on public.solicitacoes_vagas;
create trigger solicitacoes_dados_do_servidor before insert on public.solicitacoes_vagas
  for each row execute function public.fixar_solicitacao_do_servidor();

-- ---------- Aprovação pelo RH (SQL Editor ou CDLOAD; o site não pode chamar) ----------
-- select public.aprovar_solicitacao('<id>');            -> publica a vaga e devolve o id dela
-- select public.reprovar_solicitacao('<id>', 'motivo'); -> marca como reprovada
create or replace function public.aprovar_solicitacao(p_id uuid) returns text
language plpgsql security definer set search_path = '' as $$
declare
  s public.solicitacoes_vagas;
  nova text;
begin
  select * into s from public.solicitacoes_vagas where id = p_id for update;
  if not found then raise exception 'Solicitação % não encontrada.', p_id; end if;
  if s.status <> 'pendente' then raise exception 'Solicitação % já foi analisada (%).', p_id, s.status; end if;

  insert into public.vagas (cargo, empresa, cnpj, tipo_contrato, modalidade, local, quantidade, remuneracao, carga_horaria,
                            inicio, termino, descricao, requisitos, beneficios, whatsapp, link_vaga)
  values (s.cargo, s.empresa, s.cnpj, s.tipo_contrato, s.modalidade, s.local, s.quantidade, s.remuneracao, s.carga_horaria,
          s.inicio, s.termino, s.descricao, s.requisitos, s.beneficios, s.whatsapp, s.link_vaga)
  returning id into nova;

  update public.solicitacoes_vagas set status = 'aprovada', vaga_id = nova, analisado_em = now() where id = p_id;
  return nova;
end $$;

create or replace function public.reprovar_solicitacao(p_id uuid, p_motivo text default null) returns void
language plpgsql security definer set search_path = '' as $$
begin
  update public.solicitacoes_vagas set status = 'reprovada', observacao_rh = p_motivo, analisado_em = now()
   where id = p_id and status = 'pendente';
  if not found then raise exception 'Solicitação % não encontrada ou já analisada.', p_id; end if;
end $$;

revoke execute on function public.aprovar_solicitacao(uuid) from public, anon, authenticated;
revoke execute on function public.reprovar_solicitacao(uuid, text) from public, anon, authenticated;

-- ---------- Permissões ----------
alter table public.vagas enable row level security;
alter table public.candidaturas enable row level security;
alter table public.solicitacoes_vagas enable row level security;

revoke all on public.vagas, public.candidaturas, public.solicitacoes_vagas from anon, authenticated;
grant select on public.vagas to anon, authenticated;
grant insert on public.candidaturas to anon, authenticated;
grant insert on public.solicitacoes_vagas to anon, authenticated;

drop policy if exists "ver vagas ativas" on public.vagas;
create policy "ver vagas ativas" on public.vagas
  for select to anon, authenticated using (ativa);

-- Remove a permissão de cadastro que existia quando o site publicava vagas.
drop policy if exists "publicar vaga" on public.vagas;

-- Só aceita candidatura para vaga que existe e está ativa.
drop policy if exists "candidatar" on public.candidaturas;
create policy "candidatar" on public.candidaturas
  for insert to anon, authenticated
  with check (exists (select 1 from public.vagas v where v.id = vaga_id and v.ativa));

-- Qualquer empresa pode pedir a publicação; ninguém lê, altera ou apaga solicitações pelo site.
drop policy if exists "solicitar publicação" on public.solicitacoes_vagas;
create policy "solicitar publicação" on public.solicitacoes_vagas
  for insert to anon, authenticated
  with check (status = 'pendente');
