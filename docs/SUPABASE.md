# Banco de dados: Supabase (Postgres)

Todo o ecossistema de dados do portal de vagas roda no **Supabase**, projeto `xjexujpvnahaugizeyee`. Até outubro de 2026 o banco era o Cloud Firestore (Firebase, projeto `projeto-vagas-3e07a`); a seção 6 descreve a migração.

---

## 1. Visão geral

O site é estático (GitHub Pages, sem build e sem servidor próprio). Quem fala com o banco é o navegador do visitante:

```
CDLOAD (cadastro de vagas) ──(chave secret, no servidor)──┐
                                                          ▼
Navegador ──(fetch na API REST, chave publishable)──► Postgres
                                                          │
                         supabase/schema.sql (RLS + checks) decide o que o site pode fazer
```

> **O cadastro de vagas não faz parte deste projeto.** As vagas são cadastradas, alteradas e desativadas pelo projeto **CDLOAD**. Este site só lista vagas e recebe candidaturas.

| Peça | Onde |
|---|---|
| Acesso | `fetch` na API REST (`/rest/v1/...`), sem SDK |
| Configuração | `config.js`, gerado do `.env` pelo script `scripts/gerar_config.ps1` |
| Tabelas, validação e permissões | `supabase/schema.sql` |
| Tabelas | `public.vagas` e `public.candidaturas` |

### Permissões

- O visitante **vê** vagas ativas e **se candidata**.
- Ninguém cadastra, altera nem apaga vagas pelo site (o banco recusa, mesmo chamando a API direto).
- Ninguém lê candidaturas pelo site; elas só aparecem no painel do Supabase.
- O `created_at` da candidatura é sempre a data do servidor.

### Modo demonstração

Se o `config.js` estiver sem as chaves, a página não mostra vagas, salva as candidaturas no `localStorage` do navegador e mostra um aviso amarelo.

---

## 2. Arquivos do projeto ligados ao banco

| Arquivo | Papel |
|---|---|
| `vagas/oportunidade.html` | Camada de dados (`api.listarVagas`, `api.candidatar`). |
| `supabase/schema.sql` | Tabelas, validação dos campos (checks), permissões (RLS) e gatilho da data do servidor. Vale também para o que o CDLOAD gravar (os checks são do banco). |
| `.env.example` | Modelo das variáveis do Supabase. |
| `scripts/gerar_config.ps1` / `.py` | Geram o `config.js`. Recusam chave secret / service_role. |
| `config.js` | URL e chave publishable do Supabase, lidas pela página. **Vai para o Git**, porque o GitHub Pages precisa dele. |
| `scripts/migrar_firebase.ps1` | Exporta as vagas do Firestore antigo para `supabase/migracao_firebase.sql` (fora do Git). |

### Estrutura das tabelas

**`vagas`** (gravada pelo CDLOAD): o `id` é texto (as vagas migradas mantêm o ID do Firestore; se o CDLOAD não informar, o banco gera um UUID). Só aparecem no site as linhas com `ativa = true`.

| Coluna | Tipo | Regra |
|---|---|---|
| `cargo`, `empresa`, `local` | text | obrigatório, até 80 caracteres |
| `tipo_contrato` | text | Temporário, CLT, PJ, Estágio, Jovem Aprendiz ou Freelancer |
| `modalidade` | text | Presencial, Híbrido ou Remoto |
| `quantidade` | integer | de 1 a 999 |
| `remuneracao`, `carga_horaria` | text ou null | até 60 caracteres |
| `inicio`, `termino` | date ou null | o término não pode ser antes do início |
| `descricao` | text | obrigatório, até 1500 caracteres |
| `requisitos` | text ou null | até 1000 caracteres |
| `beneficios` | text ou null | até 200 caracteres |
| `whatsapp` | text | de 10 a 13 dígitos |
| `ativa` | boolean | padrão `true`; `false` tira a vaga do site |
| `created_at` | timestamptz | padrão: data do servidor |

**`candidaturas`**

| Coluna | Tipo | Regra |
|---|---|---|
| `vaga_id` | text | ID de uma vaga **existente e ativa** (chave estrangeira para `vagas.id`) |
| `nome` | text | obrigatório, até 100 caracteres |
| `whatsapp` | text | de 10 a 13 dígitos |
| `email` | text ou null | até 120 caracteres |
| `cidade` | text ou null | até 80 caracteres |
| `disponibilidade` | text | Imediata, Em até 15 dias ou Em até 30 dias |
| `apresentacao` | text ou null | até 1000 caracteres |
| `consentimento` | boolean | precisa ser `true` |
| `created_at` | timestamptz | data do servidor |

O banco recusa colunas que não existem. Se o CDLOAD passar a usar uma nova opção (por exemplo, um tipo de contrato), altere também o `check` correspondente no banco e as listas `CONTRATOS` / `MODALIDADES` dos filtros em `vagas/oportunidade.html`.

### Pontos de atenção

- **Uma vaga com candidaturas não pode ser apagada** (chave estrangeira). Para tirar uma vaga do ar, mude `ativa` para `false`.

---

## 3. Configurar ou reconectar o projeto Supabase

### Passo 1: criar as tabelas

1. Abra o painel do projeto > **SQL Editor** > **New query**.
2. Cole todo o conteúdo de `supabase/schema.sql` e clique em **Run**.

O script pode ser rodado de novo (por exemplo, depois de mudar uma permissão) sem perder dados.

### Passo 2: obter a URL e a chave publishable

1. **Project Settings > Data API**: copie a **Project URL** (`https://<id>.supabase.co`).
2. **Project Settings > API Keys**: copie a chave **publishable** (`sb_publishable_...`).

Esses valores são públicos por natureza. Quem protege os dados são as permissões (RLS). **Nunca** use a chave `sb_secret_...` (ou a antiga `service_role`) no site: ela ignora todas as permissões.

### Passo 3: gerar o `config.js`

1. Copie `.env.example` para `.env` e preencha os valores. O `.env` fica fora do Git.
2. Rode:

   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\gerar_config.ps1
   ```

### Passo 4: testar

1. Abra `vagas/oportunidade.html` por um servidor local (por exemplo, o Live Server do VS Code).
2. Confira que o aviso de "Modo demonstração" **não** aparece.
3. Confira que as vagas ativas cadastradas pelo CDLOAD aparecem e faça uma candidatura.
4. Confira a candidatura no **Table Editor**.

Se algo falhar, veja o código de erro no console do navegador (F12):

| Código | Causa provável |
|---|---|
| `PGRST205` / `404` | As tabelas não foram criadas (rode o `schema.sql`) |
| `42501` | Bloqueado pelas permissões (por exemplo, candidatura para vaga inativa) |
| `23514` | Algum campo não passou na validação (`check`) |
| `23503` | Candidatura para vaga que não existe |
| `401` | Chave errada no `config.js` |
| sem conexão | Problema de rede |

### Passo 5: publicar o site

Faça commit e push, incluindo o `config.js`. O GitHub Pages atualiza em 1 a 3 minutos.

---

## 4. Recomendações de segurança

1. **A chave secret fica só no CDLOAD**, em servidor ou variável de ambiente. Nunca no navegador nem no Git.
2. **Candidaturas sem login.** Como o site aceita candidaturas sem login, considere ativar **CAPTCHA** (Authentication > Attack Protection) junto com login anônimo, ou mover a gravação para uma Edge Function com verificação.
3. **Cotas.** No plano gratuito, projetos inativos por 7 dias são pausados. Acompanhe o uso em **Reports**.

---

## 5. Operação do dia a dia

| Tarefa | Onde |
|---|---|
| Ver candidaturas | Table Editor > `candidaturas` (o `vaga_id` é o `id` da vaga) |
| Cadastrar, corrigir ou tirar uma vaga do ar | Projeto **CDLOAD** (em emergência: Table Editor > `vagas`, `ativa = false`) |
| Mudar validações ou permissões | Edite `supabase/schema.sql` e rode de novo no SQL Editor |

---

## 6. Migração a partir do Firebase

1. Rode `supabase/schema.sql` no SQL Editor (passo 1 da seção 3).
2. Gere o arquivo com os dados:

   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\migrar_firebase.ps1
   ```

3. Cole `supabase/migracao_firebase.sql` no SQL Editor e clique em **Run**. Vagas já migradas são ignoradas, então pode repetir.

**Limitações:** as regras do Firestore só deixam ler vagas **ativas**. Vagas inativas e **candidaturas** só podem ser exportadas pelo Console do Firebase (Firestore Database > Dados) ou com uma conta de serviço. Se houver candidaturas lá, copie-as para a tabela `candidaturas` pelo Table Editor (o `vaga_id` continua o mesmo ID do Firestore).
