#!/bin/sh
# AWG Manager — установщик с выбором версии (максимально надёжный для BusyBox ash)

set -e

info()  { printf "\033[1;32m[+]\033[0m %s\n" "$1"; }
error() { printf "\033[1;31m[-]\033[0m %s\n" "$1"; exit 1; }

detect_arch() {
    info "Определяю архитектуру..."
    ARCH=$(opkg print-architecture 2>/dev/null | grep '_kn' | awk '{print $2}' | sed 's/_kn.*//')
    [ -z "$ARCH" ] && error "Не удалось определить архитектуру."

    REPO_ARCH=$(echo "$ARCH" | sed 's/-\([0-9]\)/-k\1/')
    info "Архитектура: $ARCH (repo: $REPO_ARCH)"
}

add_repo() {
    REPO_LINE="src/gz hoaxisr http://repo.hoaxisr.ru/$REPO_ARCH"

    if [ -f "/opt/etc/opkg/awg_manager.conf" ] && grep -qF "$REPO_LINE" "/opt/etc/opkg/awg_manager.conf" 2>/dev/null; then
        info "Репозиторий уже добавлен"
        return
    fi

    mkdir -p /opt/etc/opkg
    echo "$REPO_LINE" > /opt/etc/opkg/awg_manager.conf
    info "Репозиторий добавлен"
}

choose_version() {
    info "Получаю последнюю версию с GitHub..."
    LATEST=$(curl -s https://api.github.com/repos/hoaxisr/awg-manager/releases/latest | \
             sed -n 's/.*"tag_name": "\([^"]*\)".*/\1/p' | sed 's/^v//')

    [ -z "$LATEST" ] && LATEST="2.7.6"

    echo ""
    info "Последняя доступная версия: \033[1;36m$LATEST\033[0m"

    # Максимально надёжный ввод для BusyBox ash
    printf "\033[1;36mВведите версию для установки (Enter = %s): \033[0m" "$LATEST"
    echo ""                  # принудительный перевод строки
    VERSION=$(cat /dev/tty)  # читаем напрямую с терминала

    if [ -z "$VERSION" ]; then
        VERSION="$LATEST"
    fi

    info "Выбрана версия: $VERSION"
}

install_package() {
    info "Обновляю список пакетов..."
    opkg update >/dev/null 2>&1 || true

    info "Устанавливаю awg-manager версии $VERSION..."
    if ! opkg install --force-downgrade "awg-manager=$VERSION"; then
        error "Не удалось установить версию $VERSION"
    fi

    INSTALLED=$(opkg list-installed awg-manager | awk '{print $3}')
    info "Успешно установлено: $INSTALLED"
}

# Запуск
detect_arch
add_repo
choose_version
install_package

info "Перезапускаю сервис..."
/opt/etc/init.d/S99awg-manager restart 2>/dev/null || true

info "🎉 Готово!"
