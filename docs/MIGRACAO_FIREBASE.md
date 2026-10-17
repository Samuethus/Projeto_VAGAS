# Migração do banco de dados: Supabase → Firebase (Firestore)

Este documento explica o que mudou no projeto ao trocar o Supabase pelo **Cloud Firestore** e o passo a passo para conectar o site ao projeto que já existe no Firebase.

> **Sem migração de histórico.** As vagas e candidaturas que estavam no Supabase **não** foram trazidas: o Firestore começa vazio.

---

## 1. Visão geral

O site continua estático (GitHub Pages, sem build e sem servidor próprio). Quem fala com o banco é o navegador do visitante:

```
Navegador ──(SDK web do Firebase, via CDN)──► Cloud Firestore
                                                 │
                                   firestore.rules decide o que é permitido
```

| Antes (Supabase) | Agora (Firebase) |
|---|---|
| API REST `/rest/v1` chamada com `fetch` | SDK oficial `firebase-firestore.js` (v12.4.0) carregado do CDN `gstatic.com` |
| `SUPABASE_URL` + `SUPABASE_ANON_KEY` no `config.js` | `FIREBASE_API_KEY`, `FIREBASE_PROJECT_ID`, `FIREBASE_APP_ID` (+ `FIREBASE_AUTH_DOMAIN`, opcional) |
| `supabase/schema.sql` (tabelas, `check`, RLS) | `firestore.rules` (validação dos campos + permissões) |
| Tabelas `vagas` e `candidaturas` | Coleções `vagas` e `candidaturas` (os nomes dos campos são os mesmos) |

### O que **não** mudou

- A interface, os formulários e os nomes dos campos.
- O **modo demonstração**: se o `config.js` estiver sem as chaves, a página salva tudo no `localStorage` do navegador e mostra o aviso amarelo.
- As permissões: o visitante **vê** vagas ativas, **publica** vagas e **se candidata**. Ninguém lê candidaturas pelo site; elas só aparecem no Console do Firebase.

---

## 2. O que foi alterado no código

| Arquivo | Mudança |
|---|---|
| `vagas/oportunidade.html` | A camada de dados (`api.listarVagas`, `api.criarVaga`, `api.candidatar`) agora usa o Firestore. O SDK só é baixado quando há configuração. |
| `firestore.rules` | **Novo.** Regras de segurança e validação (substituem o `schema.sql`). |
| `firebase.json` | **Novo.** Aponta o Firebase CLI para o `firestore.rules`. |
| `.env.example` | **Novo.** Modelo das variáveis do Firebase. |
| `scripts/gerar_config.ps1` / `.py` | Geram o `config.js` com as chaves do Firebase. Recusam credencial de conta de serviço e apiKey que não comece com `AIza`. |
| `config.js` | Zerado (modo demonstração) até você rodar o script com o seu `.env`. |
| `.gitignore` | Libera `firebase.json` (o projeto ignora `*.json`) e bloqueia arquivos de conta de serviço. |
| `index.html` | O selo de integração "Supabase" virou "Firebase". |
| `supabase/` | **Removida.** |

### Como cada recurso do Postgres foi traduzido

| Supabase / Postgres | Firestore |
|---|---|
| `id uuid default gen_random_uuid()` | ID automático do documento (`addDoc`) |
| `created_at timestamptz default now()` | `serverTimestamp()` no site + regra `created_at == request.time` (o cliente não consegue falsificar a data) |
| `ativa boolean default true` | O site grava `ativa: true` e a regra exige isso |
| `check (char_length(...) <= N)` | Funções `texto()` / `textoOpcional()` na regra |
| `check (whatsapp ~ '^\d{10,13}$')` | `whatsapp.matches('^[0-9]{10,13}$')` |
| `check (termino >= inicio)` | Comparação das datas (texto `AAAA-MM-DD`) na regra |
| `references vagas(id)` (chave estrangeira) | `exists()` + `get()` na regra: só aceita candidatura para vaga existente **e ativa** |
| RLS "leitura das ativas" | `allow read: if resource.data.ativa == true` |
| `order by created_at desc` | Ordenação feita no navegador (dispensa índice composto) |

As regras também são **mais rígidas** que o schema antigo em dois pontos: só aceitam os tipos de contrato, modalidades e disponibilidades que existem nos formulários, e recusam qualquer campo extra.

### Diferenças que vale saber

- **Não há "on delete cascade".** Se você apagar uma vaga no Console, as candidaturas dela continuam na coleção `candidaturas`. Para tirar uma vaga do ar, prefira mudar `ativa` para `false`.
- **Datas** (`inicio`, `termino`) ficam como texto `AAAA-MM-DD`, que é o que a tela já usava.
- **`created_at`** fica como *timestamp* do Firestore; a página converte para texto só para ordenar.

---

## 3. Passo a passo para conectar ao projeto existente no Firebase

### Passo 1: criar o banco Firestore no projeto

1. Abra o [Console do Firebase](https://console.firebase.google.com/) e selecione o projeto.
2. Menu **Criação (Build) > Firestore Database > Criar banco de dados**.
   - Se o banco já existir, pule para o Passo 2.
3. **Local:** `southamerica-east1 (São Paulo)`. **Atenção:** o local não pode ser alterado depois.
4. **Modo:** *produção* (tudo bloqueado). As regras do projeto serão publicadas no Passo 4.

### Passo 2: registrar o app Web e copiar a configuração

1. No Console, clique na engrenagem > **Configurações do projeto > Geral**.
2. Em **Seus apps**, clique no ícone **Web `</>`**.
   - Se já houver um app Web, use o dele.
3. Dê um apelido (ex.: `portal-vagas`). **Não** precisa marcar o Firebase Hosting, porque o site continua no GitHub Pages.
4. Na tela seguinte aparece um objeto `firebaseConfig` como este:

   ```js
   const firebaseConfig = {
     apiKey: "AIza...",
     authDomain: "seu-projeto.firebaseapp.com",
     projectId: "seu-projeto",
     storageBucket: "...",
     messagingSenderId: "...",
     appId: "1:...:web:..."
   };
   ```

   Usaremos apenas `apiKey`, `authDomain`, `projectId` e `appId`.

> **Esses valores são públicos por natureza.** Eles vão para o navegador e identificam o projeto, mas não dão acesso de administrador. Quem protege os dados são as regras. **Nunca** use o JSON de *conta de serviço* (`firebase-adminsdk-....json`, com `private_key`) no site.

### Passo 3: gerar o `config.js`

Na raiz do projeto:

1. Copie `.env.example` para `.env` e preencha:

   ```ini
   FIREBASE_API_KEY=AIza...
   FIREBASE_AUTH_DOMAIN=seu-projeto.firebaseapp.com
   FIREBASE_PROJECT_ID=seu-projeto
   FIREBASE_APP_ID=1:...:web:...
   ```

2. Gere o arquivo:

   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\gerar_config.ps1
   ```

   O `.env` fica fora do Git. O `config.js` gerado **vai** para o Git, porque o GitHub Pages precisa dele.

### Passo 4: publicar as regras de segurança

Sem este passo o banco recusa tudo, e a página mostra "Não foi possível carregar as vagas".

**Opção A: pelo Console (mais simples)**

1. Abra **Firestore Database > Regras**.
2. Apague o conteúdo, cole todo o arquivo `firestore.rules` e clique em **Publicar**.

**Opção B: pelo Firebase CLI**

Recomendada se as regras forem mudar com frequência.

1. Instale o [Node.js LTS](https://nodejs.org/).
2. No terminal, na raiz do projeto:

   ```powershell
   npm install -g firebase-tools
   firebase login
   firebase deploy --only firestore:rules --project SEU_PROJECT_ID
   ```

Se você alterar o `firestore.rules`, publique de novo.

### Passo 5: testar localmente

1. Abra `vagas/oportunidade.html` por um servidor local, por exemplo a extensão **Live Server** do VS Code.
2. Confira os pontos abaixo:
   - O aviso amarelo de "Modo demonstração" **não** aparece.
   - "Nova vaga" publica a vaga, e ela aparece na lista e em **Console > Firestore Database > Dados > vagas**.
   - "Candidatar-se" registra a candidatura, e ela aparece na coleção **candidaturas**.
3. Se algo falhar, abra o console do navegador (F12). O erro mostra o código do Firestore:
   - `permission-denied`: as regras não foram publicadas, ou algum campo não passou na validação.
   - `failed-precondition`: o banco Firestore não foi criado (Passo 1).
   - `unavailable`: há um problema de rede.

### Passo 6: publicar o site

Faça commit e push dos arquivos alterados (inclusive o `config.js` gerado). O GitHub Pages passa a usar o Firestore.

### Passo 7: desligar o Supabase

Depois de validar em produção, pause ou exclua o projeto no painel do Supabase. Como não há migração de histórico, nada precisa ser exportado antes. Se quiser guardar uma cópia, exporte antes de excluir.

---

## 4. Recomendações de segurança (opcionais, mas indicadas)

1. **Restringir a API key ao seu domínio.**
   - Abra o [Google Cloud Console](https://console.cloud.google.com/apis/credentials) do mesmo projeto, em **APIs e serviços > Credenciais**.
   - Abra a chave *Browser key (auto created by Firebase)*.
   - Em **Restrições de aplicativo > Referenciadores HTTP**, adicione:
     - `https://SEU-USUARIO.github.io/*`
     - `http://localhost/*`
     - `http://127.0.0.1/*`
2. **App Check (reCAPTCHA Enterprise).** Como antes, qualquer visitante pode publicar vagas e candidaturas sem login. O App Check reduz spam de robôs. Exige pequenas mudanças no código, quando for desejado.
3. **Alertas de orçamento.** No plano gratuito (Spark), o Firestore tem cota diária de leituras e gravações; ao estourar, o banco para até o dia seguinte. No plano Blaze, configure um alerta de orçamento.

---

## 5. Operação do dia a dia

| Tarefa | Onde |
|---|---|
| Ver candidaturas | Console > Firestore Database > Dados > `candidaturas` (o campo `vaga_id` é o ID do documento da vaga) |
| Tirar uma vaga do ar | Abra o documento em `vagas` e mude `ativa` para `false` |
| Corrigir dados de uma vaga | Edite o documento no Console. O site não permite alteração. |
| Mudar validações / permissões | Edite `firestore.rules` e publique de novo (Passo 4) |
