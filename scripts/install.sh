#!/bin/sh
# AWG Manager — установщик с выбором версии (для rndnaame/awg-manager)
# Исправлено: цвета + стабильный ввод в BusyBox ash

set -e

info()  { printf "[+] %s\n" "$1"; }
warn()  { printf "[!] %s\n" "$1"; }
error() { printf "[-] %s\n" "$1"; exit 1; }

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

# Выбор версии — максимально простой и надёжный вариант
choose_version() {
    # Если версия передана параметром: sh -s -- 2.6.5
    if [ -n "$1" ]; then
        VERSION="$1"
        info "Версия указана параметром: $VERSION"
        return
    fi

    info "Получаю последнюю версию с GitHub..."
    LATEST=$(curl -s https://api.github.com/repos/hoaxisr/awg-manager/releases/latest | \
             sed -n 's/.*"tag_name": "\([^"]*\)".*/\1/p' | sed 's/^v//')

    [ -z "$LATEST" ] && LATEST="2.7.6"

    echo ""
    info "Последняя доступная версия: $LATEST"

    echo -n "Введите версию для установки (Enter = $LATEST): "
    read -r VERSION

    if [ -z "$VERSION" ]; then
        VERSION="$LATEST"
    fi

    info "Выбрана версия: $VERSION"
}

install_package() {
    info "Обновляю список пакетов..."
    opkg update >/dev/null 2>&1 || warn "opkg update завершился с предупреждением"

    info "Устанавливаю awg-manager версии $VERSION..."
    if ! opkg install --force-downgrade "awg-manager=$VERSION"; then
        error "Не удалось установить версию $VERSION. Убедитесь, что такая версия существует."
    fi

    INSTALLED=$(opkg list-installed awg-manager | awk '{print $3}')
    info "Успешно установлено: $INSTALLED"
}

# Основная часть
detect_arch
add_repo
choose_version "$1"
install_package

info "Перезапускаю сервис..."
/opt/etc/init.d/S99awg-manager restart 2>/dev/null || true

info "🎉 Готово!"
