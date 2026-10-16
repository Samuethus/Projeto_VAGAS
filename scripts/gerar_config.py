"""Gera o config.js (na raiz do projeto) a partir do .env.

O config.js fica fora do Git (ver .gitignore) e é lido por vagas/oportunidade.html.
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
        "// Gerado por scripts/gerar_config.py a partir do .env. Não edite nem envie ao Git.\n"
        f"window.APP_CONFIG = {json.dumps(config, indent=2)};\n",
        encoding="utf-8",
    )
    print(f"config.js gerado em {destino}")


if __name__ == "__main__":
    main()
