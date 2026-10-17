# Gera o config.js (na raiz do projeto) a partir do .env.
# O config.js é lido por vagas/oportunidade.html e vai para o Git (o GitHub Pages precisa dele),
# por isso o script recusa credenciais de servidor: só a configuração WEB do Firebase pode ir para o navegador.
# Uso (na raiz do projeto):  powershell -ExecutionPolicy Bypass -File scripts\gerar_config.ps1

$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$arquivoEnv = Join-Path $raiz '.env'
$obrigatorias = 'FIREBASE_API_KEY', 'FIREBASE_PROJECT_ID', 'FIREBASE_APP_ID'
$opcionais = @('FIREBASE_AUTH_DOMAIN')

if (-not (Test-Path $arquivoEnv)) { throw "Arquivo .env não encontrado em $raiz (copie o .env.example)" }

$env_ = @{}
foreach ($linha in Get-Content $arquivoEnv -Encoding UTF8) {
    $linha = $linha.Trim().TrimStart([char]0xFEFF)
    if (-not $linha -or $linha.StartsWith('#') -or -not $linha.Contains('=')) { continue }
    $chave, $valor = $linha.Split('=', 2)
    $env_[$chave.Trim()] = $valor.Trim().Trim('"').Trim("'")
}

$faltando = $obrigatorias | Where-Object { -not $env_[$_] }
if ($faltando) { throw "Preencha no .env: $($faltando -join ', ')" }

# Trava: o config.js é público. A apiKey web do Firebase começa com "AIza" e não dá acesso de administrador;
# chave privada de conta de serviço (BEGIN PRIVATE KEY / private_key) nunca pode ir para o navegador.
$chaves = $obrigatorias + $opcionais
foreach ($c in $chaves) {
    if ($env_[$c] -match 'PRIVATE KEY|private_key|client_email') { throw "$c no .env parece credencial de conta de serviço. Use a configuração do app WEB (Configurações do projeto > Seus apps)." }
}
if ($env_['FIREBASE_API_KEY'] -notlike 'AIza*') { throw 'FIREBASE_API_KEY no .env não parece a apiKey web do Firebase (deveria começar com "AIza").' }

$config = [ordered]@{}
foreach ($c in $chaves) { if ($env_[$c]) { $config[$c] = $env_[$c] } }

$conteudo = "// Gerado por scripts/gerar_config.ps1 a partir do .env. Não edite à mão; contém só a configuração web (pública) do Firebase.`n" +
            "window.APP_CONFIG = $($config | ConvertTo-Json);`n"

$destino = Join-Path $raiz 'config.js'
# UTF-8 sem BOM (o Set-Content do PowerShell 5.1 gravaria em ANSI).
[IO.File]::WriteAllText($destino, $conteudo, (New-Object Text.UTF8Encoding $false))
Write-Host "config.js gerado em $destino"
