@echo off
REM Скрипт для запуска Flutter приложения в режиме разработки с Hot Reload
echo 🚀 Запуск Flutter приложения в режиме разработки...
echo 📱 Hot Reload будет доступен автоматически!
echo.
echo 💡 Подсказки:
echo    - Нажмите 'r' в терминале для Hot Reload
echo    - Нажмите 'R' для Hot Restart
echo    - Нажмите 'q' для выхода
echo    - Или просто сохраните файл (Ctrl+S) - изменения применятся автоматически!
echo.

set TARGET=%1
if /I "%TARGET%"=="device" (
  echo ✅ Режим: реальный телефон (используем dart_defines_device.json)
  flutter run --debug --dart-define-from-file=dart_defines_device.json
) else (
  echo ✅ Режим: эмулятор Android (используем dart_defines_emulator.json)
  flutter run --debug --dart-define-from-file=dart_defines_emulator.json
)
