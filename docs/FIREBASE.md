# Banco de dados: Firebase (Cloud Firestore)

Todo o ecossistema de dados do portal de vagas roda no **Firebase**, projeto `projeto-vagas-3e07a`. Este documento explica a arquitetura, como reconectar ou configurar o projeto do zero e a operação do dia a dia.

---

## 1. Visão geral

O site é estático (GitHub Pages, sem build e sem servidor próprio). Quem fala com o banco é o navegador do visitante:

```
Navegador ──(SDK web do Firebase, via CDN)──► Cloud Firestore
                                                 │
                                   firestore.rules decide o que é permitido
```

| Peça | Onde |
|---|---|
| SDK | `firebase-app.js` + `firebase-firestore.js` (v12.4.0), carregados de `https://www.gstatic.com/firebasejs/` |
| Configuração | `config.js`, gerado do `.env` pelo script `scripts/gerar_config.ps1` |
| Regras e validação | `firestore.rules` |
| Coleções | `vagas` e `candidaturas` |
| Banco | `(default)`, edição Standard, modo nativo |

### Permissões

- O visitante **vê** vagas ativas, **publica** vagas e **se candidata**.
- Ninguém lê candidaturas pelo site; elas só aparecem no Console do Firebase.
- Ninguém altera nem apaga dados pelo site.

### Modo demonstração

Se o `config.js` estiver sem as chaves, a página salva tudo no `localStorage` do navegador e mostra um aviso amarelo.

---

## 2. Arquivos do projeto ligados ao banco

| Arquivo | Papel |
|---|---|
| `vagas/oportunidade.html` | Camada de dados (`api.listarVagas`, `api.criarVaga`, `api.candidatar`) usando o Firestore. O SDK só é baixado quando há configuração. |
| `firestore.rules` | Regras de segurança e validação dos campos. |
| `firebase.json` | Aponta o Firebase CLI para o `firestore.rules`. |
| `.env.example` | Modelo das variáveis do Firebase. |
| `scripts/gerar_config.ps1` / `.py` | Geram o `config.js`. Recusam credencial de conta de serviço e apiKey que não comece com `AIza`. |
| `config.js` | Configuração web (pública) do Firebase, lida pela página. **Vai para o Git**, porque o GitHub Pages precisa dele. |

### Estrutura dos documentos

**`vagas`**: o ID é gerado pelo Firestore.

| Campo | Tipo | Regra |
|---|---|---|
| `cargo`, `empresa`, `local` | texto | obrigatório, até 80 caracteres |
| `tipo_contrato` | texto | Temporário, CLT, PJ, Estágio, Jovem Aprendiz ou Freelancer |
| `modalidade` | texto | Presencial, Híbrido ou Remoto |
| `quantidade` | inteiro | de 1 a 999 |
| `remuneracao`, `carga_horaria` | texto ou null | até 60 caracteres |
| `inicio`, `termino` | texto `AAAA-MM-DD` ou null | o término não pode ser antes do início |
| `descricao` | texto | obrigatório, até 1500 caracteres |
| `requisitos` | texto ou null | até 1000 caracteres |
| `beneficios` | texto ou null | até 200 caracteres |
| `whatsapp` | texto | de 10 a 13 dígitos |
| `ativa` | booleano | precisa ser `true` ao criar |
| `created_at` | timestamp | data do servidor (`serverTimestamp()`) |

**`candidaturas`**

| Campo | Tipo | Regra |
|---|---|---|
| `vaga_id` | texto | ID de uma vaga **existente e ativa** |
| `nome` | texto | obrigatório, até 100 caracteres |
| `whatsapp` | texto | de 10 a 13 dígitos |
| `email` | texto ou null | até 120 caracteres |
| `cidade` | texto ou null | até 80 caracteres |
| `disponibilidade` | texto | Imediata, Em até 15 dias ou Em até 30 dias |
| `apresentacao` | texto ou null | até 1000 caracteres |
| `consentimento` | booleano | precisa ser `true` |
| `created_at` | timestamp | data do servidor |

As regras recusam qualquer campo fora dessas listas. Se você incluir uma nova opção em um formulário (por exemplo, um tipo de contrato), inclua também no `firestore.rules` e publique de novo.

### Pontos de atenção

- **Apagar uma vaga não apaga as candidaturas dela.** Para tirar uma vaga do ar, mude `ativa` para `false`.
- A lista de vagas é ordenada no navegador, por `created_at` (da mais nova para a mais antiga). Assim não é preciso criar índice composto.

---

## 3. Configurar ou reconectar o projeto Firebase

Use este roteiro para refazer a ligação, por exemplo em outra máquina ou com outro projeto.

### Passo 1: criar o banco Firestore

1. Abra https://console.firebase.google.com/project/projeto-vagas-3e07a/firestore e clique em **Criar banco de dados**.
2. Escolha:
   - Edição: **Standard**.
   - ID: **`(default)`**.
   - Local: **`southamerica-east1 (São Paulo)`**. O local não pode ser alterado depois.
   - Modo: **produção**.
3. Clique em **Criar**.

Se aparecer a pergunta entre **Modo nativo** e **Modo Datastore**, escolha **Modo nativo**.

### Passo 2: obter a configuração do app Web

1. Abra **⚙️ Configurações do projeto > Geral > Seus apps**.
2. Se ainda não existir um app Web, clique em **Web `</>`** e registre um. Não marque o Firebase Hosting.
3. Em **SDK setup and configuration**, marque **Config** e copie `apiKey`, `authDomain`, `projectId` e `appId`.

Esses valores são públicos por natureza: identificam o projeto, mas não dão acesso de administrador. Quem protege os dados são as regras. **Nunca** use o JSON de conta de serviço (`firebase-adminsdk-....json`, com `private_key`) no site.

### Passo 3: gerar o `config.js`

1. Copie `.env.example` para `.env` e preencha os valores. O `.env` fica fora do Git.
2. Rode:

   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\gerar_config.ps1
   ```

### Passo 4: publicar as regras

**Pelo Console:**
1. Abra **Firestore Database > Regras**.
2. Cole todo o conteúdo de `firestore.rules`.
3. Clique em **Publicar**.

**Pelo CLI** (requer o [Node.js LTS](https://nodejs.org/)):

```powershell
npm install -g firebase-tools
firebase login
firebase deploy --only firestore:rules --project projeto-vagas-3e07a
```

### Passo 5: testar

1. Abra `vagas/oportunidade.html` por um servidor local (por exemplo, o Live Server do VS Code).
2. Confira que o aviso de "Modo demonstração" **não** aparece.
3. Publique uma vaga e faça uma candidatura.
4. Confira os dois documentos no Console.

Se algo falhar, veja o código de erro no console do navegador (F12):

| Código | Causa provável |
|---|---|
| `permission-denied` | Regras não publicadas, ou algum campo não passou na validação |
| `failed-precondition` / `not-found` | O banco `(default)` não foi criado |
| `unavailable` | Problema de rede |

### Passo 6: publicar o site

Faça commit e push, incluindo o `config.js`. O GitHub Pages atualiza em 1 a 3 minutos.

---

## 4. Recomendações de segurança

1. **Restringir a API key aos seus domínios.**
   - Abra o [Google Cloud Console](https://console.cloud.google.com/apis/credentials?project=projeto-vagas-3e07a), em **APIs e serviços > Credenciais**.
   - Abra a chave *Browser key (auto created by Firebase)*.
   - Em **Restrições de aplicativo > Referenciadores HTTP**, adicione:
     - `https://samuethus.github.io/*`
     - `http://localhost/*`
     - `http://127.0.0.1/*`
2. **App Check (reCAPTCHA Enterprise).** Como o site aceita vagas e candidaturas sem login, o App Check ajuda a barrar robôs.
3. **Cotas.** No plano gratuito (Spark), o Firestore tem limite diário de leituras e gravações. No plano Blaze, configure um alerta de orçamento.

---

## 5. Operação do dia a dia

| Tarefa | Onde |
|---|---|
| Ver candidaturas | Console > Firestore Database > Dados > `candidaturas` (o campo `vaga_id` é o ID do documento da vaga) |
| Tirar uma vaga do ar | Abra o documento em `vagas` e mude `ativa` para `false` |
| Corrigir dados de uma vaga | Edite o documento no Console. O site não permite alteração. |
| Mudar validações ou permissões | Edite `firestore.rules` e publique de novo |
