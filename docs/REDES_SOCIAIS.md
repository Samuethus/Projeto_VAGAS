# Redes sociais do cabeçalho

O cabeçalho do `index.html` mostra cinco ícones de redes sociais da CDL Cuiabá. Por enquanto todos apontam para `#`, ou seja, não abrem nada. Preencha a tabela abaixo com os endereços oficiais; depois eles serão aplicados no site.

---

## 1. Links para preencher

Preencha a coluna **Link** com o endereço completo, começando por `https://`. Se a CDL não usa alguma rede, escreva **remover** e o ícone sai do cabeçalho.

| Rede | Link | Exemplo de formato |
|---|---|---|
| Facebook |  | `https://www.facebook.com/nome-da-pagina` |
| Instagram |  | `https://www.instagram.com/perfil` |
| LinkedIn |  | `https://www.linkedin.com/company/nome-da-empresa` |
| YouTube |  | `https://www.youtube.com/@canal` |
| WhatsApp |  | `https://wa.me/5565999999999` (55 + DDD + número, só dígitos) |

### Quer incluir outra rede?

Acrescente uma linha na tabela (por exemplo TikTok, X ou Spotify). Um ícone novo será criado no mesmo estilo dos atuais.

| Rede | Link |
|---|---|
|  |  |

---

## 2. Onde os links ficam no código

Os ícones estão no bloco `<nav class="redes">` do cabeçalho, em `index.html`. Cada rede é um link com o nome em `aria-label`; basta trocar o `href="#"` pelo endereço:

```html
<a href="#" target="_blank" rel="noopener" aria-label="Instagram" title="Instagram">…</a>
```

vira

```html
<a href="https://www.instagram.com/perfil" target="_blank" rel="noopener" aria-label="Instagram" title="Instagram">…</a>
```

Os links abrem em uma nova aba (`target="_blank"`). Para remover uma rede, apague a linha `<a …>…</a>` inteira dela.

---

## 3. Conferência

Depois de aplicar os links, abra o site, clique em cada ícone e confira se:

- a página aberta é o perfil **oficial** da CDL Cuiabá;
- o link do WhatsApp abre a conversa com o número certo.
