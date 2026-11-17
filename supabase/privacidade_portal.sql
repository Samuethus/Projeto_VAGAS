-- Privacidade do portal de empregos: o público (chave publishable, papel "anon") só lê as colunas que o site exibe.
-- Ficam fora do alcance do público, mesmo chamando a API direto:
--   vagas ............ aprovada, aprovada_por (e-mail), aprovada_em, cnpj, status, responsavel, email_responsavel,
--                      observacao_rh, vaga_id, analisado_em e qualquer coluna nova criada depois
--   vagas_conteudos .. criado_por e atualizado_por (e-mails), imagem_path e qualquer coluna nova criada depois
--
-- Rode este arquivo INTEIRO em: Supabase > SQL Editor > New query > colar > Run. Pode rodar de novo.
-- Não mexe nos privilégios do CDLoad (papel authenticated) nem nas regras de RLS.
--
-- Coluna nova que o site precise exibir: inclua na lista "grant select (...)" abaixo e na consulta da página
-- (vagas/oportunidade.html › COLUNAS_VAGA ou candidatos/candidatos.html › select=...).
-- Com o privilégio por coluna, "select=*" feito com a chave pública passa a dar erro 42501 (de propósito).

-- ---------- vagas ----------
-- id, ativa e status_validacao também são usados pela regra "candidatar" (RLS de candidaturas).
revoke select on public.vagas from anon;
grant select (id, cargo, empresa, tipo_contrato, modalidade, local, quantidade, remuneracao, carga_horaria,
              inicio, termino, descricao, requisitos, beneficios, whatsapp, link_vaga, ativa, status_validacao, created_at)
  on public.vagas to anon;

-- ---------- vagas_conteudos ----------
do $$
begin
  if to_regclass('public.vagas_conteudos') is not null then
    revoke select on public.vagas_conteudos from anon;
    grant select (id, titulo, subtitulo, descricao, categoria, assunto, imagem_url, created_at, updated_at)
      on public.vagas_conteudos to anon;
  end if;
end $$;

notify pgrst, 'reload schema';

-- Conferência: todas as linhas "publico_le" devem ser false.
select t.tabela, t.coluna, has_column_privilege('anon', 'public.' || t.tabela, t.coluna, 'select') as publico_le
  from (values ('vagas', 'aprovada_por'), ('vagas', 'responsavel'), ('vagas', 'email_responsavel'), ('vagas', 'cnpj'),
               ('vagas_conteudos', 'criado_por'), ('vagas_conteudos', 'atualizado_por')) as t(tabela, coluna)
 where exists (select 1 from information_schema.columns c
                where c.table_schema = 'public' and c.table_name = t.tabela and c.column_name = t.coluna);
