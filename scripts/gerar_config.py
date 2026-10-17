"""Gera o config.js (na raiz do projeto) a partir do .env.

Versão principal: scripts/gerar_config.ps1. As duas recusam credenciais de conta de serviço.
O config.js vai para o Git: use só a configuração WEB do Firebase.
Uso:  python scripts/gerar_config.py
"""
import json
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
OBRIGATORIAS = ("FIREBASE_API_KEY", "FIREBASE_PROJECT_ID", "FIREBASE_APP_ID")
OPCIONAIS = ("FIREBASE_AUTH_DOMAIN",)


def ler_env(caminho: Path) -> dict:
    valores = {}
    for linha in caminho.read_text(encoding="utf-8-sig").splitlines():
        linha = linha.strip()
        if not linha or linha.startswith("#") or "=" not in linha:
            continue
        chave, valor = linha.split("=", 1)
        valores[chave.strip()] = valor.strip().strip('"').strip("'")
    return valores


def main() -> None:
    caminho_env = RAIZ / ".env"
    if not caminho_env.exists():
        raise SystemExit(f"Arquivo .env não encontrado em {RAIZ} (copie o .env.example)")
    env = ler_env(caminho_env)
    faltando = [c for c in OBRIGATORIAS if not env.get(c)]
    if faltando:
        raise SystemExit(f"Preencha no .env: {', '.join(faltando)}")

    chaves = OBRIGATORIAS + OPCIONAIS
    for c in chaves:
        if any(t in env.get(c, "") for t in ("PRIVATE KEY", "private_key", "client_email")):
            raise SystemExit(f"{c} no .env parece credencial de conta de serviço. Use a configuração do app WEB.")
    if not env["FIREBASE_API_KEY"].startswith("AIza"):
        raise SystemExit('FIREBASE_API_KEY no .env não parece a apiKey web do Firebase (deveria começar com "AIza").')

    config = {c: env[c] for c in chaves if env.get(c)}
    destino = RAIZ / "config.js"
    destino.write_text(
        "// Gerado por scripts/gerar_config.py a partir do .env. Não edite à mão; contém só a configuração web (pública) do Firebase.\n"
        f"window.APP_CONFIG = {json.dumps(config, indent=2)};\n",
        encoding="utf-8",
    )
    print(f"config.js gerado em {destino}")


if __name__ == "__main__":
    main()
