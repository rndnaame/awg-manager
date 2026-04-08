cat > /tmp/install_awg.sh << 'EOF'
#!/bin/sh
# AWG Manager — установщик с правильным выбором версии

set -e

info()  { printf "\033[1;32m[+]\033[0m %s\n" "$1"; }
error() { printf "\033[1;31m[-]\033[0m %s\n" "$1"; exit 1; }

info "Определяю архитектуру..."
ARCH=$(opkg print-architecture 2>/dev/null | grep '_kn' | awk '{print $2}' | sed 's/_kn.*//')
[ -z "$ARCH" ] && error "Не удалось определить архитектуру."

REPO_ARCH=$(echo "$ARCH" | sed 's/-\([0-9]\)/-k\1/')
info "Архитектура: $ARCH (repo: $REPO_ARCH)"

mkdir -p /opt/etc/opkg
echo "src/gz hoaxisr http://repo.hoaxisr.ru/$REPO_ARCH" > /opt/etc/opkg/awg_manager.conf
info "Репозиторий добавлен"

info "Получаю последнюю версию..."
LATEST=$(curl -s https://api.github.com/repos/hoaxisr/awg-manager/releases/latest | \
         sed -n 's/.*"tag_name": "\([^"]*\)".*/\1/p' | sed 's/^v//')

[ -z "$LATEST" ] && LATEST="2.7.6"

echo ""
info "Последняя версия: \033[1;36m$LATEST\033[0m"
printf "\033[1;36mВведите версию (Enter = %s): \033[0m" "$LATEST"
read -r INPUT_VER

if [ -z "$INPUT_VER" ]; then
    VERSION="$LATEST"
else
    VERSION="$INPUT_VER"
fi

info "Устанавливаю версию: $VERSION"

opkg update >/dev/null 2>&1 || true

if ! opkg install --force-downgrade "awg-manager=$VERSION"; then
    error "Не удалось установить awg-manager=$VERSION. Проверьте, существует ли такая версия."
fi

info "Успешно установлено!"

info "Перезапускаю сервис..."
/opt/etc/init.d/S99awg-manager restart 2>/dev/null || true

info "Готово! 🎉"
EOF

chmod +x /tmp/install_awg.sh
/tmp/install_awg.sh
