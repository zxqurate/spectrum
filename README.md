# Spectrum

Рабочий стол на **Hyprland** с кастомной оболочкой [Quickshell](https://github.com/quickshell-impl/quickshell) и цветами из обоев через [matugen](https://github.com/InioX/matugen).

Меняешь обои — обновляются бар, control center, lock screen, rofi, kitty, fish и GTK-приложения.

---

## Возможности

- **Верхний бар** — воркспейсы, медиа, громкость, Wi‑Fi, статистика, часы
- **Control Center** (`Super+Space`) — время, инфо о системе, настройки, меню питания
- **Боковая панель** — уведомления, календарь, быстрые переключатели, режим Always On
- **Экран блокировки** — пароль, медиа, статистика (`Super+L`, автоблок через 15 мин)
- **Выбор обоев** (`Super+Ctrl+T`) — картинка и тема в одном клике
- **Меню кейбиндов** (`Super+/`) — просмотр и редактирование сочетаний

---

## Поддерживаемые дистрибутивы

Конфиги не привязаны к одному дистру: пути через `$HOME` и стандартные каталоги FHS. Теоретически встанет на любой Linux, где есть нужные пакеты.

| Дистрибутив | Комментарий |
|-------------|-------------|
| **Arch Linux** | Основная платформа; установка одной командой |
| **EndeavourOS / Manjaro / CachyOS** | Как Arch: pacman + AUR для quickshell |
| **Fedora / Nobara** | Зависимости вручную, потом `./install.sh` |
| **Debian / Ubuntu** | Hyprland и deps из реп или сторонних источников; quickshell может потребовать сборку |
| **openSUSE / NixOS** | Реально, но пакеты маппить самому |

На **Arch-подобных** всё проще всего. На остальных — ставишь программы из [`packages/arch.txt`](packages/arch.txt) своим менеджером пакетов, затем `./install.sh` без `--install-deps`.

---

## Установка

```bash
git clone https://github.com/zxqurate/spectrum.git ~/spectrum
cd ~/spectrum
chmod +x install.sh
./install.sh --install-deps --install-aur
```

На Arch последняя строка поставит пакеты и `quickshell` из AUR.

На других дистрибутивах — сначала зависимости, потом:

```bash
./install.sh
```

### Мониторы

```bash
nwg-displays
# сохрани раскладку в ~/.config/hypr/monitors.conf
```

Или отредактируй `~/.config/hypr/monitors.conf` вручную — пример в `monitors.conf.example`.

### Вход в систему

Выбери сессию **Hyprland** в display manager. Бар и shell поднимутся сами.

---

## Флаги install.sh

| Флаг | Что делает |
|------|------------|
| `--install-deps` | Ставит пакеты из `packages/arch.txt` (только Arch) |
| `--install-aur` | Ставит `quickshell` из AUR через yay/paru |
| `--force` | Заменяет существующие конфиги (старые → `.spectrum-bak.*`) |
| `--dry-run` | Показывает действия без изменений |

---

## Горячие клавиши

| Комбинация | Действие |
|------------|----------|
| `Super+Space` | Control Center |
| `Super+/` | Меню кейбиндов |
| `Super+L` | Блокировка |
| `Super+Ctrl+T` | Выбор обоев |
| `Super+D` | Лаунчер (rofi) |
| `Super+Return` | Терминал (kitty) |
| `Super+E` | Файловый менеджер (Thunar) |
| `Super+Shift+S` | Скриншот (область) |

Остальное: `Super+/` или `~/.config/hypr/keybinds.conf`.

---

## Обои и тема

Картинки клади в `~/wallpapers/`.

```bash
# Сменить обои и перегенерировать тему
~/.config/hypr/scripts/change-wallpaper.sh ~/wallpapers/картинка.jpg

# Только тема (текущие обои)
~/.config/hypr/scripts/run-matugen.sh
```

Светлая / тёмная тема: Control Center → Settings → Appearance.

---

## Зависимости

| Компонент | Зачем |
|-----------|--------|
| Hyprland + hypridle | Комpositor и idle-блокировка |
| Quickshell | UI: бар, панели, lock screen |
| awww | Обои |
| matugen | Цвета из обоев |
| kitty, fish, rofi | Терминал, shell, лаунчер |
| PipeWire + wireplumber | Звук (`wpctl`) |
| grim, slurp, wl-clipboard | Скриншоты |
| adw-gtk3, adwaita icons | GTK / Thunar |
| Rubik, JetBrainsMono Nerd Font | Шрифты интерфейса и иконок |

Полный список для Arch: [`packages/arch.txt`](packages/arch.txt).

---

## Обновление

```bash
cd ~/spectrum
git pull
./install.sh --force
~/.config/hypr/scripts/run-matugen.sh
```

---

## Если что-то не работает

**Нет бара или темы после установки**
```bash
~/.config/hypr/scripts/run-matugen.sh ~/wallpapers/default.jpg dark
```

**Криво встали мониторы**
```bash
nwg-displays
hyprctl reload
```

**Quickshell не найден** — на Arch: `yay -S quickshell`

**Quickshell пропадает после закрытия терминала**

Не запускай `quickshell` голым — процесс привязан к терминалу и умрёт вместе с ним. Используй:

```bash
~/.config/hypr/scripts/start-quickshell.sh
# или
quickshell --daemonize
```

После установки Spectrum поднимает его через autostart Hyprland и (если доступен systemd) `quickshell.service`:

```bash
systemctl --user enable --now quickshell.service
quickshell list   # должен показать shell.qml
```

**Blur / System blur / нет прозрачности на баре**

1. Quickshell должен быть запущен (`quickshell list`).
2. Тёмная тема + включены **System blur** и **Blur** в настройках (Super+Space → ⚙).
3. После обновления конфига: `killall quickshell; ~/.config/hypr/scripts/start-quickshell.sh`
4. Для Hyprland blur: `hyprctl reload` (layerrule в `windowrules.conf`).

Прозрачность панелей требует `surfaceFormat.opaque: false` на layer-окнах — это уже в `GlassPanelWindow`. Если бар всё ещё непрозрачный, перезапусти quickshell (не из терминала без `-d`).

---

## Лицензия

MIT

**Автор:** [zxqurate](https://github.com/zxqurate)
