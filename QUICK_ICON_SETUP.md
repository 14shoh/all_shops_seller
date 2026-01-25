# Быстрая установка иконки

## Самый простой способ:

1. **Откройте в браузере:** `assets/icon_scanner.html`
   - Иконка автоматически скачается как PNG
   - Переместите файл в папку `assets/` и переименуйте в `icon_scanner.png`

2. **Или используйте онлайн конвертер:**
   - Перейдите на https://convertio.co/svg-png/
   - Загрузите `assets/icon_scanner.svg`
   - Установите размер: **1024x1024 пикселей**
   - Скачайте и сохраните как `assets/icon_scanner.png`

3. **Сгенерируйте иконки:**
   ```bash
   flutter pub run flutter_launcher_icons
   ```

4. **Готово!** Перезапустите приложение.

---

## Альтернативный способ (если установлен Inkscape):

```bash
inkscape -w 1024 -h 1024 assets/icon_scanner.svg -o assets/icon_scanner.png
flutter pub run flutter_launcher_icons
```
