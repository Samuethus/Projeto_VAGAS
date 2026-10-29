-- Banco do portal de vagas (Supabase / Postgres): tabelas, validação dos campos e permissões (RLS).
-- Rodar uma vez em: Supabase > SQL Editor > New query > colar tudo > Run. Pode ser rodado de novo sem perder dados.
--
-- Visitantes (chave publishable, papel "anon") podem: ver vagas ativas e se candidatar.
-- Vagas são cadastradas SÓ pelo projeto CDLOAD (com a chave secret, no servidor, que ignora estas permissões).
-- Candidaturas NÃO podem ser lidas pelo site: só pelo painel do Supabase (Table Editor).
-- Ninguém cadastra vaga, altera nem apaga pelo site.

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

create index if not exists vagas_ativa_created_at on public.vagas (ativa, created_at desc);
create index if not exists candidaturas_vaga_id on public.candidaturas (vaga_id);

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

-- ---------- Permissões ----------
alter table public.vagas enable row level security;
alter table public.candidaturas enable row level security;

revoke all on public.vagas, public.candidaturas from anon, authenticated;
grant select on public.vagas to anon, authenticated;
grant insert on public.candidaturas to anon, authenticated;

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
