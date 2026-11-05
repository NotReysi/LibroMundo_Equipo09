# Actividad 3 — Laboratorio 4: ETL de LibroMundo

Guía rápida para ejecutar el pipeline ETL que puebla el Data Mart `lm_bi` (MySQL 8.0+) a partir de los CSV entregados por el profesor.

## Qué hace esta actividad

Ingiere los CSV crudos de los sistemas OLTP de LibroMundo (POS, ERP, CRM, etc.) en un esquema estrella/constelación, con pipeline en 6 fases por fuente: RAW (`raw_*`) → perfilado (`etl_observaciones`) → normalización (`stg_*`) → validación y rechazos (`etl_rechazos`) → carga idempotente (UPSERT por clave de negocio) → conciliación y bitácora (`etl_log`). Al final se consultan los indicadores.

## Requisitos

1. **MySQL 8.0.16 o superior** (las restricciones `CHECK` no se aplican antes).
2. **`local_infile` activo en servidor y cliente:**
   - Servidor: `SET PERSIST local_infile = 1;` (o `SET GLOBAL ...`) y verificar con `SHOW VARIABLES LIKE 'local_infile';` (ejecutar el `SHOW` después del `SET`). Error **3948** = falta el lado servidor; error **2068** = falta el lado cliente.
   - Workbench: clic derecho en la conexión → *Edit Connection* → pestaña *Advanced* → campo *Others* → `OPT_LOCAL_INFILE=1` → guardar y **reconectar**.
   - Alternativa por consola: `mysql --local-infile=1 -u root -p lm_bi`.
3. **Rutas de los CSV:** cada `etl_*.sql` contiene la ruta de ejemplo `C:/RUTA/AL/REPO/LibroMundo/ALUMNO/RAW/...`. Antes de ejecutar, reemplazar `C:/RUTA/AL/REPO` por la ruta local de esta carpeta `ACTIVIDAD U4` (usar `/`, no `\`).

## Archivos

- `LibroMundo_DataMart_DDL_Corregido.sql`: crea la base `lm_bi`, el modelo dimensional y las tablas de auditoría (`etl_log`, `etl_observaciones`, `etl_rechazos`).
- `etl_sucursales.sql`: `OPERACION/sucursales.csv` → `dim_sucursal`.
- `etl_clientes.sql`: `CRM/clientes.csv` → `dim_cliente`.
- `etl_productos_y_autores.sql`: `ERP/productos.csv` + `ESPECIFICO/catalogo_editorial.csv` → `dim_item`, `dim_autor`, `bridge_item_autor`.
- `etl_promociones.sql`: `MARKETING/promociones.csv` → `dim_promocion`.
- `etl_ventas_y_detalle.sql`: `POS/ventas.csv` + `POS/detalle_ventas.csv` → `dim_canal`, `dim_fecha`, `fact_ventas` (requiere `dim_cliente`, `dim_item` y `dim_sucursal` ya cargadas).
- `etl_devoluciones.sql`: `POS/devoluciones.csv` → `fact_devoluciones` (requiere `fact_ventas`).
- `consulta_de_indicadores_finales.sql`: indicadores finales.
- `LibroMundo/`: datos del profesor. `ALUMNO/RAW/` tiene los CSV por sistema; `MANIFEST.json` los conteos de referencia por archivo; `ALUMNO/DOCS/` el enunciado y el diccionario de datos.

## Orden de ejecución

Ejecutar los scripts completos, en este orden, en MySQL Workbench:

1. `LibroMundo_DataMart_DDL_Corregido.sql`
2. `etl_sucursales.sql`
3. `etl_clientes.sql`
4. `etl_productos_y_autores.sql`
5. `etl_promociones.sql`
6. `etl_ventas_y_detalle.sql`
7. `etl_devoluciones.sql`
8. `consulta_de_indicadores_finales.sql`

Los pasos 2 a 5 son dimensiones y no dependen entre sí (ese orden es el recomendado); los pasos 6 y 7 sí dependen de lo anterior. `LibroMundo/ALUMNO/SQL_BASE/00_crear_bd_y_log.sql` es opcional: el DDL corregido ya crea `lm_bi` y `etl_log`.

Para repetir una fuente concreta: cada script empieza recreando sus tablas (`raw_*`, `stg_*`) con `DROP TABLE IF EXISTS`, así que basta volver a ejecutarlo. Para repetir todo desde cero, ejecutar de nuevo el DDL corregido y luego los `etl_*.sql` en orden.

## Verificación

- **Conteos:** comparar `SELECT COUNT(*)` de cada `raw_*` contra `LibroMundo/MANIFEST.json`.
- **Conciliación:** en `etl_log` debe cumplirse `filas_leidas = filas_cargadas + filas_rechazadas` y `estatus = 'OK'` para cada fuente.
- **Idempotencia:** re-ejecutar un `etl_*.sql` ya corrido no debe duplicar filas (el UPSERT por clave de negocio con índice `UNIQUE` da `0 row(s) affected` si nada cambió).
- **Rechazos:** consultar `SELECT tabla_origen, motivo, COUNT(*) FROM etl_rechazos GROUP BY 1, 2;` para ver qué filas se descartaron y por qué.

## Reglas de oro

- **Nunca modificar los CSV de `LibroMundo/ALUMNO/RAW/`**: contienen errores de calidad intencionales y son la evidencia de origen. Toda la limpieza ocurre en SQL (`raw_` → `stg_` → rechazos → Data Mart).
- **No inventar datos:** atributos que no vienen en el CSV se cargan como `NULL`.
- Las llaves sustitutas (`AUTO_INCREMENT`) pueden tener huecos; no asumir consecutividad.
- `etl_log` es de solo añadir (append-only): no editar ni borrar corridas anteriores.
