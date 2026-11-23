#!/bin/bash
# Aprovisiona la instancia de Scriba de kb.duv0-x.cloud en la Pi `alfred`. Idempotente.
# Correr como root desde una copia de este repo en la Pi:  sudo ./pi/provision.sh
# Instala la versión de scriba.version con las plantillas deploy/ de esa misma release.
set -euo pipefail

here=$(cd "$(dirname "$0")/.." && pwd)
REPO=duv0-x/scriba
DIR=/scriba

version=$(tr -d '[:space:]' < "$here/scriba.version")
if ! [[ "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "scriba.version inválido: '$version'" >&2
  exit 1
fi
case "$(uname -m)" in
  aarch64|arm64) arch=arm64 ;;
  x86_64|amd64) arch=amd64 ;;
  *) echo "arquitectura no soportada: $(uname -m)" >&2; exit 1 ;;
esac

echo "== paquetes"
command -v git >/dev/null || { apt-get update -q && apt-get install -y -q git; }

echo "== usuario y directorios"
id scriba >/dev/null 2>&1 || useradd --system --home "$DIR" --shell /usr/sbin/nologin scriba
install -d -m 0755 -o root -g root "$DIR"
# data/: vault, índice, state.db y secret.key; tmp/ es el TMPDIR de scriba.service (zips y askpass de git en disco).
install -d -m 0700 -o scriba -g scriba "$DIR/data" "$DIR/data/tmp"
install -m 0600 -o root -g root "$here/config/scriba.env" "$DIR/scriba.env"
install -m 0600 -o root -g root "$here/config/scriba-update.env" "$DIR/scriba-update.env"

echo "== release $version"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
file="scriba_${version#v}_linux_${arch}.tar.gz"
curl -fsSL -o "$tmp/$file" "https://github.com/$REPO/releases/download/$version/$file"
curl -fsSL -o "$tmp/checksums.txt" "https://github.com/$REPO/releases/download/$version/checksums.txt"
(cd "$tmp" && sha256sum -c --ignore-missing checksums.txt)
mkdir "$tmp/new"
tar -xzf "$tmp/$file" -C "$tmp/new"

install -m 0755 -o root -g root "$tmp/new/deploy/scriba-update" /usr/local/bin/scriba-update
install -m 0644 -o root -g root "$tmp/new/deploy/scriba.service" "$tmp/new/deploy/scriba-update.service" \
  "$tmp/new/deploy/scriba-update.timer" /etc/systemd/system/
systemctl daemon-reload

# Primera instalación: el binario va antes de arrancar el servicio. Después, las actualizaciones las hace
# scriba-update.timer. No hay paso de "dueño": la primera persona entra por Cloudflare Access y ve la bienvenida.
if [ ! -f "$DIR/scriba" ]; then
  install -m 0755 -o root -g root "$tmp/new/scriba" "$DIR/scriba"
  echo "$version" > "$DIR/.release"
fi

echo "== servicios"
systemctl enable --now scriba.service scriba-update.timer
for _ in $(seq 1 30); do
  if curl -sf -o /dev/null http://127.0.0.1:8090/readyz; then
    echo "scriba $(cat "$DIR/.release") listo en 127.0.0.1:8090"
    exit 0
  fi
  sleep 2
done
echo "scriba no respondió /readyz; revisa: journalctl -u scriba" >&2
exit 1
