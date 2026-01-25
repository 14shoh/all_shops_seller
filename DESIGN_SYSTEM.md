# Единая система дизайна

## Обзор

Все экраны приложения теперь используют единую систему дизайна с консистентными шрифтами, цветами, отступами и скруглениями.

## Основные компоненты

### 1. Тема приложения (`AppTheme`)

**Расположение:** `lib/core/theme/app_theme.dart`

- Единая типографика для всех текстов
- Консистентная цветовая палитра
- Стандартизированные размеры отступов и скруглений

### 2. Переиспользуемые виджеты (`AppWidgets`)

**Расположение:** `lib/core/widgets/app_widgets.dart`

- `ScreenHeader` - заголовок экрана с иконкой
- `AppCard` - карточка с единым стилем
- `GradientButton` - кнопка с градиентом
- `AppTextField` - поле ввода с единым стилем
- `SectionHeader` - заголовок секции

## Использование

### Заголовок экрана

```dart
ScreenHeader(
  title: 'Название экрана',
  subtitle: 'Подзаголовок',
  icon: Icons.icon_name,
  iconColor: AppTheme.primaryColor,
)
```

### Карточка

```dart
AppCard(
  padding: const EdgeInsets.all(AppTheme.paddingMD),
  onTap: () {},
  child: YourContent(),
)
```

### Кнопка с градиентом

```dart
GradientButton(
  text: 'Сохранить',
  onPressed: () {},
  icon: Icons.save_rounded,
)
```

### Поле ввода

```dart
AppTextField(
  controller: controller,
  label: 'Название поля',
  prefixIcon: Icons.icon_name,
)
```

## Константы

### Отступы
- `AppTheme.paddingXS` = 8.0
- `AppTheme.paddingSM` = 12.0
- `AppTheme.paddingMD` = 16.0
- `AppTheme.paddingLG` = 20.0
- `AppTheme.paddingXL` = 24.0

### Скругления
- `AppTheme.radiusSM` = 12.0
- `AppTheme.radiusMD` = 16.0
- `AppTheme.radiusLG` = 20.0
- `AppTheme.radiusXL` = 24.0

### Цвета
- `AppTheme.primaryColor` - основной цвет
- `AppTheme.successColor` - цвет успеха
- `AppTheme.errorColor` - цвет ошибки
- `AppTheme.textPrimary` - основной текст
- `AppTheme.textSecondary` - второстепенный текст
- `AppTheme.backgroundPrimary` - фон экрана
- `AppTheme.surfaceColor` - цвет карточек

## Типографика

Все тексты используют стили из `Theme.of(context).textTheme`:

- `displayLarge/Medium/Small` - крупные заголовки
- `headlineLarge/Medium/Small` - заголовки экранов
- `titleLarge/Medium/Small` - заголовки карточек
- `bodyLarge/Medium/Small` - основной текст
- `labelLarge/Medium/Small` - метки и подписи

Или готовые стили из `AppTheme`:
- `AppTheme.screenTitle` - заголовок экрана
- `AppTheme.screenSubtitle` - подзаголовок экрана
- `AppTheme.cardTitle` - заголовок карточки
- `AppTheme.cardSubtitle` - описание карточки
- `AppTheme.priceText` - текст цены
- `AppTheme.labelText` - текст метки
