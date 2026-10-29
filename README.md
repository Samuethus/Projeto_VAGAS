# Projeto_VAGAS

Portal de vagas estático (GitHub Pages). O banco de dados é o **Supabase** (Postgres).

- `vagas/oportunidade.html`: listagem e candidatura às vagas.
- **O cadastro de vagas NÃO é feito aqui**: é responsabilidade do projeto **CDLOAD**, que grava direto no Supabase.
- `supabase/schema.sql`: tabelas, permissões e validação do banco.
- `scripts/gerar_config.ps1`: gera o `config.js` a partir do `.env` (veja `.env.example`).
- `scripts/migrar_firebase.ps1`: exporta as vagas do Firebase antigo para o Supabase.

Arquitetura, configuração e operação do banco: [docs/SUPABASE.md](docs/SUPABASE.md).
