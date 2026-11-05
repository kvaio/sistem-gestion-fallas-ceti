# Sistema de Gestión de Fallas CETI

## Descripción

Plataforma web para administrar un negocio de servicios técnicos dedicado a la reparación de equipos de cómputo, electrónica y electrodomésticos.

Incluye gestión de órdenes de servicio, seguimiento de reparaciones, convenios empresariales B2B, tarifas preferenciales y comisiones.

## Objetivo general

Desarrollar un sistema que centralice el proceso de atención técnica, desde la recepción de un equipo hasta su entrega.

## Tecnologías

| Componente | Tecnología |
|---|---|
| Frontend | React + Vite |
| Backend | Node.js + Express |
| Lenguaje | JavaScript |
| Base de datos | PostgreSQL |
| ORM | Prisma 7 |
| API | REST |
| Autenticación prevista | JWT de acceso + refresh token; Argon2id para contraseñas |

## Roles

- ADMIN: administración global.
- GERENTE: supervisión y convenios.
- TECNICO: diagnóstico y reparación.
- RECEPCIONISTA: recepción y órdenes de servicio.
- CLIENTE_B2B: seguimiento de equipos y órdenes de su empresa.

## Flujo de servicio

Recepción → Diagnóstico → Reparación → Control de Calidad → Entrega.

## Modelo de datos inicial

- Usuario.
- Convenio.
- Equipo.
- OrdenServicio.
- BitacoraOrden.

## Arquitectura

- frontend/: aplicación React.
- backend/: API Express.
- backend/src/config/: configuración y conexiones.
- backend/src/modules/: módulos funcionales.
- backend/src/middlewares/: seguridad y validaciones.
- backend/src/routes/: rutas de la API.
- backend/prisma/: esquema y migraciones.
- docs/: documentación técnica.

## Plan de desarrollo

### Sprint 1
- Autenticación.
- Usuarios y roles.
- Convenios empresariales.
- Descuentos y tarifas preferenciales.

### Sprint 2
- Equipos.
- Órdenes de servicio.
- Asignación de técnicos.
- Seguimiento y bitácora.
- Control de calidad y entrega.
- Portal B2B.

## Configuración local

| Servicio | Dirección |
|---|---|
| Frontend | http://localhost:5173 |
| Backend | http://localhost:3001 |
| Health check | http://localhost:3001/api/health |
| PostgreSQL | localhost:5434 |
| Base de datos | gestion_fallas |

## Documentación

Consultar `docs/CONTEXTO_GPT_DESKTOP.md` para conocer las reglas generales de desarrollo y `docs/DISEÑO_TECNICO_SPRINT_1.md` para la arquitectura, permisos, contratos y plan aprobado del Sprint 1.

## Estado

Base técnica inicial preparada. La configuración de Fase 0 está lista y el esquema de Fase 1 está preparado para revisión. No se ha aplicado ninguna migración; la implementación funcional del Sprint 1 está pendiente.
