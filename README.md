# Projeto_VAGAS

Portal de vagas estático (GitHub Pages). O banco de dados é o **Supabase** (Postgres).

**Endereço oficial: [empregoscdlcba.com.br](http://empregoscdlcba.com.br/)**. O domínio está no arquivo `CNAME`. O endereço antigo (`samuethus.github.io/Projeto_VAGAS`) e o `www.` redirecionam para ele. Os links do site são relativos, então nada muda no código ao trocar de domínio.

- `vagas/oportunidade.html`: listagem e candidatura às vagas.
- `vagas/solicitar-vaga.html`: formulário público para empresas pedirem a publicação de uma vaga. A solicitação entra como **pendente** e só vira vaga depois da aprovação do RH.
- **O site não publica vagas diretamente**: elas são gravadas pelo projeto **CDLOAD** ou pela aprovação de uma solicitação (`public.aprovar_solicitacao`).
- `supabase/schema.sql`: tabelas, permissões e validação do banco.
- `scripts/gerar_config.ps1`: gera o `config.js` a partir do `.env` (veja `.env.example`).
- `scripts/migrar_firebase.ps1`: exporta as vagas do Firebase antigo para o Supabase.

Arquitetura, configuração e operação do banco: [docs/SUPABASE.md](docs/SUPABASE.md).
