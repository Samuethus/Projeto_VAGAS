-- Estrutura do banco de vagas (Supabase > SQL Editor > New query > colar e rodar).
-- Visitantes (chave anon) podem: ver vagas ativas, publicar vagas e se candidatar.
-- Candidaturas NÃO podem ser lidas pela chave anon: só pelo painel do Supabase
-- (ou por uma área logada, quando existir).

create table if not exists public.vagas (
  id             uuid primary key default gen_random_uuid(),
  created_at     timestamptz not null default now(),
  cargo          text not null check (char_length(cargo) <= 80),
  empresa        text not null check (char_length(empresa) <= 80),
  tipo_contrato  text not null,
  modalidade     text not null,
  local          text not null check (char_length(local) <= 80),
  quantidade     int  not null default 1 check (quantidade between 1 and 999),
  remuneracao    text check (char_length(remuneracao) <= 60),
  carga_horaria  text check (char_length(carga_horaria) <= 60),
  inicio         date,
  termino        date,
  descricao      text not null check (char_length(descricao) <= 1500),
  requisitos     text check (char_length(requisitos) <= 1000),
  beneficios     text check (char_length(beneficios) <= 200),
  whatsapp       text not null check (whatsapp ~ '^\d{10,13}$'),
  ativa          boolean not null default true,
  check (termino is null or inicio is null or termino >= inicio)
);

create table if not exists public.candidaturas (
  id              uuid primary key default gen_random_uuid(),
  created_at      timestamptz not null default now(),
  vaga_id         uuid not null references public.vagas(id) on delete cascade,
  nome            text not null check (char_length(nome) <= 100),
  whatsapp        text not null check (whatsapp ~ '^\d{10,13}$'),
  email           text check (char_length(email) <= 120),
  cidade          text check (char_length(cidade) <= 80),
  disponibilidade text not null,
  apresentacao    text check (char_length(apresentacao) <= 1000),
  consentimento   boolean not null check (consentimento)
);

create index if not exists candidaturas_vaga_id_idx on public.candidaturas (vaga_id);

alter table public.vagas        enable row level security;
alter table public.candidaturas enable row level security;

drop policy if exists "vagas: leitura das ativas" on public.vagas;
create policy "vagas: leitura das ativas" on public.vagas
  for select to anon, authenticated using (ativa);

drop policy if exists "vagas: publicar" on public.vagas;
create policy "vagas: publicar" on public.vagas
  for insert to anon, authenticated with check (ativa);

drop policy if exists "candidaturas: enviar" on public.candidaturas;
create policy "candidaturas: enviar" on public.candidaturas
  for insert to anon, authenticated
  with check (exists (select 1 from public.vagas v where v.id = vaga_id and v.ativa));
