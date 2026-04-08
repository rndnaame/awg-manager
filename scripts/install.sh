#!/bin/sh
# AWG Manager — установщик для роутеров Keenetic
# Версия с возможностью выбора конкретной версии пакета

set -e

ENTWARE_REPO="http://repo.hoaxisr.ru"
OPKG_CONF="/opt/etc/opkg/awg_manager.conf"

info()  { printf "\033[1;32m[+]\033[0m %s\n" "$1"; }
warn()  { printf "\033[1;33m[!]\033[0m %s\n" "$1"; }
error() { printf "\033[1;31m[-]\033[0m %s\n" "$1"; exit 1; }

# Определение архитектуры
detect_arch() {
    info "Определяю архитектуру..."
    ARCH=$(opkg print-architecture 2>/dev/null | grep '_kn' | awk '{print $2}' | sed 's/_kn.*//')
    [ -z "$ARCH" ] && error "Не удалось определить архитектуру. Это роутер Keenetic с Entware?"

    case "$ARCH" in
        mipsel-3.4|mips-3.4|aarch64-3.10) ;;
        *) error "Неподдерживаемая архитектура: $ARCH" ;;
    esac

    REPO_ARCH=$(echo "$ARCH" | sed 's/-\([0-9]\)/-k\1/')
    info "Архитектура: $ARCH (repo: $REPO_ARCH)"
}

# Добавление репозитория
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

# Выбор версии
choose_version() {
    info "Получаю последнюю версию с GitHub..."
    LATEST=$(curl -s https://api.github.com/repos/hoaxisr/awg-manager/releases/latest | \
             sed -n 's/.*"tag_name": "\([^"]*\)".*/\1/p' | sed 's/^v//')

    [ -z "$LATEST" ] && error "Не удалось получить последнюю версию с GitHub"

    echo ""
    info "Последняя доступная версия: $LATEST"
    printf "\033[1;36mВведите версию для установки (Enter = %s): \033[0m" "$LATEST"
    read -r USER_VER

    if [ -z "$USER_VER" ]; then
        VERSION="$LATEST"
        info "Выбрана последняя версия: $VERSION"
    else
        VERSION="$USER_VER"
        info "Выбрана версия: $VERSION"
    fi
}

# Установка через opkg (с возможностью downgrade)
install_awg_manager() {
    BEFORE=$(opkg list-installed 2>/dev/null | awk '/^awg-manager /{print $3}' || echo "не установлено")

    info "Обновляю список пакетов (opkg update)..."
    opkg update >/dev/null 2>&1 || warn "opkg update завершился с ошибкой, продолжаем..."

    info "Устанавливаю awg-manager версии $VERSION..."
    if ! opkg install --force-downgrade awg-manager="$VERSION"; then
        error "Не удалось установить awg-manager версии $VERSION"
    fi

    AFTER=$(opkg list-installed 2>/dev/null | awk '/^awg-manager /{print $3}')

    if [ "$BEFORE" = "не установлено" ]; then
        info "Установлено: $AFTER"
    elif [ "$BEFORE" = "$AFTER" ]; then
        info "Версия не изменилась ($AFTER)"
    else
        info "Обновлено: $BEFORE → $AFTER"
    fi
}

# Запуск сервиса
start_service() {
    info "Перезапускаю сервис..."
    /opt/etc/init.d/S99awg-manager restart 2>/dev/null || \
    /opt/bin/awg-manager --service start 2>/dev/null || \
    warn "Не удалось автоматически запустить сервис. Запустите вручную: /opt/etc/init.d/S99awg-manager start"
}

# Проверка работоспособности
health_check() {
    PORT=$(sed -n 's/.*"port"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' \
        /opt/etc/awg-manager/settings.json 2>/dev/null || echo "2222")

    info "Проверяю работу сервиса (порт $PORT)..."

    for i in 1 2 3; do
        if curl -sf "http://127.0.0.1:${PORT}/api/health" >/dev/null 2>&1; then
            info "Сервис успешно запущен!"
            return 0
        fi
        sleep 2
    done

    warn "Сервис не отвечает на порту $PORT (может потребоваться время)"
}

# Показать адрес веб-интерфейса
show_access_url() {
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

# ====================== MAIN ======================
detect_arch
add_repo
choose_version
install_awg_manager
start_service
health_check
show_access_url

info "Установка/обновление завершено!"
