# Gera o config.js (na raiz do projeto) a partir do .env.
# O config.js é lido por vagas/oportunidade.html e vai para o Git (o GitHub Pages precisa dele),
# por isso o script recusa chaves secretas: só a publishable/anon do Supabase pode ir para o navegador.
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

# Trava: o config.js é público, então a chave precisa ser a publishable/anon.
$chave = $env_['SUPABASE_ANON_KEY']
$ehSecreta = $chave -like 'sb_secret_*'
if (-not $ehSecreta -and $chave -like 'eyJ*') {
    try {
        $p = $chave.Split('.')[1].Replace('-', '+').Replace('_', '/')
        while ($p.Length % 4) { $p += '=' }
        $ehSecreta = ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($p)) | ConvertFrom-Json).role -ne 'anon'
    } catch { $ehSecreta = $true }
}
if ($ehSecreta) { throw 'SUPABASE_ANON_KEY no .env é uma chave secreta. Use a chave publishable/anon (Project Settings > API).' }

$config = [ordered]@{}
foreach ($c in $chaves) { $config[$c] = $env_[$c] }

$conteudo = "// Gerado por scripts/gerar_config.ps1 a partir do .env. Não edite à mão; contém só a chave pública.`n" +
            "window.APP_CONFIG = $($config | ConvertTo-Json);`n"

$destino = Join-Path $raiz 'config.js'
# UTF-8 sem BOM (o Set-Content do PowerShell 5.1 gravaria em ANSI).
[IO.File]::WriteAllText($destino, $conteudo, (New-Object Text.UTF8Encoding $false))
Write-Host "config.js gerado em $destino"
