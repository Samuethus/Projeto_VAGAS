"""Gera o config.js (na raiz do projeto) a partir do .env.

Versão principal: scripts/gerar_config.ps1. As duas recusam chaves secretas do Supabase.
O config.js vai para o Git: use só a chave PUBLISHABLE (ou anon).
Uso:  python scripts/gerar_config.py
"""
import base64
import json
import re
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
CHAVES = ("SUPABASE_URL", "SUPABASE_KEY")


def ler_env(caminho: Path) -> dict:
    valores = {}
    for linha in caminho.read_text(encoding="utf-8-sig").splitlines():
        linha = linha.strip()
        if not linha or linha.startswith("#") or "=" not in linha:
            continue
        chave, valor = linha.split("=", 1)
        valores[chave.strip()] = valor.strip().strip('"').strip("'")
    return valores


def papel_jwt(key: str):
    partes = key.split(".")
    if len(partes) != 3:
        return None
    try:
        payload = partes[1] + "=" * (-len(partes[1]) % 4)
        return json.loads(base64.urlsafe_b64decode(payload)).get("role")
    except ValueError:
        return None


def main() -> None:
    caminho_env = RAIZ / ".env"
    if not caminho_env.exists():
        raise SystemExit(f"Arquivo .env não encontrado em {RAIZ} (copie o .env.example)")
    env = ler_env(caminho_env)
    faltando = [c for c in CHAVES if not env.get(c)]
    if faltando:
        raise SystemExit(f"Preencha no .env: {', '.join(faltando)}")

    if not re.fullmatch(r"https://[^/]+/?", env["SUPABASE_URL"]):
        raise SystemExit("SUPABASE_URL no .env deve ser só o endereço do projeto, como https://abcdefgh.supabase.co")
    key = env["SUPABASE_KEY"]
    papel = papel_jwt(key)
    if key.startswith("sb_secret_") or papel == "service_role":
        raise SystemExit("SUPABASE_KEY no .env é uma chave SECRETA. Use a chave publishable (Project Settings > API Keys).")
    if not key.startswith("sb_publishable_") and papel != "anon":
        raise SystemExit('SUPABASE_KEY no .env não parece a chave publishable do Supabase (deveria começar com "sb_publishable_").')

    config = {c: env[c].rstrip("/") for c in CHAVES}
    destino = RAIZ / "config.js"
    destino.write_text(
        "// Gerado por scripts/gerar_config.py a partir do .env. Não edite à mão; contém só a configuração pública do Supabase.\n"
        f"window.APP_CONFIG = {json.dumps(config, indent=2)};\n",
        encoding="utf-8",
    )
    print(f"config.js gerado em {destino}")


if __name__ == "__main__":
    main()
