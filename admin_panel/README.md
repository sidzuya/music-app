# MusicApp Admin Panel

Веб-панель администратора для управления песнями в музыкальном Flutter-приложении.

## Возможности

- **Дашборд** — статистика: кол-во песен, пользователей, плейлистов
- **Список песен** — все треки из bucket `songs` и `featured` с поиском и фильтрацией
- **Загрузка** — форма для загрузки аудиофайлов с обложкой
- **Удаление** — удаление файлов из Storage
- **Перемещение** — перенос песен между `songs` ↔ `featured`
- **Аутентификация** — вход только для пользователей с `role = 'admin'`

## Настройка

### 1. Запустите SQL-миграцию

Откройте SQL Editor в Supabase Dashboard и выполните содержимое:
```
supabase/admin_migration.sql
```

### 2. Назначьте себя администратором

```sql
UPDATE profiles SET role = 'admin' WHERE email = 'ваш-email@example.com';
```

### 3. Создайте bucket `covers` (если миграция не создала)

В Supabase Dashboard → Storage → New Bucket → `covers` → Public.

### 4. Запуск

```bash
cd admin_panel
flutter run -d chrome
```

## Технический стек

- Flutter Web + Material 3
- Supabase (тот же проект что и основное приложение)
- file_picker для выбора файлов
