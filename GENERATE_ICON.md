# Генерация иконки приложения

## Шаг 1: Создание PNG иконки

1. Откройте файл `assets/icon_scanner.html` в браузере
2. Иконка автоматически скачается как `icon_scanner.png`
3. Переместите скачанный файл в папку `assets/`

Или используйте онлайн конвертер SVG в PNG:
- https://convertio.co/svg-png/
- https://cloudconvert.com/svg-to-png

Загрузите `assets/icon_scanner.svg` и скачайте PNG размером 1024x1024 пикселей.

## Шаг 2: Установка зависимостей

```bash
cd seller
flutter pub get
```

## Шаг 3: Генерация иконок

```bash
flutter pub run flutter_launcher_icons
```

Или используйте:

```bash
dart run flutter_launcher_icons
```

## Шаг 4: Пересборка приложения

```bash
flutter clean
flutter pub get
flutter run
```

Иконка сканера штрих-кода будет установлена для Android и iOS!
