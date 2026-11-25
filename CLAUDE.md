# CLAUDE.md — kb.duv0-x.cloud

Repo de la **instancia** de Scriba de Duván (`https://kb.duv0-x.cloud`), no del producto. El código de Scriba vive en `/Users/lx-duv0-x/Documents/Repositories/scriba`; las notas, en `duv0-x/ia-kb`, que se leen y escriben solo vía Scriba (MCP `scriba`; no hay clon local). Español, con términos técnicos en inglés.

## Reglas

- **Esto es producción.** Cualquier escritura en la Pi `alfred` o en Cloudflare requiere autorización explícita, paso a paso, y se reporta el resultado antes de seguir.
- **Nunca commitear secretos.** El token de GitHub se configura en Conectores y los tokens de agente se guardan en Bitwarden.
- Subir de versión = PR que cambia `scriba.version`; el merge lo aplica en la Pi.
- La web va detrás de Cloudflare Access; la app `scriba-mcp` tiene una regla *Bypass* solo para las rutas que Scriba protege por sí mismo (lista en `docs/runbook.md`). `/oauth/authorize` queda detrás de Access: nunca abrir `/oauth/*`. No quitar ese orden: crear el DNS sin Access expone la base.
- La Pi: `alfred@192.168.1.72`, Debian 13 arm64, solo por cable (`eth0`). Comparte RAM (1 GB) con Gremio (`127.0.0.1:8081`, repo `work.duv0-x.cloud`). Su llave SSH ED25519 es `SHA256:vtZ1eNuK2kbQLhIHnJ/dkJcoJTiOzHZHsRkfEh17jBo`. Si cambia, parar y preguntar.

## Contexto

- Runbook: `docs/runbook.md`.
- Decisiones: ADRs en el repo `scriba` (`docs/adr/`) y el plan `plans/2026-11-16-scriba-1-mvp-y-migracion.md` de la KB (PR5): https://kb.duv0-x.cloud/n/plans/2026-11-16-scriba-1-mvp-y-migracion.md
