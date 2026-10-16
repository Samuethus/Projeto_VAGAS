"""Gera o config.js (na raiz do projeto) a partir do .env.

Versão principal: scripts/gerar_config.ps1 (que também recusa chaves secretas).
O config.js vai para o Git: use só a chave publishable/anon do Supabase.
Uso:  python scripts/gerar_config.py
"""
import json
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
CHAVES = ("SUPABASE_URL", "SUPABASE_ANON_KEY")


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
    env = ler_env(RAIZ / ".env")
    faltando = [c for c in CHAVES if not env.get(c)]
    if faltando:
        raise SystemExit(f"Preencha no .env: {', '.join(faltando)}")

    config = {c: env[c] for c in CHAVES}
    destino = RAIZ / "config.js"
    destino.write_text(
        "// Gerado por scripts/gerar_config.py a partir do .env. Não edite à mão; contém só a chave pública.\n"
        f"window.APP_CONFIG = {json.dumps(config, indent=2)};\n",
        encoding="utf-8",
    )
    print(f"config.js gerado em {destino}")


if __name__ == "__main__":
    main()
