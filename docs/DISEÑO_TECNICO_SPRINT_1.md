# Diseño técnico definitivo — Sprint 1

**Estado:** Fase 1 preparada en Prisma; migración incremental generada con `--create-only` y revisada. Fase 2 de autenticación implementada; migración pendiente de aplicación.  
**Alcance:** decisiones y estado vigente del modelo, migración y autenticación. No se aplicó la migración ni se alteró la base de datos.

## 1. Arquitectura definitiva

Se conserva el stack actual: React + Vite, Node.js + Express, JavaScript, PostgreSQL, Prisma 7 y API REST. El backend se organiza por módulos de negocio con rutas, controladores, servicios y validaciones separados. Las reglas de autorización viven en el servidor; la interfaz solo refleja permisos.

`app.js` monta routers versionados bajo `/api/v1`; `server.js` carga y valida configuración antes de escuchar, usando el puerto 3001 como valor predeterminado. Un middleware central de errores traduce errores conocidos a respuestas HTTP uniformes. Prisma se crea una sola vez con el adaptador PostgreSQL ya empleado por el proyecto.

Los módulos del sprint son `auth`, `usuarios`, `convenios` y, transversalmente, `auditoria`. La autenticación depende de usuarios y sesiones; usuarios, convenios y condiciones comerciales generan auditoría dentro de la misma transacción que la mutación cuando sea posible.

## 2. Matriz completa de permisos

La matriz describe permisos de Sprint 1. La validación debe cubrir tanto el rol como el alcance del recurso. “Propio” significa el usuario autenticado; “propio convenio” significa el convenio asociado al usuario B2B. No se conceden permisos implícitos por ocultar o mostrar controles en el frontend.

| Capacidad | ADMIN | GERENTE | TECNICO | RECEPCIONISTA | CLIENTE_B2B |
|---|---|---|---|---|---|
| Login, refresh, logout, consultar `/auth/me` | Sí | Sí | Sí | Sí | Sí |
| Consultar/editar perfil propio; cambio de contraseña propio | Sí | Sí | Sí | Sí | Sí |
| Listar y consultar usuarios de la organización | Sí | Sí | No | No | No |
| Crear TECNICO, RECEPCIONISTA o CLIENTE_B2B | Sí | Sí | No | No | No |
| Editar datos no privilegiados de esos roles | Sí | Sí | No | No | No |
| Activar/desactivar TECNICO, RECEPCIONISTA o CLIENTE_B2B | Sí | Sí | No | No | No |
| Crear, cambiar o asignar rol ADMIN o GERENTE | Sí | No | No | No | No |
| Modificar el rol propio o elevar privilegios propios | Sí, según política de administración; no autoescalamiento por endpoint de GERENTE | No | No | No | No |
| Administrar convenios, descuentos y tarifas | Sí | Sí | No | No | No |
| Consultar convenio y tarifas | Todos | Todos | No | No | Solo propio convenio (lectura) |
| Consultar auditoría administrativa | Sí | Sí, dentro del alcance de negocio | No | No | No |
| Consultar equipos/órdenes | Fuera del alcance funcional del Sprint 1; Sprint 2 aplicará permisos propios | Fuera del alcance funcional del Sprint 1 | Fuera del alcance funcional del Sprint 1 | Fuera del alcance funcional del Sprint 1 | Sprint 2: solo de su convenio |

Reglas obligatorias:

- GERENTE puede crear, editar, activar y desactivar TECNICO, RECEPCIONISTA y CLIENTE_B2B, pero nunca crear GERENTE/ADMIN ni asignar o modificar roles administrativos.
- GERENTE no puede modificar su rol, cambiar su estado para eludir controles, cambiar su propio convenio ni ejecutar acciones que eleven privilegios propios. Un ADMIN que modifique su propio rol requerirá política explícita y salvaguarda contra dejar el sistema sin administradores; recomendación: impedir auto degradación si es el último ADMIN activo.
- Un GERENTE no administra cuentas ADMIN ni GERENTE. Un usuario no puede modificar a otro usuario con rol superior o equivalente fuera de la capacidad otorgada expresamente.
- ADMIN conserva el control administrativo total, sujeto a impedir que la última cuenta ADMIN activa quede deshabilitada o sin acceso.
- Las bajas son lógicas (`activo=false`). Desactivar un usuario revoca todas sus sesiones activas en la misma transacción o con un proceso idempotente y observable.
- CLIENTE_B2B solo lee el convenio vinculado y, en Sprint 2, equipos/órdenes alcanzables a través de ese convenio. No se aceptará un `convenioId` confiado del cliente para decidir el ámbito; se deriva de la identidad autenticada.
- TECNICO y RECEPCIONISTA pueden usar autenticación y su perfil en este sprint. Sus permisos operativos se definirán al diseñar Sprint 2.

## 3. Flujos de autenticación y sesiones

### Inicio de sesión

1. Validar cuerpo, normalizar email y aplicar límite de intentos por IP y cuenta normalizada. Evitar bloqueo permanente explotable; responder con espera temporal y mensaje genérico.
2. Buscar usuario por email. Comprobar que esté activo. Verificar contraseña con Argon2id y parámetros configurables/calibrados para el entorno; nunca registrar contraseña, hash, JWT o refresh token.
3. Crear una sesión con identificador, hash del refresh token, fecha de creación/expiración y metadatos mínimos (por ejemplo, último uso). Entregar refresh token aleatorio opaco solo en cookie `HttpOnly`.
4. Emitir JWT de acceso de corta duración (inicialmente 15 minutos) como respuesta JSON. Claims mínimos: `sub`, `role`, `iss`, `aud`, `iat`, `exp`, `jti`. No incluir secretos ni información comercial. Fijar y verificar explícitamente algoritmo, emisor, audiencia y expiración.
5. El cliente mantiene el access token solo en memoria. No usar `localStorage` ni `sessionStorage` para tokens.

### Solicitudes autenticadas

El frontend envía el access token en `Authorization: Bearer`. `authenticate` verifica firma y claims y resuelve el estado vigente de usuario/sesión según la política de revocación. `authorize` verifica rol/acción. Los servicios vuelven a aplicar ámbito de convenio en las consultas; nunca basta con validar el UUID recibido. Los cambios de rol, estado y convenio deben surtir efecto en las solicitudes siguientes, sin depender de un JWT con permisos antiguos.

### Refresh rotativo y revocación

`POST /auth/refresh` requiere cookie válida y protección CSRF/origen. El backend compara el hash del token, verifica vigencia y estado del usuario, invalida el refresh usado y crea uno nuevo en una operación atómica. Si detecta reutilización de un token ya rotado/revocado, revoca la familia de sesión y requiere autenticación de nuevo. El refresh token en base de datos se guarda como hash de un secreto aleatorio de alta entropía; no como texto plano.

La cookie será `HttpOnly`, `SameSite=Lax`, `Secure` en producción, con `Path` limitado al endpoint de autenticación si el diseño del cliente lo permite y expiración alineada a la sesión. CORS enumera orígenes permitidos y solo habilita credentials para ellos.

### Protección CSRF y validación de origen

Todo endpoint que use cookies (refresh y logout) comprueba `Origin`/`Referer` contra allowlist estricta y exige token CSRF en header, ligado a la sesión (patrón synchronizer token o double-submit firmado). La estrategia elegida se implementa de forma consistente; `SameSite=Lax` es defensa adicional, no sustituto de CSRF. Rechazar origen ausente o no permitido en solicitudes de navegador con cookie, documentando las excepciones para clientes no navegador.

### Logout y desactivación

Logout revoca la sesión actual, limpia la cookie con los mismos atributos y deja expirar el access token breve. La desactivación de una cuenta revoca todas sus sesiones. Si se requiere invalidación inmediata del access token, middleware verifica una versión de credenciales/estado o una lista de revocación; de otro modo la ventana máxima es la vida restante del JWT (15 minutos). La decisión debe quedar explícita en implementación.

## 4. Modelo Prisma y migración (pendiente de aplicación)

El esquema conserva `Usuario`, `Convenio`, `Equipo`, `OrdenServicio` y `BitacoraOrden`. La Fase 1 quedó preparada en `backend/prisma/schema.prisma` y validada por Prisma. La migración incremental está generada e inspeccionada, pero no aplicada.

### Sesiones

`Sesion`: una fila por refresh token de una familia; `id`, `usuarioId`, `familiaId`, `tokenHash` SHA-256 hexadecimal único, `creadoEn`, `expiraEn`, `revocadoEn`, `ultimoUsoEn` y `reemplazoDeId` para encadenar rotaciones. Tiene FK a `Usuario`, unicidad del hash y de cada predecessor, e índices por usuario/estado, familia y expiración. El refresh original nunca se persiste en claro.

### Tarifas con historial

`TarifaConvenio`: FK a `Convenio` y al usuario que la creó, `claveServicio` (texto temporal; catálogo en Sprint 2), modalidad enum `PRECIO_FIJO` o `DESCUENTO_PORCENTUAL`, valor `Decimal(12,2)`, moneda MXN por defecto y fechas `vigenteDesde`/`vigenteHasta`. La clave única convenio/servicio/fecha de inicio evita versiones duplicadas; los cambios cierran vigencia y crean otra fila. La migración añade `CHECK` para modalidad, valor y vigencia, y una restricción PostgreSQL `EXCLUDE USING gist` con rangos semiabiertos `[)` por convenio/servicio. Así se permiten periodos adyacentes y se rechaza cualquier solapamiento incluso en escrituras concurrentes. Requiere la extensión `btree_gist`; la API también validará y traducirá el conflicto a un error HTTP uniforme.

`Convenio.descuentoPorcentaje` existente se conserva como descuento general predeterminado. Conviene agregar vigencia/actor o mantener historial de cambios en `AuditoriaCambio`; no sobrescribir silenciosamente condiciones previas.

### Auditoría

`AuditoriaCambio`: actor (`actorUsuarioId` nullable solo para eventos automáticos), `origen` (`ADMINISTRATIVO`/`AUTOMATICO`), entidad, identificador, operación, fecha, valores anteriores/nuevos JSON y request ID opcional. Tiene FK restrictiva al actor para conservar referencias. Una restricción SQL hará obligatorio el actor para origen administrativo. `entidadId` es polimórfico y se valida desde el servicio. No guardar contraseñas, hashes, tokens ni secretos.

### Snapshot comercial de órdenes futuras

El esquema conserva `costo` y `comision` y agrega campos opcionales para snapshots futuros: convenio/tarifa aplicados, modalidad/valor, precio de lista, descuento, servicio neto, importe agregado de refacciones/materiales, porcentaje de comisión, moneda y JSON de condiciones. Los valores son nullable para no reinterpretar órdenes históricas. Las FK a convenio y tarifa son restrictivas; una tarifa usada no debe borrarse físicamente. En Sprint 2 se decidirán líneas detalladas si una orden cubre varios tipos de servicio. Los snapshots serán inmutables por regla de aplicación.

Los importes y porcentajes se representan con `Decimal`/`NUMERIC`, no `Float`; moneda inicial MXN. Se conserva `passwordHash` para Argon2id. La migración incremental contiene los `CHECK` para rangos y vigencias, integridad del hash de refresh, snapshots, auditoría y sesión, además de la restricción de exclusión indicada. Las relaciones de rotación enlazan una sesión sucesora con un único predecesor (`reemplazoDeId` único, autorrelación con FK RESTRICT); un trigger SQL comprueba mismo usuario/familia y que el predecesor esté revocado. No crear tablas de catálogo de servicios o materiales en este sprint.

La migración `backend/prisma/migrations/20261105101122_sprint1_auth_sessions/migration.sql` fue generada con `prisma migrate dev --create-only`, inspeccionada y complementada con las restricciones/funciones SQL mencionadas. Se ejecutó un preflight de solo lectura para validar porcentajes existentes de convenio y comisiones no negativas. No se ejecutó ninguna operación de aplicación de migraciones ni escritura de esquema en la base.

## 5. Reglas comerciales y fórmulas

1. Determinar la tarifa para convenio + tipo de servicio + fecha de cotización. Si existe tarifa específica vigente, esta sustituye al descuento general. No acumular ambos.
2. Si la modalidad es `PRECIO_FIJO`, el precio de servicio será el importe fijo aplicable. Si es `DESCUENTO_PORCENTUAL`, aplicar el porcentaje al precio de lista vigente:
   - `netoServicio = precioLista × (1 − descuentoEspecífico / 100)`.
3. Si no hay tarifa específica vigente, aplicar descuento general del convenio al precio de lista:
   - `netoServicio = precioLista × (1 − descuentoGeneral / 100)`.
4. Refacciones/materiales se registran aparte y se excluyen de la base de comisión. La regla aprobada es:
   - `baseComision = suma de importes de servicio después del descuento`.
   - `comision = baseComision × porcentajeComisionAplicado / 100`.
   - `totalCobrar = netoServicio + refaccionesMateriales + otrosConceptos`, sujetos a reglas fiscales/contables aún por acordar.
5. Guardar en cada orden futura porcentaje, importe y condiciones comerciales aplicados (incluyendo snapshot de la tarifa/descuento y comisión). Ningún cambio posterior recalcula una orden histórica.
6. Usar precisión decimal definida y regla explícita de redondeo a moneda (propuesta: redondeo monetario a 2 decimales al nivel de línea y luego suma; confirmar con operación/contabilidad antes de codificar).

Decisiones cerradas: moneda inicial MXN; valores monetarios y porcentajes Decimal; tarifa específica sustituye al descuento general; comisión sobre servicio neto, excluyendo refacciones/materiales; snapshots conservan lo aplicado. Catálogo y precios de lista, impuestos y materiales corresponden al Sprint 2. Redondeo exacto y tratamiento contable de ajustes/devoluciones se cerrarán al diseñar cotizaciones/órdenes.

## 6. Contratos REST

Base `/api/v1`; JSON; IDs UUID; fechas ISO-8601; importes decimales serializados como strings para no perder precisión. Paginación uniforme `page`, `pageSize`, respuesta `{data, pagination}`. Errores uniformes `{error:{code,message,details?,requestId}}`. No incluir hashes ni secretos. Respuestas genéricas para credenciales inválidas y recursos B2B ajenos (404 para evitar revelar existencia).

### Autenticación

| Método/ruta | Acceso | Contrato resumido |
|---|---|---|
| `POST /auth/login` | Público, rate limit | `{email,password}` → `{user,accessToken,expiresIn:900}` y cookie refresh HttpOnly; error genérico si falla |
| `POST /auth/refresh` | Cookie + CSRF + origen válido | Rota refresh atómicamente → `{accessToken,expiresIn}` y nueva cookie |
| `POST /auth/logout` | Cookie/sesión + CSRF + origen válido | Revoca sesión, borra cookie → 204 |
| `GET /auth/me` | JWT válido | Perfil seguro: `id,nombre,email,rol,activo,convenioId` aplicando minimización |

### Usuarios

| Método/ruta | Permiso | Contrato resumido |
|---|---|---|
| `GET /users` | ADMIN, GERENTE | Filtros `rol`, `activo`, `q`; paginado; GERENTE ve usuarios que puede administrar |
| `POST /users` | ADMIN; GERENTE solo TECNICO/RECEPCIONISTA/CLIENTE_B2B | Alta con nombre, email, rol y convenio requerido para B2B; no aceptar hash ni campos privilegiados ocultos |
| `GET /users/:id` | ADMIN, GERENTE según jerarquía; propio usuario | Detalle seguro |
| `PATCH /users/:id` | ADMIN; GERENTE solo cuentas administrables; propio usuario solo perfil | Cambios permitidos por campo; rol de ADMIN/GERENTE solo ADMIN; GERENTE no autoedita privilegios |
| `POST /users/:id/activate` | ADMIN; GERENTE para roles no administrativos | Reactivación lógica, auditada |
| `POST /users/:id/deactivate` | ADMIN; GERENTE para roles no administrativos | Baja lógica; revoca todas las sesiones; auditada |
| `PATCH /users/me/password` | Usuario autenticado | `{currentPassword,newPassword}`; invalida otras sesiones y rota sesión actual según política |

Alta/cambio de contraseña administrativa deberá usar invitación o contraseña temporal de un solo uso, con expiración y cambio obligatorio, en vez de comunicar credenciales permanentes por canales inseguros. Diseñar el endpoint concreto en Fase 2/3.

### Convenios y condiciones

| Método/ruta | Permiso | Contrato resumido |
|---|---|---|
| `GET /convenios` | ADMIN, GERENTE | Lista paginada, filtros de activo/búsqueda |
| `POST /convenios` | ADMIN, GERENTE | Datos de empresa + descuento general; validación RFC/porcentajes |
| `GET /convenios/:id` | ADMIN, GERENTE; B2B solo propio | Detalle; convenio ajeno responde 404 |
| `PATCH /convenios/:id` | ADMIN, GERENTE | Editar datos y descuento general; cambio versionado/auditado |
| `POST /convenios/:id/deactivate` | ADMIN, GERENTE | Baja lógica; preservar órdenes/snapshots |
| `GET /convenios/:id/tarifas` | ADMIN, GERENTE; B2B solo propio (lectura) | Vigentes e historial según filtro autorizado |
| `POST /convenios/:id/tarifas` | ADMIN, GERENTE | Crear modalidad exactamente una: precio fijo o porcentaje, tipo y vigencia |
| `PATCH /convenios/:id/tarifas/:tarifaId` | ADMIN, GERENTE | Cerrar/versionar tarifa; no sobrescribir histórico ni cambiar órdenes |
| `GET /convenios/:id/auditoria` | ADMIN, GERENTE según alcance | Historial paginado con campos sensibles excluidos |

Estados inválidos o conflicto de vigencias devuelven 409; entradas inválidas 400. El catálogo y precio de lista base se definirán antes de implementar endpoints de cálculo/cotización, que pertenecen al futuro módulo de órdenes.

## 7. Estructura de carpetas objetivo

```text
backend/src/
├── app.js
├── server.js
├── config/{env.js,database.js,cors.js}
├── middlewares/{authenticate.js,authorize.js,csrf.js,validate.js,rateLimit.js,errorHandler.js}
├── modules/
│   ├── auth/{auth.routes.js,auth.controller.js,auth.service.js,session.service.js,auth.schemas.js}
│   ├── usuarios/{usuarios.routes.js,usuarios.controller.js,usuarios.service.js,usuarios.schemas.js}
│   ├── convenios/{convenios.routes.js,convenios.controller.js,convenios.service.js,convenios.schemas.js}
│   └── auditoria/{auditoria.service.js,auditoria.repository.js}
└── shared/{errors/,http/,security/}

frontend/src/
├── app/{App.jsx,router.jsx,AuthProvider.jsx}
├── api/{client.js,auth.js,usuarios.js,convenios.js}
├── components/{Layout/,ProtectedRoute.jsx,forms/}
├── features/{auth/,usuarios/,convenios/}
└── pages/{LoginPage.jsx,DashboardPage.jsx,usuarios/,convenios/,perfil/}
```

Esta es estructura objetivo; se crearán archivos solo conforme avance la implementación. No supone reemplazar los archivos actuales ni borrar directorios.

## 8. Requisitos de seguridad

- **Configuración central:** validar al inicio `NODE_ENV`, `PORT`, `DATABASE_URL`, `FRONTEND_URL`/lista de orígenes, secreto/llaves JWT y parámetros de expiración. Fallar con mensaje claro que nombre la variable faltante, nunca imprimir su valor.
- **Firma JWT:** si se conserva `JWT_SECRET`, rechazar valor ausente, placeholder, longitud/entropía insuficiente y configuración de producción insegura. Usar secreto aleatorio de al menos 32 bytes de entropía y comparar contra valores conocidos de ejemplo; preferir administrar secretos fuera del repositorio. Firmar y verificar con algoritmo fijado; validar `iss`, `aud`, `exp` y `sub`. Una alternativa futura es firma asimétrica con rotación de claves, no requisito inicial.
- **Contraseñas:** Argon2id; salt gestionado por biblioteca; no cifrar ni registrar contraseñas. Parámetros medidos en máquina objetivo y versionados en configuración. Respuestas genéricas y limitación de intentos.
- **Tokens/sesiones:** refresh opaco aleatorio, persistir hash, rotar de un solo uso, detectar replay, expiración y revocación; invalidar todas las sesiones al desactivar usuario y al cambiar credenciales sensibles. Access token breve, sin almacenamiento web persistente.
- **CSRF/origen/CORS:** allowlist explícita, jamás reflejar cualquier `Origin`; cookies con `HttpOnly`, `SameSite=Lax`, `Secure` en producción. Validar `Origin` y token CSRF en cada operación cookie; CORS no es autorización ni defensa CSRF.
- **Autorización multi-tenant:** derive `convenioId` del usuario autenticado y aplique filtro en el servicio/repositorio; probar IDOR con IDs válidos de otro convenio.
- **Entradas:** validar forma, tipo, tamaño, enumeraciones, límites de texto, UUID, email, RFC, porcentajes y fechas; rechazar propiedades no permitidas y asignación masiva.
- **Errores/logging:** códigos uniformes; no exponer stack, SQL, secretos o existencia de cuenta; registrar request ID. Redactar `Authorization`, cookies, contraseñas y tokens.
- **Auditoría:** operaciones administrativas siempre con actor autenticado; eventos automáticos pueden tener actor nulo y deben marcar tipo/origen de sistema. Cambios de rol, estado, convenio, descuento, tarifa y comisión registran antes/después. No registrar credenciales.
- **Operación:** HTTPS en despliegue, cabeceras Helmet, política de tamaño de body, límite de solicitudes y política de expiración/limpieza de sesiones. No usar credenciales de `.env.example` en entornos reales.

## 9. Estrategia de pruebas

No se define ni instala ahora un runner. En Fase 0 se inspeccionarán versiones disponibles y se seleccionará una herramienta compatible; pruebas de integración usarán una base PostgreSQL aislada, nunca datos locales de desarrollo/producción.

**Unitarias:** parámetros y verificación Argon2id; claims JWT; validación de entorno; políticas de rol y jerarquía GERENTE; matriz de campos modificables; resolución de tarifa; precedencia tarifa específica/general; precio neto, base de comisión, exclusión de materiales y redondeo.

**Integración auth/sesiones:** login válido/inválido/inactivo; límite de intentos; token expirado/audiencia/firma errónea; refresh válido; rotación; replay revoca familia; logout; CSRF y origen ausente/ajeno; cookie attrs; revocación de todas las sesiones al desactivar cuenta.

**Integración autorización y datos:** combinaciones rol-endpoint; GERENTE no crea/eleva ADMIN o GERENTE ni altera privilegios propios; bajas lógicas; usuario B2B solo consulta su convenio y un UUID ajeno devuelve 404; inputs inválidos, duplicados y conflictos de vigencia.

**Integración comercial/auditoría:** tarifa fija o porcentaje (nunca ambos); sustitución, no acumulación, del descuento general; comisión sobre servicio neto excluyendo refacciones; snapshot inmutable ante cambios posteriores; actor y before/after obligatorios para cambios administrativos; eventos automáticos identificados; atomicidad de mutación y auditoría.

**Frontend y regresión:** rutas y menús por rol; refresh tras recarga sin almacenamiento web; logout/expiración; formularios/errores; build/lint; smoke de health. Pruebas negativas de seguridad forman parte del criterio de aceptación.

## 10. Pantallas del frontend

1. Inicio de sesión.
2. Panel inicial distinto por rol y estado de sesión.
3. Perfil y cambio de contraseña.
4. Usuarios: lista, filtros, alta/edición, activar/desactivar; campos y roles disponibles según actor.
5. Convenios: lista, búsqueda, alta, detalle, edición y baja lógica.
6. Condiciones comerciales del convenio: descuento general, tarifas por tipo/modalidad, vigencias e historial. Validar exclusividad de modalidad antes de envío.
7. Historial de auditoría de cambios relevantes, solo roles autorizados.
8. Vista B2B de solo lectura para su propio convenio y condiciones; equipos y órdenes se incorporarán en Sprint 2.

Las pantallas protegidas no son frontera de seguridad: toda acción se autoriza nuevamente en API.

## 11. Plan definitivo de implementación por etapas

| Fase | Alcance y salida verificable |
|---|---|
| **Fase 0: ajustes técnicos y validación del entorno** | **Completada:** puerto predeterminado 3001; entorno y CORS centralizados; Node/npm/Prisma revisados; conexión confirmada a `localhost:5434/gestion_fallas` con lectura solamente. No se cambiaron datos. |
| **Fase 1: diseño y revisión del esquema Prisma y migración incremental** | **Preparada:** esquema validado, SQL incremental revisado y preflight de solo lectura ejecutado. Pendiente aplicar migración; catálogo y precios de lista quedan para Sprint 2. |
| **Fase 2: autenticación y sesiones** | **Implementada en código:** Argon2id, JWT 15 min, refresh rotativo persistido por hash, revocación/replay, cookie, CSRF/origen, login/refresh/logout/me, cambio de contraseña y pruebas unitarias. Requiere aplicar migración para funcionar contra PostgreSQL. |
| **Fase 3: usuarios, roles y permisos** | CRUD permitido, baja lógica, revocación de sesiones al desactivar, jerarquía de roles, validaciones y pruebas completas de matriz. |
| **Fase 4: convenios, descuentos, tarifas y comisiones** | CRUD convenio, descuento general, tarifas fijas/porcentuales con vigencia/historial, resolución comercial y snapshots para órdenes futuras; pruebas de fórmulas. |
| **Fase 5: auditoría y pruebas integrales del backend** | Auditoría con actor y before/after, eventos automáticos identificados, integración transaccional, pruebas end-to-end de seguridad, multi-tenant y reglas comerciales. |
| **Fase 6: frontend administrativo** | Login/sesión, perfil, usuarios, convenios, condiciones/tarifas, historial y vistas según rol, integrado con API. |
| **Fase 7: validación final del Sprint 1** | Ejecutar suite, lint/build, recorrido manual por rol, verificación de migración y documentación; registrar limitaciones y criterios de aceptación cumplidos. |

Las pruebas se ejecutan después de cada implementación importante. La base de datos no se ha modificado; las pruebas unitarias usan Prisma simulado y no requieren las tablas nuevas.

## Estado de implementación de autenticación (Fase 2)

El backend implementa Argon2id, access JWT HS256 de 15 minutos con `sub`, `role`, `iss`, `aud`, `iat`, `exp`, `jti` y `sid`; refresh opaco aleatorio con SHA-256 hexadecimal persistido en `Sesion`; rotación transaccional, revocación de familia ante reutilización, logout, `/auth/me`, cambio de contraseña con revocación, CSRF double-submit firmado, allowlist estricta de Origin y rate limiting de login. El middleware comprueba la sesión y el estado/rol vigentes en Prisma. La cuenta ADMIN inicial se crea mediante `npm run auth:bootstrap-admin`: requiere las tablas base disponibles, que `Usuario` esté vacío, solicita contraseña en consola sin eco y no tiene credenciales predeterminadas.

El frontend ya tiene login, cliente API con cookies `credentials: include`, access token solo en memoria, restauración vía refresh, logout y ruta básica protegida. No escribe tokens en `localStorage` ni `sessionStorage`.

Pruebas unitarias en `backend/test/unit` se ejecutan sin las tablas nuevas. Las pruebas de integración contra Prisma quedan para después de aplicar esta migración en una base de pruebas aislada.

## 13. Riesgos y decisiones técnicas pendientes

### Riesgos del estado actual

- Las tablas de autenticación/tarifas/auditoría aún no existen en PostgreSQL hasta aplicar la migración revisada; endpoints que consultan `Sesion` no funcionarán completamente antes de aplicarla.
- El puerto fallback 3000 detectado en la auditoría se corrigió a 3001 en Fase 0.
- La conexión de aplicación y Prisma CLI carga `backend/.env` en los comandos del proyecto; destino verificado `localhost:5434/gestion_fallas` mediante consulta de solo lectura. No se ejecutaron migraciones.
- La extensión PostgreSQL `btree_gist` debe estar permitida al usuario de base de datos al aplicar la migración.
- Las sesiones, tarifas, auditoría y campos de snapshots ya están preparados en el esquema, pero no existen en PostgreSQL hasta una migración aprobada. No hay todavía desglose de materiales ni líneas de servicio; se diseñarán en Sprint 2.
- El `test` script actual no ejecuta pruebas; escoger runner y preparar DB aislada es trabajo previo.

### Pendiente de decisión antes de Fase 1

- Catálogo/unidad de tipos de servicio y origen de precios de lista son trabajo de Sprint 2.
- Impuestos, redondeo contable, devoluciones y órdenes parcialmente ajustadas se definirán al diseñar cotizaciones/órdenes.
- Concretar la estructura de líneas de servicio/refacciones en órdenes de Sprint 2 para sostener la base de comisión.
- Refresh tiene duración inicial de siete días; definir luego expiración por inactividad y número máximo de sesiones simultáneas.
- Acordar dominios/orígenes de producción para `CORS_ORIGINS`; el login exige Origin permitido y refresh/logout/password requieren además CSRF.
- Definir proceso de invitación/reset de contraseña, caducidad y canal de entrega.
- Definir alcance visible de auditoría para GERENTE, retención, exportación y protección contra alteraciones.
- Definir política de ADMIN: alta inicial, protección del último administrador activo y posibilidad de autoedición de rol.
- Las pruebas HTTP/de integración deben ejecutarse en una base de pruebas dedicada con la migración aplicada; no deben apuntar a la base local de desarrollo.

## Referencias de diseño

- OWASP Password Storage Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html
- OWASP JSON Web Token Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/JSON_Web_Token_Cheat_Sheet
- OWASP Session Management Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet
- RFC 7519 — JSON Web Token: https://datatracker.ietf.org/doc/rfc7519/
- Express middleware guide: https://expressjs.com/en/guide/using-middleware/
- Prisma ORM 7 PostgreSQL: https://www.prisma.io/docs/orm/v7/core-concepts/supported-databases/postgresql
