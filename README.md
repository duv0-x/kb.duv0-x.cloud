# kb.duv0-x.cloud

Instancia de [Scriba](https://github.com/duv0-x/scriba) de Duván Ballén: la base de conocimiento `ia-kb`, escrita por agentes de IA vía MCP y leída en `https://kb.duv0-x.cloud`. Corre en una Raspberry Pi detrás de un túnel de Cloudflare, con Cloudflare Access delante de la web.

Este repo no tiene código de Scriba ni notas. Solo guarda **qué versión corre la instancia, su configuración y cómo se despliega**. Las notas viven en el repo privado `duv0-x/ia-kb`, que Scriba clona y al que empuja sus commits.

## Contenido

| Archivo | Qué es |
|---------|--------|
| `scriba.version` | Versión de Scriba que corre la instancia. La Pi la lee cada 5 minutos (`SCRIBA_VERSION_URL`). |
| `config/scriba.env` | Puerto, URL pública y zona horaria. Sin secretos. |
| `config/scriba-update.env` | Apunta el actualizador a `scriba.version` de este repo. |
| `pi/provision.sh` | Aprovisiona la instancia en la Pi (idempotente). |
| `pi/cloudflared-ingress.yml` | Regla del túnel para `kb.duv0-x.cloud`. |
| `docs/runbook.md` | Puesta en marcha paso a paso y cómo revertir cada paso. |

## Actualizar Scriba

1. Publicar una release en `duv0-x/scriba` (tag `vX.Y.Z`).
2. PR aquí cambiando `scriba.version`.
3. Al mergear, `scriba-update` la instala en la Pi en ≤5 min (más la caché de `raw.githubusercontent.com`). Si `/readyz` no responde, hace rollback del binario y de `state.db`, borra el índice (se reconstruye) y anota la versión en `/scriba/.failed` para no reintentarla.

## Secretos

Ninguno vive en este repo ni en variables de entorno de la Pi (ADR-006 de Scriba):

- **GitHub**: se conecta desde la pantalla **Conectores** (device flow de la OAuth App "Scriba"). El token queda cifrado en `/scriba/data/state.db` con la llave `/scriba/data/secret.key`.
- **Tokens de agente**: se crean en **Agentes**; Scriba solo guarda su hash. Cada valor se guarda en Bitwarden y se usa en el cliente (`SCRIBA_TOKEN` del plugin de Claude Code).
