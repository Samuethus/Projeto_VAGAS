# Projeto_VAGAS

Portal de vagas estático (GitHub Pages). O banco de dados é o **Cloud Firestore** (Firebase).

- `vagas/oportunidade.html`: cadastro, listagem e candidatura às vagas.
- `firestore.rules`: regras de segurança e validação do banco.
- `scripts/gerar_config.ps1`: gera o `config.js` a partir do `.env` (veja `.env.example`).

Arquitetura, configuração e operação do banco: [docs/FIREBASE.md](docs/FIREBASE.md).
