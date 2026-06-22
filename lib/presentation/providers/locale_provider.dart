import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider with ChangeNotifier {
  static const String _localeKey = 'selected_locale';

  Locale _locale = const Locale('ru');

  Locale get locale => _locale;

  final Map<String, Map<String, String>> _localizedStrings = {
    'ru': {
      // Navigation
      'home': 'Главная',
      'search': 'Поиск',
      'ai_playlist': 'AI',
      'library': 'Библиотека',
      'profile': 'Профиль',

      // Authentication
      'welcome_back': 'Добро пожаловать',
      'sign_in_subtitle': 'Войдите, чтобы продолжить слушать',
      'email': 'Email',
      'password': 'Пароль',
      'username': 'Имя пользователя',
      'sign_in': 'Войти',
      'create_account': 'Создать аккаунт',
      'register': 'Регистрация',
      'join_millions': 'Присоединяйтесь к миллионам меломанов',

      // Home
      'good_morning': 'Доброе утро',
      'good_afternoon': 'Добрый день',
      'good_evening': 'Добрый вечер',
      'recently_played': 'Недавние',
      'nothing_listened': 'Вы ещё ничего не слушали',
      'popular_right_now': 'Популярное сейчас',
      'quick_access': 'Быстрый доступ',
      'liked_songs': 'Избранные',
      'downloaded': 'Скачанные',
      'made_for_you': 'Для вас',
      'just_for_you': 'Только для тебя',
      'show_all': 'Показать все',
      'ai_mixes': 'AI Миксы',
      'personalized_for_you': 'Персонально для тебя',
      'ai_mixes_description':
          'Миксы собираются из истории прослушиваний, любимых треков, жанров и артистов.',
      'start_listening_for_ai':
          'Включи несколько треков, и AI начнет собирать миксы',
      'ai_empty_state':
          'Когда приложение увидит твои любимые жанры и артистов, здесь появятся персональные рекомендации.',

      // Search
      'search_placeholder': 'Что хотите послушать?',
      'browse_all': 'Просмотреть всё',
      'no_results': 'Результатов не найдено',
      'try_different_search': 'Попробуйте другой запрос',
      'ai_playlist_prompt_title': 'AI плейлист',
      'ai_playlist_prompt_subtitle':
          'Напиши запрос вроде: "сделай мне грустный ночной плейлист" или "подбери мягкий lo-fi для учебы".',
      'ai_playlist_where_to_type': 'Скажи это AI в поле ниже:',
      'ai_playlist_prompt_hint':
          'Например: сделай мне грустный ночной плейлист с dream pop и indie',
      'generate_ai_playlist': 'Создать плейлист с AI',
      'generating_ai_playlist': 'AI собирает плейлист...',
      'openai_key_missing':
          'AI сейчас не подключён. Добавь Google AI Studio key выше, если хочешь заменить встроенную конфигурацию.',
      'ai_playlist_results': 'AI сгенерировал для тебя',
      'play_ai_playlist': 'Слушать плейлист',
      'save_ai_playlist': 'Сохранить как плейлист',
      'playlist_saved': 'сохранён в плейлисты',
      'ai_playlist_steps':
          '1. Напиши, какой плейлист хочешь  2. AI учтёт твои лайки и историю  3. Нажми кнопку ниже',
      'openai_key_label': 'Google AI Studio key',
      'openai_key_hint':
          'Вставь сюда свой Gemini API key, если хочешь заменить встроенный',
      'save_openai_key': 'Сохранить ключ',
      'openai_key_saved': 'Google AI Studio key сохранён локально',
      'openai_key_connected': 'Gemini подключён',
      'change': 'Изменить',
      'ai_example_1': 'сделай мне грустный ночной плейлист',
      'ai_example_2': 'подбери спокойный lo-fi для учебы',
      'ai_example_3': 'собери энергичный вечерний микс для тренировки',

      // Library
      'your_library': 'Ваша библиотека',
      'create_playlist': 'Создать плейлист',
      'playlist_help': 'Это легко, мы поможем',
      'playlists': 'Плейлисты',
      'no_playlists': 'Пока нет плейлистов',
      'create_first_playlist': 'Создайте свой первый плейлист',
      'no_liked_songs': 'Нет любимых песен',
      'liked_songs_help': 'Понравившиеся песни появятся здесь',

      // Settings
      'settings': 'Настройки',
      'account': 'Аккаунт',
      'account_subtitle': 'Приватность, безопасность, изменение email',
      'notifications': 'Уведомления',
      'notifications_subtitle': 'Музыкальные рекомендации, новые релизы',
      'storage': 'Хранилище',
      'storage_subtitle': 'Скачанная музыка, кэш',
      'display': 'Оформление',
      'display_subtitle': 'Тема, внешний вид',
      'playback': 'Воспроизведение',
      'playback_subtitle': 'Кроссфейд, эквалайзер',
      'admin_panel': 'Админ-панель',
      'admin_panel_subtitle': 'Управление песнями и загрузками',
      'checking_admin_access': 'Проверяем права администратора...',
      'admin_access_denied': 'У вас нет полномочий для доступа к админ-панели',
      'help_support': 'Помощь и поддержка',
      'help_support_subtitle': 'FAQ, связаться с нами',
      'about': 'О приложении',
      'about_subtitle': 'Версия, условия, политика конфиденциальности',
      'logout': 'Выйти',

      // Display Settings
      'theme': 'Тема',
      'dark_theme': 'Тёмная',
      'light_theme': 'Светлая',
      'auto_theme': 'Авто',
      'recommended': 'Рекомендуется',
      'classic': 'Классическая',
      'follows_system': 'Следует системе',
      'accent_color': 'Акцентный цвет',
      'green': 'Зелёный',
      'blue': 'Синий',
      'purple': 'Фиолетовый',
      'red': 'Красный',
      'orange': 'Оранжевый',
      'language': 'Язык',
      'text_size': 'Размер текста',
      'small': 'Маленький',
      'large': 'Большой',
      'show_album_art': 'Показывать обложки альбомов',
      'show_album_art_subtitle': 'Отображать изображения в списках',
      'animations': 'Анимации',
      'animations_subtitle': 'Включить плавные переходы и эффекты',
      'preview': 'Предварительный просмотр',
      'sample_song': 'Название песни',
      'sample_artist': 'Исполнитель',

      // Music Player
      'playing_from': 'ВОСПРОИЗВОДИТСЯ ИЗ',
      'add_to_favorites': 'Добавить в любимые',
      'remove_from_favorites': 'Убрать из любимых',
      'add_to_playlist': 'Добавить в плейлист',
      'share': 'Поделиться',
      'go_to_album': 'Перейти к альбому',
      'go_to_artist': 'Перейти к исполнителю',

      // Common
      'save': 'Сохранить',
      'cancel': 'Отмена',
      'ok': 'OK',
      'edit': 'Изменить',
      'delete': 'Удалить',
      'coming_soon': 'Скоро',
      'coming_soon_message':
          'Эта функция будет доступна в следующих обновлениях',
      'songs': 'песен',
      'browse_all': 'Просмотреть всё',

      // Profile
      'settings': 'Настройки',
      'edit_profile': 'Редактировать профиль',
      'playlists': 'Плейлисты',
      'following': 'Подписки',
      'followers': 'Подписчики',
      'friends': 'Друзья',
      'follow': 'Подписаться',
      'following_button': 'Вы подписаны',
      'friends_button': 'Вы друзья',
      'find_users': 'Найти людей',
      'search_users_hint': 'Имя или email',
      'search_users_prompt': 'Начните вводить, чтобы найти друзей',
      'no_users_found': 'Пользователи не найдены',
      'no_users_yet': 'Пока пусто',
      'section_profiles': 'Профили',
      'section_artists': 'Исполнители',
      'section_playlists': 'Плейлисты',
      'section_songs': 'Песни',
      'account': 'Аккаунт',
      'account_subtitle': 'Приватность, безопасность, изменение email',
      'notifications': 'Уведомления',
      'notifications_subtitle': 'Музыкальные рекомендации, новые релизы',
      'storage': 'Хранилище',
      'storage_subtitle': 'Скачанная музыка, кэш',
      'display_subtitle': 'Тема, внешний вид',
      'playback': 'Воспроизведение',
      'playback_subtitle': 'Кроссфейд, эквалайзер',
      'help_support': 'Помощь и поддержка',
      'help_support_subtitle': 'FAQ, связаться с нами',
      'about_app': 'О приложении',
      'about_app_subtitle': 'Версия, условия, политика конфиденциальности',
      'logout': 'Выйти',
      'logout_title': 'Выход',
      'logout_message': 'Вы уверены, что хотите выйти?',
      'app_description':
          'Красивое музыкальное приложение, вдохновлённое Spotify. Создано с помощью Flutter.',

      // Edit Profile Screen
      'profile_info': 'Информация о профиле',
      'profile_info_description':
          'Ваше имя пользователя видно другим пользователям. Email используется для входа и не может быть изменён.',
      'profile_updated': 'Профиль успешно обновлён',
      'username_required': 'Введите имя пользователя',
      'email_cannot_be_changed': 'Email нельзя изменить',
      'take_photo': 'Сделать фото',
      'choose_from_gallery': 'Выбрать из галереи',
      'remove_photo': 'Удалить фото',

      // Playlist Detail Screen
      'play_all': 'Воспроизвести',
      'edit_playlist': 'Редактировать плейлист',
      'delete_playlist': 'Удалить плейлист',
      'delete_playlist_confirm':
          'Вы уверены, что хотите удалить этот плейлист?',
      'playlist_empty': 'Плейлист пуст',
      'playlist_empty_help': 'Добавьте песни через меню песни',

      // Notifications Settings
      'general_settings': 'Основные настройки',
      'push_notifications': 'Push-уведомления',
      'push_notifications_desc': 'Получать уведомления на устройство',
      'email_notifications': 'Email-уведомления',
      'email_notifications_desc': 'Получать уведомления на почту',
      'music_notifications': 'Музыкальные уведомления',
      'new_releases': 'Новые релизы',
      'new_releases_desc': 'Уведомления о новых альбомах любимых артистов',
      'recommendations_desc': 'Персональные музыкальные рекомендации',
      'playlist_updates': 'Обновления плейлистов',
      'playlist_updates_desc': 'Когда в ваши плейлисты добавляют песни',
      'concert_alerts': 'Концерты и события',
      'concert_alerts_desc': 'Уведомления о концертах любимых артистов',
      'social_notifications': 'Социальные уведомления',
      'friend_activity': 'Активность друзей',
      'friend_activity_desc': 'Что слушают ваши друзья',
      'sound_vibration': 'Звук и вибрация',
      'notification_sound': 'Звук уведомлений',
      'notification_sound_desc': 'Воспроизводить звук при уведомлениях',
      'vibration': 'Вибрация',
      'vibration_desc': 'Вибрировать при уведомлениях',
      'quiet_hours': 'Тихие часы',
      'enable_quiet_hours': 'Включить тихие часы',
      'quiet_hours_desc': 'Не получать уведомления в определённое время',
      'quiet_hours_start': 'Начало тихих часов',
      'quiet_hours_end': 'Конец тихих часов',

      // Account Settings
      'profile': 'Профиль',
      'email': 'Email',
      'username': 'Имя пользователя',
      'security': 'Безопасность',
      'current_password': 'Текущий пароль',
      'new_password': 'Новый пароль',
      'two_factor_auth': 'Двухфакторная аутентификация',
      'two_factor_auth_desc': 'Дополнительная защита аккаунта',
      'active_sessions': 'Активные сессии',
      'active_sessions_desc': 'Управление устройствами',
      'login_history': 'История входов',
      'login_history_desc': 'Просмотр последних входов',
      'privacy': 'Конфиденциальность',
      'profile_privacy': 'Приватность профиля',
      'profile_privacy_desc': 'Кто может видеть ваш профиль',
      'ad_data': 'Данные для рекламы',
      'ad_data_desc': 'Управление рекламными данными',
      'danger_zone': 'Опасная зона',
      'delete_account': 'Удалить аккаунт',
      'delete_account_desc': 'Безвозвратное удаление аккаунта',

      // Privacy Settings
      'public_profile': 'Публичный профиль',
      'public_profile_desc': 'Другие пользователи могут найти ваш профиль',
      'public_playlists': 'Публичные плейлисты',
      'public_playlists_desc': 'Ваши плейлисты видны другим пользователям',
      'playlists_hidden_by_settings': 'Этот список скрыт настройками',
      'show_followers': 'Показывать подписчиков',
      'show_followers_desc': 'Список ваших подписчиков виден другим',
      'listening_activity': 'Активность прослушивания',
      'listening_activity_desc': 'Показывать что вы слушаете сейчас',
      'current_session': 'Текущая',
      'terminate': 'Завершить',
      'delete_account_confirmation':
          'Вы уверены, что хотите удалить свой аккаунт? Это действие нельзя отменить.',
      'sample_text': 'Пример текста',

      // Playlists & Favorites
      'add_to_favorites': 'Добавить в избранное',
      'remove_from_favorites': 'Убрать из избранного',
      'add_to_playlist': 'Добавить в плейлист',
      'create_playlist': 'Создать плейлист',
      'playlist_name': 'Название плейлиста',
      'playlist_description': 'Описание (необязательно)',
      'added_to_favorites': 'Добавлено в избранное',
      'removed_from_favorites': 'Удалено из избранного',
      'added_to_playlist': 'Добавлено в плейлист',
      'already_in_playlist': 'Уже в плейлисте',
      'select_playlist': 'Выберите плейлист',
      'new_playlist': 'Новый плейлист',
      'no_playlists_yet': 'У вас пока нет плейлистов',
      'playlist_name_required': 'Введите название плейлиста',
      'create': 'Создать',

      // Downloaded
      'error_loading': 'Ошибка загрузки',
      'retry': 'Повторить',
      'no_downloaded_songs': 'Нет загруженных песен',
      'upload_songs_hint': 'Загрузите песни в Supabase Storage',
    },
    'en': {
      // Navigation
      'home': 'Home',
      'search': 'Search',
      'ai_playlist': 'AI',
      'library': 'Library',
      'profile': 'Profile',
      'friends': 'Friends',
      'follow': 'Follow',
      'following_button': 'Following',
      'friends_button': 'Friends',
      'find_users': 'Find people',
      'search_users_hint': 'Username or email',
      'search_users_prompt': 'Start typing to find friends',
      'no_users_found': 'No users found',
      'no_users_yet': 'Nothing here yet',
      'section_profiles': 'Profiles',
      'section_artists': 'Artists',
      'section_playlists': 'Playlists',
      'section_songs': 'Songs',

      // Authentication
      'welcome_back': 'Welcome Back',
      'sign_in_subtitle': 'Sign in to continue listening',
      'email': 'Email',
      'password': 'Password',
      'username': 'Username',
      'sign_in': 'Sign In',
      'create_account': 'Create Account',
      'register': 'Register',
      'join_millions': 'Join millions of music lovers',

      // Home
      'good_morning': 'Good Morning',
      'good_afternoon': 'Good Afternoon',
      'good_evening': 'Good Evening',
      'recently_played': 'Recent',
      'nothing_listened': "You haven't listened to anything yet",
      'popular_right_now': 'Popular Right Now',
      'quick_access': 'Quick Access',
      'liked_songs': 'Favorites',
      'downloaded': 'Downloads',
      'made_for_you': 'Made for You',
      'just_for_you': 'Just for You',
      'show_all': 'Show All',
      'ai_mixes': 'AI Mixes',
      'personalized_for_you': 'Personalized for You',
      'ai_mixes_description':
          'These mixes are built from listening history, liked songs, favorite genres and artists.',
      'start_listening_for_ai':
          'Play a few tracks and AI will start building mixes',
      'ai_empty_state':
          'Once the app sees your favorite genres and artists, your personal recommendations will appear here.',

      // Search
      'search_placeholder': 'What do you want to listen to?',
      'browse_all': 'Browse All',
      'no_results': 'No results found',
      'try_different_search': 'Try searching for something else',
      'ai_playlist_prompt_title': 'AI Playlist',
      'ai_playlist_prompt_subtitle':
          'Write something like: "make me a sad night playlist" or "build a soft lo-fi study mix".',
      'ai_playlist_where_to_type': 'Tell AI what you want in the field below:',
      'ai_playlist_prompt_hint':
          'For example: make me a sad night playlist with dream pop and indie vibes',
      'generate_ai_playlist': 'Create playlist with AI',
      'generating_ai_playlist': 'AI is building your playlist...',
      'openai_key_missing':
          'AI is not connected right now. Add a Google AI Studio key above if you want to replace the built-in configuration.',
      'ai_playlist_results': 'AI generated this for you',
      'play_ai_playlist': 'Play playlist',
      'save_ai_playlist': 'Save as playlist',
      'playlist_saved': 'was saved to playlists',
      'ai_playlist_steps':
          '1. Describe the playlist you want  2. AI will use your likes and history  3. Press the button below',
      'openai_key_label': 'Google AI Studio key',
      'openai_key_hint':
          'Paste your Gemini API key here if you want to replace the built-in one',
      'save_openai_key': 'Save key',
      'openai_key_saved': 'Google AI Studio key was saved locally',
      'openai_key_connected': 'Gemini connected',
      'change': 'Change',
      'ai_example_1': 'make me a sad night playlist',
      'ai_example_2': 'pick a calm lo-fi mix for studying',
      'ai_example_3': 'build an energetic evening mix for workout',

      // Library
      'your_library': 'Your Library',
      'create_playlist': 'Create playlist',
      'playlist_help': 'It\'s easy, we\'ll help you',
      'playlists': 'Playlists',
      'no_playlists': 'No playlists yet',
      'create_first_playlist': 'Create your first playlist',
      'no_liked_songs': 'No liked songs',
      'liked_songs_help': 'Songs you like will appear here',

      // Settings
      'settings': 'Settings',
      'account': 'Account',
      'account_subtitle': 'Privacy, security, change email',
      'notifications': 'Notifications',
      'notifications_subtitle': 'Music recommendations, new releases',
      'storage': 'Storage',
      'storage_subtitle': 'Downloaded music, cache',
      'display': 'Display',
      'display_subtitle': 'Theme, appearance',
      'playback': 'Playback',
      'playback_subtitle': 'Crossfade, gapless, equalizer',
      'admin_panel': 'Admin panel',
      'admin_panel_subtitle': 'Manage songs and uploads',
      'checking_admin_access': 'Checking admin access...',
      'admin_access_denied':
          'You do not have permission to access the admin panel',
      'help_support': 'Help & Support',
      'help_support_subtitle': 'FAQ, contact us',
      'about': 'About',
      'about_subtitle': 'Version, terms, privacy policy',
      'logout': 'Log Out',

      // Display Settings
      'theme': 'Theme',
      'dark_theme': 'Dark',
      'light_theme': 'Light',
      'auto_theme': 'Auto',
      'recommended': 'Recommended',
      'classic': 'Classic',
      'follows_system': 'Follows system',
      'accent_color': 'Accent Color',
      'green': 'Green',
      'blue': 'Blue',
      'purple': 'Purple',
      'red': 'Red',
      'orange': 'Orange',
      'language': 'Language',
      'text_size': 'Text Size',
      'small': 'Small',
      'large': 'Large',
      'show_album_art': 'Show album covers',
      'show_album_art_subtitle': 'Display images in lists',
      'animations': 'Animations',
      'animations_subtitle': 'Enable smooth transitions and effects',
      'preview': 'Preview',
      'sample_song': 'Song Title',
      'sample_artist': 'Artist',

      // Music Player
      'playing_from': 'PLAYING FROM',
      'add_to_favorites': 'Add to Liked Songs',
      'remove_from_favorites': 'Remove from Liked Songs',
      'add_to_playlist': 'Add to Playlist',
      'share': 'Share',
      'go_to_album': 'Go to Album',
      'go_to_artist': 'Go to Artist',

      // Common
      'save': 'Save',
      'cancel': 'Cancel',
      'ok': 'OK',
      'edit': 'Edit',
      'delete': 'Delete',
      'coming_soon': 'Coming Soon',
      'coming_soon_message': 'This feature will be available in future updates',
      'songs': 'songs',
      'browse_all': 'Browse All',

      // Profile
      'settings': 'Settings',
      'edit_profile': 'Edit Profile',
      'playlists': 'Playlists',
      'following': 'Following',
      'followers': 'Followers',
      'account': 'Account',
      'account_subtitle': 'Privacy, security, change email',
      'notifications': 'Notifications',
      'notifications_subtitle': 'Music recommendations, new releases',
      'storage': 'Storage',
      'storage_subtitle': 'Downloaded music, cache',
      'display_subtitle': 'Theme, appearance',
      'playback': 'Playback',
      'playback_subtitle': 'Crossfade, equalizer',
      'help_support': 'Help & Support',
      'help_support_subtitle': 'FAQ, contact us',
      'about_app': 'About App',
      'about_app_subtitle': 'Version, terms, privacy policy',
      'logout': 'Logout',
      'logout_title': 'Logout',
      'logout_message': 'Are you sure you want to logout?',
      'app_description':
          'Beautiful music app inspired by Spotify. Built with Flutter.',

      // Edit Profile Screen
      'profile_info': 'Profile Info',
      'profile_info_description':
          'Your username is visible to other users. Email is used for login and cannot be changed.',
      'profile_updated': 'Profile updated successfully',
      'username_required': 'Enter username',
      'email_cannot_be_changed': 'Email cannot be changed',
      'take_photo': 'Take Photo',
      'choose_from_gallery': 'Choose from Gallery',
      'remove_photo': 'Remove Photo',

      // Playlist Detail Screen
      'play_all': 'Play All',
      'edit_playlist': 'Edit Playlist',
      'delete_playlist': 'Delete Playlist',
      'delete_playlist_confirm':
          'Are you sure you want to delete this playlist?',
      'playlist_empty': 'Playlist is empty',
      'playlist_empty_help': 'Add songs via the song menu',

      // Notifications Settings
      'general_settings': 'General Settings',
      'push_notifications': 'Push Notifications',
      'push_notifications_desc': 'Receive notifications on device',
      'email_notifications': 'Email Notifications',
      'email_notifications_desc': 'Receive notifications via email',
      'music_notifications': 'Music Notifications',
      'new_releases': 'New Releases',
      'new_releases_desc':
          'Notifications about new albums from favorite artists',
      'recommendations_desc': 'Personalized music recommendations',
      'playlist_updates': 'Playlist Updates',
      'playlist_updates_desc': 'When songs are added to your playlists',
      'concert_alerts': 'Concerts & Events',
      'concert_alerts_desc':
          'Notifications about concerts from favorite artists',
      'social_notifications': 'Social Notifications',
      'friend_activity': 'Friend Activity',
      'friend_activity_desc': 'What your friends are listening to',
      'sound_vibration': 'Sound & Vibration',
      'notification_sound': 'Notification Sound',
      'notification_sound_desc': 'Play sound for notifications',
      'vibration': 'Vibration',
      'vibration_desc': 'Vibrate for notifications',
      'quiet_hours': 'Quiet Hours',
      'enable_quiet_hours': 'Enable Quiet Hours',
      'quiet_hours_desc': 'Don\'t receive notifications at certain times',
      'quiet_hours_start': 'Quiet Hours Start',
      'quiet_hours_end': 'Quiet Hours End',

      // Account Settings
      'email': 'Email',
      'username': 'Username',
      'security': 'Security',
      'current_password': 'Current Password',
      'new_password': 'New Password',
      'two_factor_auth': 'Two-Factor Authentication',
      'two_factor_auth_desc': 'Additional account protection',
      'active_sessions': 'Active Sessions',
      'active_sessions_desc': 'Device management',
      'login_history': 'Login History',
      'login_history_desc': 'View recent logins',
      'privacy': 'Privacy',
      'profile_privacy': 'Profile Privacy',
      'profile_privacy_desc': 'Who can see your profile',
      'ad_data': 'Ad Data',
      'ad_data_desc': 'Manage advertising data',
      'danger_zone': 'Danger Zone',
      'delete_account': 'Delete Account',
      'delete_account_desc': 'Permanently delete account',

      // Privacy Settings
      'public_profile': 'Public Profile',
      'public_profile_desc': 'Other users can find your profile',
      'public_playlists': 'Public Playlists',
      'public_playlists_desc': 'Your playlists are visible to other users',
      'playlists_hidden_by_settings': 'This list is hidden by settings',
      'show_followers': 'Show Followers',
      'show_followers_desc': 'Your followers list is visible to others',
      'listening_activity': 'Listening Activity',
      'listening_activity_desc': 'Show what you\'re currently listening to',
      'current_session': 'Current',
      'terminate': 'Terminate',
      'delete_account_confirmation':
          'Are you sure you want to delete your account? This action cannot be undone.',
      'sample_text': 'Sample Text',

      // Playlists & Favorites
      'add_to_favorites': 'Add to Favorites',
      'remove_from_favorites': 'Remove from Favorites',
      'add_to_playlist': 'Add to Playlist',
      'create_playlist': 'Create Playlist',
      'playlist_name': 'Playlist Name',
      'playlist_description': 'Description (optional)',
      'added_to_favorites': 'Added to favorites',
      'removed_from_favorites': 'Removed from favorites',
      'added_to_playlist': 'Added to playlist',
      'already_in_playlist': 'Already in playlist',
      'select_playlist': 'Select Playlist',
      'new_playlist': 'New Playlist',
      'no_playlists_yet': 'You don\'t have any playlists yet',
      'playlist_name_required': 'Please enter a playlist name',
      'create': 'Create',

      // Downloaded
      'error_loading': 'Error loading',
      'retry': 'Retry',
      'no_downloaded_songs': 'No downloaded songs',
      'upload_songs_hint': 'Upload songs to Supabase Storage',
    },
    'kk': {
      // Navigation
      'home': 'Басты',
      'search': 'Іздеу',
      'ai_playlist': 'AI',
      'library': 'Кітапхана',
      'profile': 'Профиль',

      // Authentication
      'welcome_back': 'Қош келдіңіз',
      'sign_in_subtitle': 'Тыңдауды жалғастыру үшін кіріңіз',
      'email': 'Email',
      'password': 'Құпия сөз',
      'username': 'Пайдаланушы аты',
      'sign_in': 'Кіру',
      'create_account': 'Тіркелу',
      'register': 'Тіркелу',
      'join_millions': 'Миллиондаған музыка сүйерлерге қосылыңыз',

      // Home
      'good_morning': 'Қайырлы таң',
      'good_afternoon': 'Қайырлы күн',
      'good_evening': 'Қайырлы кеш',
      'recently_played': 'Соңғылар',
      'nothing_listened': 'Сіз әлі ештеңе тыңдаған жоқсыз',
      'popular_right_now': 'Қазір танымал',
      'quick_access': 'Жылдам қатынас',
      'liked_songs': 'Ұнағандар',
      'downloaded': 'Жүктелген',
      'made_for_you': 'Сіз үшін',
      'just_for_you': 'Тек сіз үшін',
      'show_all': 'Барлығын көрсету',
      'ai_mixes': 'AI Микстер',
      'personalized_for_you': 'Сіз үшін жеке',
      'ai_mixes_description':
          'Микстер тыңдау тарихынан, ұнаған тректерден, жанрлар мен орындаушылардан жиналады.',
      'start_listening_for_ai':
          'Бірнеше трек қосыңыз, AI микстер құрастыра бастайды',
      'ai_empty_state':
          'Қолданба сіздің сүйікті жанрларыңыз бен орындаушыларыңызды көргенде, мұнда жеке ұсыныстар пайда болады.',

      // Search
      'search_placeholder': 'Не тыңдағыңыз келеді?',
      'browse_all': 'Барлығын шолу',
      'no_results': 'Нәтиже табылмады',
      'try_different_search': 'Басқа сұрауды қолданып көріңіз',
      'ai_playlist_prompt_title': 'AI плейлист',
      'ai_playlist_prompt_subtitle':
          'Мысалы: "маған түнгі қайғылы плейлист жаса" немесе "оқуға арналған жұмсақ lo-fi таңда" деп жазыңыз.',
      'ai_playlist_where_to_type': 'AI-ға не қалайтыныңызды төменде жазыңыз:',
      'ai_playlist_prompt_hint':
          'Мысалы: маған dream pop және indie бар қайғылы түнгі плейлист жаса',
      'generate_ai_playlist': 'AI арқылы плейлист жасау',
      'generating_ai_playlist': 'AI плейлист құрастыруда...',
      'openai_key_missing':
          'AI қазір қосылмаған. Кірістірілген конфигурацияны ауыстырғыңыз келсе, жоғарыда Google AI Studio кілтін қосыңыз.',
      'ai_playlist_results': 'AI сіз үшін жасады',
      'play_ai_playlist': 'Плейлистті тыңдау',
      'save_ai_playlist': 'Плейлист ретінде сақтау',
      'playlist_saved': 'плейлисттерге сақталды',
      'ai_playlist_steps':
          '1. Қандай плейлист қалайтыныңызды жазыңыз  2. AI лайктарыңыз бен тарихыңызды ескереді  3. Төмендегі батырманы басыңыз',
      'openai_key_label': 'Google AI Studio кілті',
      'openai_key_hint':
          'Кірістірілгенді ауыстырғыңыз келсе, Gemini API кілтіңізді осында қойыңыз',
      'save_openai_key': 'Кілтті сақтау',
      'openai_key_saved': 'Google AI Studio кілті жергілікті сақталды',
      'openai_key_connected': 'Gemini қосылды',
      'change': 'Өзгерту',
      'ai_example_1': 'маған қайғылы түнгі плейлист жаса',
      'ai_example_2': 'оқуға арналған тыныш lo-fi таңда',
      'ai_example_3': 'жаттығуға арналған қуатты кешкі микс құрастыр',

      // Library
      'your_library': 'Сіздің кітапхана',
      'create_playlist': 'Плейлист жасау',
      'playlist_help': 'Бұл оңай, біз көмектесеміз',
      'playlists': 'Плейлисттер',
      'no_playlists': 'Плейлисттер жоқ',
      'create_first_playlist': 'Алғашқы плейлистіңізді жасаңыз',
      'no_liked_songs': 'Ұнаған әндер жоқ',
      'liked_songs_help': 'Ұнаған әндер мұнда пайда болады',

      // Settings
      'settings': 'Баптаулар',
      'account': 'Аккаунт',
      'account_subtitle': 'Құпиялылық, қауіпсіздік, email өзгерту',
      'notifications': 'Хабарландырулар',
      'notifications_subtitle': 'Музыкалық ұсыныстар, жаңа шығарылымдар',
      'storage': 'Жад',
      'storage_subtitle': 'Жүктелген музыка, кэш',
      'display': 'Безендіру',
      'display_subtitle': 'Тақырып, сыртқы түрі',
      'playback': 'Ойнату',
      'playback_subtitle': 'Кроссфейд, эквалайзер',
      'admin_panel': 'Админ-панель',
      'admin_panel_subtitle': 'Әндер мен жүктеулерді басқару',
      'checking_admin_access': 'Әкімші құқықтары тексерілуде...',
      'admin_access_denied': 'Админ-панельге кіруге өкілеттігіңіз жоқ',
      'help_support': 'Көмек және қолдау',
      'help_support_subtitle': 'Жиі қойылатын сұрақтар, бізге хабарласу',
      'about': 'Қолданба туралы',
      'about_subtitle': 'Нұсқа, шарттар, құпиялылық саясаты',
      'logout': 'Шығу',

      // Display Settings
      'theme': 'Тақырып',
      'dark_theme': 'Қараңғы',
      'light_theme': 'Жарық',
      'auto_theme': 'Авто',
      'recommended': 'Ұсынылады',
      'classic': 'Классикалық',
      'follows_system': 'Жүйе бойынша',
      'accent_color': 'Акцент түсі',
      'green': 'Жасыл',
      'blue': 'Көк',
      'purple': 'Күлгін',
      'red': 'Қызыл',
      'orange': 'Қызғылт сары',
      'language': 'Тіл',
      'text_size': 'Мәтін өлшемі',
      'small': 'Кішкентай',
      'large': 'Үлкен',
      'show_album_art': 'Альбом мұқабаларын көрсету',
      'show_album_art_subtitle': 'Тізімдерде суреттерді көрсету',
      'animations': 'Анимациялар',
      'animations_subtitle': 'Тегіс ауысулар мен эффекттерді қосу',
      'preview': 'Алдын ала қарау',
      'sample_song': 'Ән атауы',
      'sample_artist': 'Орындаушы',

      // Music Player
      'playing_from': 'ОЙНАТЫЛУДА',
      'add_to_favorites': 'Ұнағандарға қосу',
      'remove_from_favorites': 'Ұнағандардан алып тастау',
      'add_to_playlist': 'Плейлистке қосу',
      'share': 'Бөлісу',
      'go_to_album': 'Альбомға өту',
      'go_to_artist': 'Орындаушыға өту',

      // Common
      'save': 'Сақтау',
      'cancel': 'Бас тарту',
      'ok': 'OK',
      'edit': 'Өзгерту',
      'delete': 'Жою',
      'coming_soon': 'Жақында',
      'coming_soon_message':
          'Бұл мүмкіндік келесі жаңартуларда қолжетімді болады',
      'songs': 'ән',

      // Profile
      'edit_profile': 'Профильді өзгерту',
      'following': 'Жазылымдар',
      'followers': 'Жазылушылар',
      'friends': 'Достар',
      'follow': 'Жазылу',
      'following_button': 'Жазылғансыз',
      'friends_button': 'Достарсыз',
      'find_users': 'Адамдарды табу',
      'search_users_hint': 'Аты немесе email',
      'search_users_prompt': 'Достарды табу үшін теруді бастаңыз',
      'no_users_found': 'Пайдаланушылар табылмады',
      'no_users_yet': 'Әзірге бос',
      'section_profiles': 'Профильдер',
      'section_artists': 'Орындаушылар',
      'section_playlists': 'Плейлисттер',
      'section_songs': 'Әндер',
      'about_app': 'Қолданба туралы',
      'about_app_subtitle': 'Нұсқа, шарттар, құпиялылық саясаты',
      'logout_title': 'Шығу',
      'logout_message': 'Шынымен шығғыңыз келе ме?',
      'app_description':
          'Spotify-дан шабыттанған әдемі музыка қолданбасы. Flutter арқылы жасалған.',

      // Edit Profile Screen
      'profile_info': 'Профиль ақпараты',
      'profile_info_description':
          'Пайдаланушы атыңыз басқаларға көрінеді. Email кіру үшін қолданылады және өзгертілмейді.',
      'profile_updated': 'Профиль сәтті жаңартылды',
      'username_required': 'Пайдаланушы атын енгізіңіз',
      'email_cannot_be_changed': 'Email өзгертілмейді',
      'take_photo': 'Фото түсіру',
      'choose_from_gallery': 'Галереядан таңдау',
      'remove_photo': 'Фотоны жою',

      // Playlist Detail Screen
      'play_all': 'Ойнату',
      'edit_playlist': 'Плейлистті өзгерту',
      'delete_playlist': 'Плейлистті жою',
      'delete_playlist_confirm':
          'Бұл плейлистті жойғыңыз келетініне сенімдісіз бе?',
      'playlist_empty': 'Плейлист бос',
      'playlist_empty_help': 'Ән мәзірі арқылы әндер қосыңыз',

      // Notifications Settings
      'general_settings': 'Жалпы баптаулар',
      'push_notifications': 'Push-хабарландырулар',
      'push_notifications_desc': 'Құрылғыда хабарландырулар алу',
      'email_notifications': 'Email-хабарландырулар',
      'email_notifications_desc': 'Поштаға хабарландырулар алу',
      'music_notifications': 'Музыкалық хабарландырулар',
      'new_releases': 'Жаңа шығарылымдар',
      'new_releases_desc':
          'Сүйікті орындаушылардың жаңа альбомдары туралы хабарландырулар',
      'recommendations_desc': 'Жеке музыкалық ұсыныстар',
      'playlist_updates': 'Плейлист жаңартулары',
      'playlist_updates_desc': 'Плейлисттеріңізге ән қосылғанда',
      'concert_alerts': 'Концерттер мен оқиғалар',
      'concert_alerts_desc':
          'Сүйікті орындаушылардың концерттері туралы хабарландырулар',
      'social_notifications': 'Әлеуметтік хабарландырулар',
      'friend_activity': 'Достар белсенділігі',
      'friend_activity_desc': 'Достарыңыз не тыңдап жатыр',
      'sound_vibration': 'Дыбыс және дірілдеу',
      'notification_sound': 'Хабарландыру дыбысы',
      'notification_sound_desc': 'Хабарландыруларда дыбыс ойнату',
      'vibration': 'Дірілдеу',
      'vibration_desc': 'Хабарландыруларда дірілдеу',
      'quiet_hours': 'Тыныш сағаттар',
      'enable_quiet_hours': 'Тыныш сағаттарды қосу',
      'quiet_hours_desc': 'Белгілі бір уақытта хабарландырулар алмау',
      'quiet_hours_start': 'Тыныш сағаттардың басы',
      'quiet_hours_end': 'Тыныш сағаттардың соңы',

      // Account Settings
      'security': 'Қауіпсіздік',
      'current_password': 'Ағымдағы құпия сөз',
      'new_password': 'Жаңа құпия сөз',
      'two_factor_auth': 'Екі факторлы аутентификация',
      'two_factor_auth_desc': 'Аккаунтты қосымша қорғау',
      'active_sessions': 'Белсенді сессиялар',
      'active_sessions_desc': 'Құрылғыларды басқару',
      'login_history': 'Кіру тарихы',
      'login_history_desc': 'Соңғы кірулерді қарау',
      'privacy': 'Құпиялылық',
      'profile_privacy': 'Профиль құпиялылығы',
      'profile_privacy_desc': 'Профиліңізді кім көре алады',
      'ad_data': 'Жарнама деректері',
      'ad_data_desc': 'Жарнама деректерін басқару',
      'danger_zone': 'Қауіпті аймақ',
      'delete_account': 'Аккаунтты жою',
      'delete_account_desc': 'Аккаунтты біржола жою',

      // Privacy Settings
      'public_profile': 'Жария профиль',
      'public_profile_desc': 'Басқа пайдаланушылар профиліңізді таба алады',
      'public_playlists': 'Жария плейлисттер',
      'public_playlists_desc': 'Плейлисттеріңіз басқаларға көрінеді',
      'playlists_hidden_by_settings': 'Бұл тізім параметрлермен жасырылған',
      'show_followers': 'Жазылушыларды көрсету',
      'show_followers_desc': 'Жазылушылар тізіміңіз басқаларға көрінеді',
      'listening_activity': 'Тыңдау белсенділігі',
      'listening_activity_desc': 'Қазір не тыңдап жатқаныңызды көрсету',
      'current_session': 'Ағымдағы',
      'terminate': 'Аяқтау',
      'delete_account_confirmation':
          'Аккаунтыңызды жойғыңыз келетініне сенімдісіз бе? Бұл әрекетті қайтару мүмкін емес.',
      'sample_text': 'Мәтін үлгісі',

      // Playlists & Favorites
      'playlist_name': 'Плейлист атауы',
      'playlist_description': 'Сипаттама (міндетті емес)',
      'added_to_favorites': 'Ұнағандарға қосылды',
      'removed_from_favorites': 'Ұнағандардан жойылды',
      'added_to_playlist': 'Плейлистке қосылды',
      'already_in_playlist': 'Плейлистте бар',
      'select_playlist': 'Плейлистті таңдаңыз',
      'new_playlist': 'Жаңа плейлист',
      'no_playlists_yet': 'Сізде әлі плейлисттер жоқ',
      'playlist_name_required': 'Плейлист атауын енгізіңіз',
      'create': 'Жасау',

      // Downloaded
      'error_loading': 'Жүктеу қатесі',
      'retry': 'Қайталау',
      'no_downloaded_songs': 'Жүктелген әндер жоқ',
      'upload_songs_hint': 'Supabase Storage-ге әндер жүктеңіз',
    },
  };

  LocaleProvider() {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final localeCode = prefs.getString(_localeKey) ?? 'ru';
    _locale = Locale(localeCode);
    notifyListeners();
  }

  Future<void> setLocale(String localeCode) async {
    _locale = Locale(localeCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, localeCode);
    notifyListeners();
  }

  String getString(String key) {
    return _localizedStrings[_locale.languageCode]?[key] ?? key;
  }

  List<Map<String, String>> get supportedLanguages => [
    {'code': 'ru', 'name': 'Русский', 'flag': '🇷🇺'},
    {'code': 'en', 'name': 'English', 'flag': '🇺🇸'},
    {'code': 'kk', 'name': 'Қазақша', 'flag': '🇰🇿'},
  ];
}
