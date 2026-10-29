# Exporta as vagas do Firestore (projeto antigo) para supabase/migracao_firebase.sql, mantendo IDs e datas.
# Depois de rodar o supabase/schema.sql, cole o arquivo gerado no SQL Editor do Supabase e clique em Run.
# Pode ser rodado de novo: vagas que já estão no Supabase são ignoradas (on conflict do nothing).
#
# Só as vagas ATIVAS são lidas: as regras do Firestore escondem as inativas e todas as candidaturas
# (elas só saem com uma conta de serviço, pelo Console do Firebase).
# Uso (na raiz do projeto):  powershell -ExecutionPolicy Bypass -File scripts\migrar_firebase.ps1

$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$projeto = 'projeto-vagas-3e07a'
$apiKey = 'AIzaSyBAdGP5s3Qb-_VM8TBP_knYAnrj0Kd2hY8'   # apiKey web (pública) do Firebase antigo
$colunas = 'id', 'cargo', 'empresa', 'tipo_contrato', 'modalidade', 'local', 'quantidade', 'remuneracao', 'carga_horaria',
           'inicio', 'termino', 'descricao', 'requisitos', 'beneficios', 'whatsapp', 'ativa', 'created_at'

$consulta = '{"structuredQuery":{"from":[{"collectionId":"vagas"}],"where":{"fieldFilter":{"field":{"fieldPath":"ativa"},"op":"EQUAL","value":{"booleanValue":true}}}}}'
$url = "https://firestore.googleapis.com/v1/projects/$projeto/databases/(default)/documents:runQuery?key=$apiKey"
# Invoke-RestMethod do PowerShell 5.1 decodifica a resposta como ANSI; lendo os bytes, os acentos chegam certos.
$resposta = Invoke-WebRequest $url -Method Post -Body $consulta -ContentType 'application/json' -UseBasicParsing
$json = [Text.Encoding]::UTF8.GetString($resposta.RawContentStream.ToArray()) | ConvertFrom-Json
$documentos = @($json | Where-Object { $_.document } | ForEach-Object { $_.document })

# Valor do Firestore -> literal SQL.
function Literal($valor) {
    if ($null -eq $valor -or $valor.PSObject.Properties.Name -contains 'nullValue') { return 'null' }
    if ($valor.PSObject.Properties.Name -contains 'booleanValue') { return $(if ($valor.booleanValue) { 'true' } else { 'false' }) }
    if ($valor.PSObject.Properties.Name -contains 'integerValue') { return [string][long]$valor.integerValue }
    $texto = if ($valor.PSObject.Properties.Name -contains 'timestampValue') { $valor.timestampValue } else { [string]$valor.stringValue }
    # Quebras de linha viram escapes (E'...\n...'): colar no SQL Editor pelo Windows trocaria LF por CRLF,
    # aumentando o tamanho do texto e podendo estourar os limites de caracteres.
    $texto = $texto.Replace('\', '\\').Replace("'", "''").Replace("`r", '\r').Replace("`n", '\n')
    return "E'" + $texto + "'"
}

$linhas = foreach ($d in $documentos) {
    $campos = $d.fields
    $valores = foreach ($c in $colunas) {
        if ($c -eq 'id') { "'" + ($d.name -split '/')[-1].Replace("'", "''") + "'" }
        elseif ($c -eq 'created_at' -and -not $campos.created_at) { "'" + $d.createTime + "'" }
        else { Literal $campos.$c }
    }
    "  (" + ($valores -join ', ') + ")"
}

$destino = Join-Path $raiz 'supabase\migracao_firebase.sql'
if (-not $documentos) {
    Write-Host 'Nenhuma vaga ativa encontrada no Firestore. Nada a migrar.'
    exit 0
}
$conteudo = "-- Gerado por scripts/migrar_firebase.ps1 em $(Get-Date -Format 'yyyy-MM-dd HH:mm'): $($documentos.Count) vaga(s) ativa(s) do Firestore.`n" +
            "-- Rode DEPOIS do supabase/schema.sql, no SQL Editor do Supabase.`n" +
            "insert into public.vagas ($($colunas -join ', ')) values`n" +
            ($linhas -join ",`n") + "`non conflict (id) do nothing;`n"
[IO.File]::WriteAllText($destino, $conteudo, (New-Object Text.UTF8Encoding $false))
Write-Host "$($documentos.Count) vaga(s) exportada(s) para $destino"
