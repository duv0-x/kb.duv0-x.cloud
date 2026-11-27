# Runbook: puesta en marcha de kb.duv0-x.cloud

Cada paso escribe en producción y se ejecuta con autorización explícita, reportando el resultado antes del siguiente. El orden importa: **Access antes que el DNS**.

| Paso | Qué | Dónde | Cómo revertir |
|---|---|---|---|
| P1 | Solo lectura: `ss -ltn` (8090 libre), `free -m`, `df -h /`, `git --version`, `systemctl is-active gremio cloudflared`, huella SSH | Pi | — |
| P2 | Copiar este repo a la Pi y `sudo ./pi/provision.sh` | Pi | `sudo systemctl disable --now scriba scriba-update.timer`, `sudo rm -rf /scriba /usr/local/bin/scriba-update /etc/systemd/system/scriba*.{service,timer}`, `sudo userdel scriba`, `sudo systemctl daemon-reload` |
| P3 | Comprobar: `curl -s 127.0.0.1:8090/readyz`, `journalctl -u scriba`, `systemctl status scriba` (memoria) | Pi | — |
| P4 | Cloudflare Access: app self-hosted `kb.duv0-x.cloud` (*Allow*: el correo del dueño) y app `kb.duv0-x.cloud/mcp` (*Bypass*: everyone) | Dashboard de Cloudflare | Borrar las dos apps |
| P5 | Añadir `pi/cloudflared-ingress.yml` a `/etc/cloudflared/config.yml` antes del `http_status:404`, `cloudflared tunnel ingress validate`, `sudo systemctl restart cloudflared` (corte de segundos también para Gremio). CNAME: `cloudflared tunnel route dns alfred kb.duv0-x.cloud` desde la Mac con `cert.pem` | Pi y Mac | Quitar la regla y reiniciar `cloudflared`; borrar el CNAME en el dashboard |
| P6 | Desde fuera: `https://kb.duv0-x.cloud` pide el login de Access; `curl -i https://kb.duv0-x.cloud/mcp` sin token responde 401 de Scriba | Mac | — |
| P7 | Conectores → Conectar GitHub (device flow) → Bienvenida → Importar desde GitHub `duv0-x/ia-kb` → push activo | Navegador | Desconectar GitHub en Conectores; `sudo rm -rf /scriba/data/vault` (desde v0.7.0: `/scriba/data/kbs/ia-kb/vault`) |
| P8 | Agentes → token `claude-code-mac` → Bitwarden → `SCRIBA_URL` y `SCRIBA_TOKEN` en el shell de Claude Code | Navegador y Mac | Revocar el token en Agentes |
| P9 | Prueba de punta a punta: `claude -p` con el plugin escribe una nota → aparece en vivo → commit `claude-code-mac via Scriba` → llega a GitHub en ≤30 s → `git -C ~/Documents/ia-kb pull` la trae; luego se borra | Mac y navegador | Borrar la nota |

## Rutas en Bypass de Access (conectores de Claude, desde v0.5.0)

La app `scriba-mcp` (*Bypass*: everyone) tiene estos destinos, **exactos y sin comodines**:

- `kb.duv0-x.cloud/mcp`
- `kb.duv0-x.cloud/.well-known/oauth-protected-resource`
- `kb.duv0-x.cloud/.well-known/oauth-protected-resource/mcp`
- `kb.duv0-x.cloud/.well-known/oauth-authorization-server`
- `kb.duv0-x.cloud/oauth/register`
- `kb.duv0-x.cloud/oauth/token`

`/oauth/authorize` lo cubre la app `scriba` (*Allow*): quien llegue a esa pantalla puede emitir un token. Comprobar desde fuera tras cualquier cambio:

```sh
B=https://kb.duv0-x.cloud
for p in .well-known/oauth-protected-resource/mcp .well-known/oauth-authorization-server; do curl -s -o /dev/null -w "$p %{http_code}\n" $B/$p; done  # 200
curl -s -X POST $B/oauth/token                                    # invalid_client
curl -s -o /dev/null -w '%{http_code}\n' $B/oauth/authorize       # 302 al login de Access
curl -s -o /dev/null -w '%{http_code}\n' $B/                      # 302 al login de Access
```

Si Claude no logra conectar y en *Security Events* aparece un bloqueo de Browser Integrity Check, desactivarlo solo en esas rutas.

**Antes de volver a una versión anterior a v0.5.0**, revocar los conectores en Agentes: el binario viejo ignora la expiración de sus tokens.

## Varias bases (desde v0.7.0, ADR-013 de Scriba)

Layout en la Pi:

```
/scriba/data/
  state.db  secret.key  tmp/      # de la instancia: agentes, OAuth, conectores, Kindle
  kbs/<slug>/vault/               # repo git de la base
  kbs/<slug>/index.db             # índice, reconstruible
```

La lista de bases es el contenido de `kbs/`. La base por defecto es `ia-kb` (migrada desde `data/vault` el 2026-11-26, kb.duv0-x.cloud#15). Desde v0.8.0 (2026-11-27, kb.duv0-x.cloud#18) `scriba.service` arranca con `--data /scriba/data`: `--vault` y `--db` ya no existen (scriba#48). `scriba-update` no reinstala la unidad; si una versión futura cambia `deploy/scriba.service`, hay que instalarla a mano (con `sudo`) antes de subir `scriba.version`.

- **Crear una base:** *Bases* (`/kbs`) → slug (minúsculas, números y guiones, hasta 40; no se puede cambiar) → vacía con la plantilla o desde un `.zip`.
- **Repo de backup:** crear el repo privado en GitHub (`duv0-x/<repo>`) → *Conectores* → elegir la base → elegir el repo → activar el push. La cuenta de GitHub es una sola para la instancia; el repo y el push son por base. Si la base está vacía, Scriba clona el repo; si no, lo enlaza.
- **Token de agente:** *Agentes* → nombre y base. Cada token ve una sola base; los tokens anteriores a v0.7.0 quedaron ligados a `ia-kb`. Los conectores OAuth de Claude eligen la base en el consentimiento.
- **Borrar una base:** *Bases* → teclear el slug. Borra `kbs/<slug>/` y revoca sus tokens (401). La base por defecto no se puede borrar. El repo de GitHub no se toca.
- **Access:** `/k/*` y `/kbs` quedan detrás de la app `scriba` (*Allow*). Las rutas Bypass no cambian (lista de arriba). Una ruta vieja (`/n/…`, `/buscar`…) responde 301 a `/k/ia-kb/…`; desde fuera, Access la intercepta antes con 302 al login.
- **Rollback desde v0.8.0:** el automático solo es seguro hacia v0.7.0, que entiende `--data` (ADR-013, decisión 10). Para volver más atrás, primero restaurar `/etc/systemd/system/scriba.service.pre-kb18` (unidad con `--vault`).
- **Rollback a una versión anterior a v0.7.0:** el `scriba-update` de v0.7.0 devuelve `kbs/<slug>/vault` a `data/vault` si solo hay una base. Con dos o más no lo hace: hay que borrar las demás primero.
- **Edición en línea (desde v0.9.0, 2026-11-27, kb.duv0-x.cloud#20):** el lector es el editor (CodeMirror 6 con Live Preview y autosave). El `PUT` de autosave va a la ruta del lector (`/k/<kb>/n/<path>`), queda detrás de la app `scriba` (*Allow*) y **no** se agrega a Bypass. El commit `web: actualiza <path>` se hace tras ~60 s sin guardados en esa ruta, o antes de una escritura de agente en ella. Con presencia de un agente, el PUT responde 423 y el editor queda en solo lectura. `/editar/<path>` responde 301 al lector.
- **Memoria (RSS de `scriba`, 2026-11-26, v0.7.0):** 39 MB con `ia-kb` (519 notas) recién arrancada; 44,5 MB con `ia-kb` y una base `prueba`; 46,7 MB después de borrarla. `MemoryMax=192M`. La Pi tenía 699 MB disponibles, compartidos con Gremio.

## Operación

- Logs: `journalctl -u scriba -f`; actualizaciones: `journalctl -u scriba-update`.
- Versión instalada: `cat /scriba/.release`. Versión que falló y no se reintenta: `cat /scriba/.failed`.
- Reconstruir el índice de una base: `sudo systemctl stop scriba && sudo rm -f /scriba/data/kbs/<slug>/index.db* && sudo systemctl start scriba`.
- Si se pierden `state.db` o `secret.key`: reconectar GitHub en Conectores y crear tokens de agente nuevos. El vault está en GitHub.
