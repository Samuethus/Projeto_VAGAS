# Projeto_VAGAS

Portal de vagas estático (GitHub Pages). O banco de dados é o **Cloud Firestore** (Firebase).

- `vagas/oportunidade.html`: cadastro, listagem e candidatura às vagas.
- `firestore.rules`: regras de segurança e validação do banco.
- `scripts/gerar_config.ps1`: gera o `config.js` a partir do `.env` (veja `.env.example`).

Para conectar ao projeto Firebase, siga o passo a passo em [docs/MIGRACAO_FIREBASE.md](docs/MIGRACAO_FIREBASE.md).
