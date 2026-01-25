# Скрипт для запуска Flutter приложения в режиме разработки с Hot Reload
param(
  [ValidateSet('emulator', 'device')]
  [string]$Target = 'emulator',
  [int]$Port = 3000
)

Write-Host "🚀 Запуск Flutter приложения в режиме разработки..." -ForegroundColor Green
Write-Host "📱 Hot Reload будет доступен автоматически!" -ForegroundColor Cyan
Write-Host ""
Write-Host "💡 Подсказки:" -ForegroundColor Yellow
Write-Host "   - Нажмите 'r' в терминале для Hot Reload" -ForegroundColor Gray
Write-Host "   - Нажмите 'R' для Hot Restart" -ForegroundColor Gray
Write-Host "   - Нажмите 'q' для выхода" -ForegroundColor Gray
Write-Host "   - Или просто сохраните файл (Ctrl+S) - изменения применятся автоматически!" -ForegroundColor Gray
Write-Host ""

$defineFile = if ($Target -eq 'device') { 'dart_defines_device.json' } else { 'dart_defines_emulator.json' }

if ($Target -eq 'device') {
  # Автоматически берём IPv4 ПК (активный интерфейс с Default Gateway)
  $ip = $null
  try {
    $cfg = Get-NetIPConfiguration |
      Where-Object { $_.IPv4DefaultGateway -ne $null -and $_.NetAdapter.Status -eq 'Up' } |
      Select-Object -First 1
    if ($cfg -and $cfg.IPv4Address -and $cfg.IPv4Address.IPAddress) {
      $ip = $cfg.IPv4Address.IPAddress
    }
  } catch { }

  if (-not $ip) {
    # Фоллбек: парсим ipconfig
    try {
      $ip = (ipconfig | Select-String -Pattern 'IPv4 Address' -SimpleMatch | Select-Object -First 1).ToString().Split(':')[-1].Trim()
    } catch { }
  }

  if ($ip) {
    $url = "http://$ip`:$Port"
    @{ API_BASE_URL = $url } | ConvertTo-Json | Set-Content -Path $defineFile -Encoding UTF8
    Write-Host "✅ API_BASE_URL для телефона: $url" -ForegroundColor Green
  } else {
    Write-Host "⚠️ Не смог автоматически определить IPv4. Проверь ipconfig и обнови $defineFile" -ForegroundColor Yellow
  }
} else {
  Write-Host "✅ API_BASE_URL для эмулятора: http://10.0.2.2:$Port" -ForegroundColor Green
}

flutter run --debug "--dart-define-from-file=$defineFile"
