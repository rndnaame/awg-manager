#!/bin/sh
# AWG Manager installer with version selection
# Автор: Grok (исправленная версия для hoaxisr/awg-manager)

set -e

ENTWARE_REPO="http://repo.hoaxisr.ru"
OPKG_CONF="/opt/etc/opkg/awg_manager.conf"

info()  { printf "\033[1;32m[+]\033[0m %s\n" "$1"; }
warn()  { printf "\033[1;33m[!]\033[0m %s\n" "$1"; }
error() { printf "\033[1;31m[-]\033[0m %s\n" "$1"; exit 1; }

detect_arch() {
    info "Определяю архитектуру..."
    ARCH=$(opkg print-architecture 2>/dev/null | grep '_kn' | awk '{print $2}' | sed 's/_kn.*//')
    [ -z "$ARCH" ] && error "Не удалось определить архитектуру."

    case "$ARCH" in
        mipsel-3.4|mips-3.4|aarch64-3.10) ;;
        *) error "Неподдерживаемая архитектура: $ARCH" ;;
    esac

    REPO_ARCH=$(echo "$ARCH" | sed 's/-\([0-9]\)/-k\1/')
    info "Архитектура: $ARCH (repo: $REPO_ARCH)"
}

add_repo() {
    REPO_LINE="src/gz hoaxisr ${ENTWARE_REPO}/${REPO_ARCH}"

    if [ -f "$OPKG_CONF" ] && grep -qF "$REPO_LINE" "$OPKG_CONF" 2>/dev/null; then
        info "Репозиторий уже добавлен"
        return
    fi

    mkdir -p /opt/etc/opkg
    echo "$REPO_LINE" > "$OPKG_CONF"
    info "Репозиторий добавлен: ${ENTWARE_REPO}/${REPO_ARCH}"
}

choose_version() {
    info "Получаю последнюю версию с GitHub..."
    LATEST=$(curl -s https://api.github.com/repos/hoaxisr/awg-manager/releases/latest \
             | sed -n 's/.*"tag_name": "\([^"]*\)".*/\1/p' | sed 's/^v//')

    [ -z "$LATEST" ] && { warn "Не удалось получить версию, используем 2.7.6"; LATEST="2.7.6"; }

    echo ""
    info "Последняя стабильная версия: \033[1;36m$LATEST\033[0m"
    printf "\033[1;36mВведите версию для установки (Enter = %s): \033[0m" "$LATEST"
    read -r INPUT_VER

    if [ -z "$INPUT_VER" ]; then
        VERSION="$LATEST"
    else
        VERSION="$INPUT_VER"
    fi

    info "Выбрана версия: $VERSION"
}

install_package() {
    info "Обновляю список пакетов..."
    opkg update >/dev/null 2>&1 || warn "opkg update завершился с предупреждением"

    info "Устанавливаю awg-manager версии $VERSION..."
    if ! opkg install --force-downgrade "awg-manager=$VERSION"; then
        error "Не удалось установить версию $VERSION. Возможно, такой версии нет в репозитории."
    fi

    INSTALLED_VER=$(opkg list-installed awg-manager | awk '{print $3}')
    info "Успешно установлено: $INSTALLED_VER"
}

start_service() {
    info "Перезапускаю сервис..."
    /opt/etc/init.d/S99awg-manager restart 2>/dev/null || true
}

show_url() {
    PORT=$(sed -n 's/.*"port"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' \
        /opt/etc/awg-manager/settings.json 2>/dev/null || echo "2222")

    IP=$(ip -4 addr show br0 2>/dev/null | awk '/inet /{sub(/\/.*/, "", $2); print $2; exit}' || echo "192.168.1.1")

    echo ""
    info "========================================"
    info "  AWG Manager доступен по адресу:"
    info "  http://${IP}:${PORT}"
    info "========================================"
    echo ""
}

# ===================== MAIN =====================
detect_arch
add_repo
choose_version
install_package
start_service
show_url

info "Готово! 🎉"
