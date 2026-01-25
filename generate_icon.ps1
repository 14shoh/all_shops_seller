# PowerShell script to generate icon from SVG
# Requires: Inkscape or ImageMagick

Write-Host "Генерация иконки приложения..." -ForegroundColor Green

$svgPath = "assets/icon_scanner.svg"
$pngPath = "assets/icon_scanner.png"

# Check if SVG exists
if (-not (Test-Path $svgPath)) {
    Write-Host "Ошибка: Файл $svgPath не найден!" -ForegroundColor Red
    exit 1
}

# Try to use Inkscape
$inkscape = Get-Command inkscape -ErrorAction SilentlyContinue
if ($inkscape) {
    Write-Host "Используется Inkscape для конвертации..." -ForegroundColor Yellow
    & inkscape -w 1024 -h 1024 "$svgPath" -o "$pngPath"
    if (Test-Path $pngPath) {
        Write-Host "✓ Иконка успешно создана: $pngPath" -ForegroundColor Green
        Write-Host "Теперь выполните: flutter pub run flutter_launcher_icons" -ForegroundColor Cyan
        exit 0
    }
}

# Try to use ImageMagick
$magick = Get-Command magick -ErrorAction SilentlyContinue
if ($magick) {
    Write-Host "Используется ImageMagick для конвертации..." -ForegroundColor Yellow
    & magick -density 300 "$svgPath" -resize 1024x1024 "$pngPath"
    if (Test-Path $pngPath) {
        Write-Host "✓ Иконка успешно создана: $pngPath" -ForegroundColor Green
        Write-Host "Теперь выполните: flutter pub run flutter_launcher_icons" -ForegroundColor Cyan
        exit 0
    }
}

Write-Host "Внимание: Inkscape или ImageMagick не найдены!" -ForegroundColor Yellow
Write-Host "Пожалуйста, используйте один из следующих методов:" -ForegroundColor Yellow
Write-Host "1. Установите Inkscape: https://inkscape.org/release/" -ForegroundColor Cyan
Write-Host "2. Установите ImageMagick: https://imagemagick.org/script/download.php" -ForegroundColor Cyan
Write-Host "3. Используйте онлайн конвертер: https://convertio.co/svg-png/" -ForegroundColor Cyan
Write-Host "4. Откройте assets/icon_scanner.html в браузере для автоматической конвертации" -ForegroundColor Cyan
