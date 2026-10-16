# Gera o config.js (na raiz do projeto) a partir do .env.
# O config.js fica fora do Git (ver .gitignore) e é lido por vagas/oportunidade.html.
# Uso (na raiz do projeto):  powershell -ExecutionPolicy Bypass -File scripts\gerar_config.ps1

$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$arquivoEnv = Join-Path $raiz '.env'
$chaves = 'SUPABASE_URL', 'SUPABASE_ANON_KEY'

if (-not (Test-Path $arquivoEnv)) { throw "Arquivo .env não encontrado em $raiz" }

$env_ = @{}
foreach ($linha in Get-Content $arquivoEnv -Encoding UTF8) {
    $linha = $linha.Trim().TrimStart([char]0xFEFF)
    if (-not $linha -or $linha.StartsWith('#') -or -not $linha.Contains('=')) { continue }
    $chave, $valor = $linha.Split('=', 2)
    $env_[$chave.Trim()] = $valor.Trim().Trim('"').Trim("'")
}

$faltando = $chaves | Where-Object { -not $env_[$_] }
if ($faltando) { throw "Preencha no .env: $($faltando -join ', ')" }

$config = [ordered]@{}
foreach ($c in $chaves) { $config[$c] = $env_[$c] }

$conteudo = "// Gerado por scripts/gerar_config.ps1 a partir do .env. Não edite nem envie ao Git.`n" +
            "window.APP_CONFIG = $($config | ConvertTo-Json);`n"

$destino = Join-Path $raiz 'config.js'
# UTF-8 sem BOM (o Set-Content do PowerShell 5.1 gravaria em ANSI).
[IO.File]::WriteAllText($destino, $conteudo, (New-Object Text.UTF8Encoding $false))
Write-Host "config.js gerado em $destino"
