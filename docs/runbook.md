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
| P7 | Conectores → Conectar GitHub (device flow) → Bienvenida → Importar desde GitHub `duv0-x/ia-kb` → push activo | Navegador | Desconectar GitHub en Conectores; `sudo rm -rf /scriba/data/vault` |
| P8 | Agentes → token `claude-code-mac` → Bitwarden → `SCRIBA_URL` y `SCRIBA_TOKEN` en el shell de Claude Code | Navegador y Mac | Revocar el token en Agentes |
| P9 | Prueba de punta a punta: `claude -p` con el plugin escribe una nota → aparece en vivo → commit `claude-code-mac via Scriba` → llega a GitHub en ≤30 s → `git -C ~/Documents/ia-kb pull` la trae; luego se borra | Mac y navegador | Borrar la nota |

## Operación

- Logs: `journalctl -u scriba -f`; actualizaciones: `journalctl -u scriba-update`.
- Versión instalada: `cat /scriba/.release`. Versión que falló y no se reintenta: `cat /scriba/.failed`.
- Reconstruir el índice: `sudo systemctl stop scriba && sudo rm -f /scriba/data/scriba.db* && sudo systemctl start scriba`.
- Si se pierden `state.db` o `secret.key`: reconectar GitHub en Conectores y crear tokens de agente nuevos. El vault está en GitHub.
