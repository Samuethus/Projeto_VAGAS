# Gera o config.js (na raiz do projeto) a partir do .env.
# O config.js é lido por vagas/oportunidade.html e vai para o Git (o GitHub Pages precisa dele),
# por isso o script recusa chaves de servidor: só a chave PUBLISHABLE (ou anon) do Supabase pode ir para o navegador.
# Uso (na raiz do projeto):  powershell -ExecutionPolicy Bypass -File scripts\gerar_config.ps1

$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$arquivoEnv = Join-Path $raiz '.env'
$chaves = 'SUPABASE_URL', 'SUPABASE_KEY'

if (-not (Test-Path $arquivoEnv)) { throw "Arquivo .env não encontrado em $raiz (copie o .env.example)" }

$env_ = @{}
foreach ($linha in Get-Content $arquivoEnv -Encoding UTF8) {
    $linha = $linha.Trim().TrimStart([char]0xFEFF)
    if (-not $linha -or $linha.StartsWith('#') -or -not $linha.Contains('=')) { continue }
    $chave, $valor = $linha.Split('=', 2)
    $env_[$chave.Trim()] = $valor.Trim().Trim('"').Trim("'")
}

$faltando = $chaves | Where-Object { -not $env_[$_] }
if ($faltando) { throw "Preencha no .env: $($faltando -join ', ')" }

if ($env_['SUPABASE_URL'] -notmatch '^https://[^/]+$' -and $env_['SUPABASE_URL'] -notmatch '^https://[^/]+/$') {
    throw 'SUPABASE_URL no .env deve ser só o endereço do projeto, como https://abcdefgh.supabase.co'
}

# Trava: o config.js é público. A chave secret (sb_secret_...) ou service_role ignora as permissões do banco
# e nunca pode ir para o navegador.
$key = $env_['SUPABASE_KEY']
$papel = $null
if ($key.Split('.').Count -eq 3) {
    try {
        $p = $key.Split('.')[1].Replace('-', '+').Replace('_', '/'); while ($p.Length % 4) { $p += '=' }
        $papel = ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($p)) | ConvertFrom-Json).role
    } catch { }
}
if ($key -like 'sb_secret_*' -or $papel -eq 'service_role') {
    throw 'SUPABASE_KEY no .env é uma chave SECRETA. Use a chave publishable (Project Settings > API Keys).'
}
if ($key -notlike 'sb_publishable_*' -and $papel -ne 'anon') {
    throw 'SUPABASE_KEY no .env não parece a chave publishable do Supabase (deveria começar com "sb_publishable_").'
}

$config = [ordered]@{}
foreach ($c in $chaves) { $config[$c] = $env_[$c].TrimEnd('/') }

$conteudo = "// Gerado por scripts/gerar_config.ps1 a partir do .env. Não edite à mão; contém só a configuração pública do Supabase.`n" +
            "window.APP_CONFIG = $($config | ConvertTo-Json);`n"

$destino = Join-Path $raiz 'config.js'
# UTF-8 sem BOM (o Set-Content do PowerShell 5.1 gravaria em ANSI).
[IO.File]::WriteAllText($destino, $conteudo, (New-Object Text.UTF8Encoding $false))
Write-Host "config.js gerado em $destino"
