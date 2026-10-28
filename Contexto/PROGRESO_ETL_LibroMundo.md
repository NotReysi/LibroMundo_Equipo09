# LibroMundo · Laboratorio 4 (ETL) — Progreso, scripts y pendientes

> **Para quién es:** mi yo del futuro y el Equipo 09. Aquí queda lo que se hizo, por qué, los scripts exactos que se corrieron y lo que falta.
> **Complementa a:** `CONTEXTO_PROYECTO.md` (arquitectura y reglas de negocio).
> **Última actualización:** 27 de octubre de 2026.
> **Estado en una línea:** el pipeline completo (6 fases) está terminado y verificado para **`clientes`**; faltan las demás fuentes y el Paso 7 (indicadores).

---

## 0. Estado rápido

| Fuente | Destino en el Data Mart | 2 RAW | 1 Perfilado | 3 Normalización | 4 Rechazos | 5 Carga | 6 Conciliación |
|---|---|:-:|:-:|:-:|:-:|:-:|:-:|
| `CRM/clientes.csv` (11,400) | `dim_cliente` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `OPERACION/sucursales.csv` (17) | `dim_sucursal` | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| `ERP/productos.csv` (1,420) + `ESPECIFICO/catalogo_editorial.csv` (1,420) | `dim_item`, `dim_autor`, `bridge_item_autor` | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| `MARKETING/promociones.csv` (190) | `dim_promocion` (+ `bridge_venta_promocion`) | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| `POS/ventas.csv` (145,000) + `POS/detalle_ventas.csv` (343,281) | `fact_ventas`, `dim_canal`, `dim_fecha` | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| `POS/devoluciones.csv` (10,298) | `fact_devoluciones` | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| `ERP/proveedores.csv` (170) | sin destino en el esquema estrella | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| `INVENTARIO/existencias.csv` (24,140) | sin destino en el esquema estrella | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| `COMPRAS/ordenes_compra.csv` (13,500) | sin destino en el esquema estrella | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |

Los conteos coinciden con `MANIFEST.json`. Las tres últimas filas solo se hacen si el profesor las exige (ver pendientes).

---

## 1. Lista de pendientes

### 1.1 Hecho

- [x] Instalar MySQL 8.0+ y ejecutar `00_crear_bd_y_log.sql` (crea `lm_bi` y `etl_log`).
- [x] Unificar el DDL propio en `lm_bi` y eliminar `dm_libromundo`.
- [x] Habilitar `local_infile` en el servidor (`SET PERSIST`) y en Workbench (`OPT_LOCAL_INFILE=1`).
- [x] **`clientes`: Paso 2 (RAW), Paso 1 (perfilado + `etl_observaciones`), Paso 3 (`stg_clientes`), Paso 4 (`etl_rechazos`), Paso 5 (UPSERT a `dim_cliente`), Paso 6 (`etl_log`).**
- [x] Prueba de idempotencia de `dim_cliente`: la 2.ª ejecución dio `0 row(s) affected`, 11,401 filas (11,400 + semilla), `suma_keys = 64,997,101` en ambas.

### 1.2 Decisiones y confirmaciones pendientes (hacer ANTES de las demás tablas)

- [ ] **Preguntar al profesor** si la bitácora debe llamarse `etl_auditoria` (la guía del laboratorio la menciona) o basta `etl_log` (la que trae su script). Mientras tanto se usa `etl_log`.
- [ ] **Preguntar al profesor** si hay que ingerir `proveedores`, `existencias` y `ordenes_compra`. La guía del laboratorio no las menciona y no alimentan el esquema estrella.
- [ ] **Actualizar el script DDL propio:** `dim_cliente.cliente_id` debe ser `VARCHAR(20)` (hoy el DDL lo crea `BIGINT`). Si no, reconstruir `lm_bi` desde cero deshace el `ALTER` y la carga falla.
- [ ] **Decidir el grano de `fact_ventas` con el equipo** (ver §6.4): hay 224 ventas con el mismo producto en dos líneas distintas, lo que choca con `UNIQUE (venta_id, item_key)`.
- [ ] **Decidir cómo clasificar `dim_item`** (`LIBRO` vs `PRODUCTO_NO_EDITORIAL`): el catálogo editorial trae ISBN para los 1,420 productos, incluso de categorías como `Papelería` y `Juegos` (ver §6.3).
- [ ] **Decidir el origen de `region`** en `dim_sucursal`: `sucursales.csv` trae `estado` pero no `region`.
- [ ] **Decidir qué hacer con tablas sin fuente:** no hay CSV para `dim_evento`, `fact_eventos`, `dim_genero`, `dim_temporada`, `bridge_item_genero`, `bridge_venta_evento` ni `bridge_venta_promocion` (`detalle_ventas` no trae `promocion_id`). Definir si quedan vacías, se derivan por regla (por ejemplo, por fechas) o se documentan como fuera de alcance.
- [ ] **Decidir el tratamiento de dos incoherencias de fechas** detectadas en ventas (ver §6.4).
- [ ] Definir cómo se construyen `dim_fecha` (calendario generado) y `dim_canal` (valores distintos de `ventas.canal`).

### 1.3 Por cada fuente que falta (mismo patrón que `clientes`)

- [ ] **Paso 2 – RAW:** `raw_<fuente>` con todo en `VARCHAR`, `_row_id`, `_archivo_origen`, `_cargado_en`; `LOAD DATA LOCAL INFILE`; conteo contra `MANIFEST.json`.
- [ ] **Paso 1 – Perfilado en SQL** sobre `raw_`: conteos, claves repetidas, vacíos, formatos de fecha, montos/cantidades ≤ 0, variantes de catálogo. Guardar resultados en `etl_observaciones`.
- [ ] **Paso 3 – Normalización** a `stg_<fuente>`: `TRIM`, tipado, catálogos canónicos, fechas a `DATE`, deduplicación con `ROW_NUMBER()`.
- [ ] **Paso 4 – Validación y rechazos:** integridad referencial contra las dimensiones ya cargadas, fechas válidas, importes y cantidades > 0, duplicados. Rechazos a `etl_rechazos` con motivo.
- [ ] **Paso 5 – Carga:** UPSERT con `ON DUPLICATE KEY UPDATE` sobre la clave de negocio (necesita índice `UNIQUE`). Probar idempotencia ejecutándolo dos veces.
- [ ] **Paso 6 – Conciliación:** fila en `etl_log` con `leídas = cargadas + rechazadas`, y conciliación de **importes** staging vs Data Mart en las tablas con montos.

Orden recomendado (los rechazos por integridad referencial necesitan dimensiones ya validadas): `sucursales` → `productos` + `catalogo_editorial` → `promociones` → `ventas` + `detalle_ventas` → `devoluciones`.

### 1.4 Entregables finales

- [ ] Script SQL **único y reproducible** que una todas las fases (con `SET @inicio = NOW();` al principio para `etl_log`).
- [ ] **Paso 7 – Indicadores:** consulta final (ventas netas y pedidos/ventas por estado y fecha). Documentar el supuesto de "ventas netas" para no confundirlo con contabilidad real.
- [ ] Capturas de conteos, rechazos y de la idempotencia (los rechazos reales se verán en las fuentes de ventas y devoluciones, no en `clientes`).
- [ ] Reflexión breve sobre decisiones de limpieza. Preguntas de la guía: ¿qué pasa si un cliente tiene estado vacío?, ¿cómo detectar pedidos tardíos?, ¿cómo admitir devoluciones? ¿por qué el total bruto difiere del válido? ¿por qué una clave estable permite idempotencia? (Ver respuestas parciales en §5.)
- [ ] Según el `README_ALUMNO.md`: dashboard (Excel 365 o Power BI), KPIs estratégicos/tácticos/operacionales y storytelling.

---

## 2. Contexto del proyecto

- **LibroMundo:** cadena de librerías (libros, papelería, juegos, regalos, material escolar, eventos). Canales: tienda, web y app; ventas institucionales; club de lectura y preventas.
- **Objetivo:** construir un Data Mart de ventas en MySQL 8.0+ a partir de CSV crudos, con un ETL reproducible e idempotente y una bitácora de ejecución.
- **Modelo (Unidades 2 y 3):** constelación con `fact_ventas`, `fact_devoluciones` y `fact_eventos`; dimensiones conformadas (`dim_fecha`, `dim_sucursal`, `dim_item`, `dim_cliente`, `dim_canal`, `dim_temporada`, `dim_promocion`, `dim_evento`, `dim_autor`, `dim_genero`) y puentes N:M.
- **Grano de `fact_ventas`:** un ítem vendido dentro de una transacción. Está documentado como inmutable (ver §6.4).
- **Regla crítica:** **nunca** modificar los `.csv` de `LibroMundo/ALUMNO/RAW/`. Toda limpieza ocurre en SQL (`raw_` → `stg_` → rechazos → Data Mart).
- **Nota sobre la guía del laboratorio (`laboratorio_unidad_4.docx`):** describe un caso de e-commerce (`clientes.csv` de 5 columnas, `pedidos.sql`, `catalogo_estados`, `fact_ordenes`, `etl_auditoria`). Es una guía de **método**; los nombres de tablas y archivos del proyecto son los de LibroMundo.

### Archivos clave del repositorio

```
LibroMundo/ALUMNO/RAW/<SISTEMA>/<archivo>.csv   -> fuentes crudas (no tocar)
LibroMundo/ALUMNO/DOCS/diccionario_fuentes_raw.csv
LibroMundo/ALUMNO/DOCS/README_ALUMNO.md
LibroMundo/ALUMNO/SQL_BASE/00_crear_bd_y_log.sql   -> crea lm_bi y etl_log
```

`etl_log` (del profesor): `run_id, proceso, inicio, fin, filas_leidas, filas_cargadas, filas_rechazadas, estatus, detalle`.

---

## 3. Plan de trabajo y convenciones

El plan original tenía dos fallos que se corrigieron:

1. Las `raw_` **no** son tablas temporales (`TEMPORARY TABLE` desaparece al cerrar la sesión): son tablas permanentes en `lm_bi`.
2. **Se carga antes de perfilar:** en SQL no se puede perfilar un CSV que aún no está en la base. El orden real es Paso 2 (RAW) → Paso 1 (perfilado).

Fases:

1. **Perfilado** de `raw_` y registro en `etl_observaciones`.
2. **Staging RAW** (`raw_*`): carga fiel 1:1 con `LOAD DATA`, todo texto, no se modifica después.
3. **Normalización** (`stg_*`): `TRIM`, tipado, catálogos canónicos, fechas a `DATE`, deduplicación.
4. **Validación y rechazos:** `etl_rechazos` con un motivo por fila; vista `v_<fuente>_validos`.
5. **Carga incremental:** UPSERT por clave de negocio estable.
6. **Conciliación:** `etl_log` con `leídas = cargadas + rechazadas` y conciliación de importes.
7. **Indicadores:** consultas analíticas finales.

Convenciones usadas:

- `raw_*`: columnas `VARCHAR`, más `_row_id` (autoincremental), `_archivo_origen`, `_cargado_en`. Para recargar: `TRUNCATE` y volver a ejecutar el `LOAD`; nunca editar a mano.
- `stg_*`: conserva `_raw_row_id` para poder trazar y para que el Paso 4 recupere filas descartadas (anti-join contra `raw_`).
- `etl_rechazos`: una sola tabla para todas las fuentes, con `UNIQUE (tabla_origen, raw_row_id)` (un motivo por fila, con prioridad).
- UPSERT: requiere un índice `UNIQUE` sobre la clave de negocio; sin él, `ON DUPLICATE KEY UPDATE` nunca se dispara y cada corrida duplica filas.
- Collation: la de MySQL 8 (`utf8mb4_0900_ai_ci`) no distingue mayúsculas ni acentos. Para **ver** variantes sucias, usar `COLLATE utf8mb4_bin`.

---

## 4. Scripts ejecutados para `clientes`

> **Orden de ejecución:** S0 → S1 → Paso 2 → Paso 1 (consultas) → Paso 3 → Paso 1 (`etl_observaciones`, que usa `stg_clientes`) → Paso 4 → Paso 5 → Paso 6.
> **Ruta del CSV:** cambia `C:/RUTA/AL/REPO` por la ruta real en tu máquina. En Windows usa `/`, no `\`.

### S0. Unificar todo en `lm_bi`

1. En el script DDL propio, reemplazar `CREATE DATABASE dm_libromundo;` y `USE dm_libromundo;` por `USE lm_bi;` (y cambiar cualquier `dm_libromundo.tabla` por `lm_bi.tabla`).
2. Ejecutar el DDL y verificar:

```sql
SELECT table_schema, COUNT(*) AS tablas
FROM information_schema.tables
WHERE table_schema IN ('lm_bi','dm_libromundo')
GROUP BY table_schema;
```

3. Eliminar la base duplicada (si ya no existe da el error 1008, que es inofensivo):

```sql
DROP DATABASE dm_libromundo;
```

### S1. Habilitar `local_infile`

El error 3948 indica que falta el lado **servidor**; el 2068, que falta el lado **cliente**. Hay que activar ambos.

```sql
SHOW VARIABLES LIKE 'local_infile';
SET PERSIST local_infile = 1;          -- si no se permite: SET GLOBAL local_infile = 1;
SHOW VARIABLES LIKE 'local_infile';    -- debe dar ON (ejecutarlo DESPUÉS del SET)
```

Cliente (Workbench): clic derecho en la conexión → *Edit Connection* → pestaña **Advanced** → campo **Others** → `OPT_LOCAL_INFILE=1` → guardar, **cerrar la conexión y abrirla de nuevo**.

Alternativa por consola: `mysql --local-infile=1 -u root -p lm_bi`.

### Paso 2. Staging RAW — `raw_clientes`

Columnas reales del CSV: `cliente_id, nombre, sexo, fecha_alta, ciudad, segmento, email`. El archivo es UTF-8 con BOM y usa saltos de línea `\n` (con `\r\n` la carga falla).

```sql
USE lm_bi;

DROP TABLE IF EXISTS raw_clientes;
CREATE TABLE raw_clientes (
    _row_id         INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    cliente_id      VARCHAR(255),
    nombre          VARCHAR(255),
    sexo            VARCHAR(255),
    fecha_alta      VARCHAR(255),
    ciudad          VARCHAR(255),
    segmento        VARCHAR(255),
    email           VARCHAR(255),
    _archivo_origen VARCHAR(100) NOT NULL DEFAULT 'CRM/clientes.csv',
    _cargado_en     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

LOAD DATA LOCAL INFILE 'C:/RUTA/AL/REPO/LibroMundo/ALUMNO/RAW/CRM/clientes.csv'
INTO TABLE raw_clientes
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(cliente_id, nombre, sexo, fecha_alta, ciudad, segmento, email);

SELECT COUNT(*) AS filas_cargadas FROM raw_clientes;   -- 11400
```

Los vacíos del CSV entran como cadena vacía `''`, no como `NULL`.

### Paso 1. Perfilado sobre `raw_clientes`

```sql
USE lm_bi;

-- 1) Volumetría y claves repetidas
SELECT COUNT(*) AS filas,
       COUNT(DISTINCT cliente_id) AS ids_distintos,
       COUNT(*) - COUNT(DISTINCT cliente_id) AS repetidos
FROM raw_clientes;

-- 2) Vacíos (incluye cadenas de solo espacios)
SELECT
  SUM(NULLIF(TRIM(cliente_id),'') IS NULL) AS cliente_id_vacio,
  SUM(NULLIF(TRIM(nombre),'')     IS NULL) AS nombre_vacio,
  SUM(NULLIF(TRIM(sexo),'')       IS NULL) AS sexo_vacio,
  SUM(NULLIF(TRIM(fecha_alta),'') IS NULL) AS fecha_vacia,
  SUM(NULLIF(TRIM(ciudad),'')     IS NULL) AS ciudad_vacia,
  SUM(NULLIF(TRIM(segmento),'')   IS NULL) AS segmento_vacio,
  SUM(NULLIF(TRIM(email),'')      IS NULL) AS email_vacio
FROM raw_clientes;

-- 3) Formatos de fecha
SELECT CASE
         WHEN NULLIF(TRIM(fecha_alta),'') IS NULL                THEN 'VACIA'
         WHEN fecha_alta REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'   THEN 'YYYY-MM-DD'
         WHEN fecha_alta REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'   THEN 'DD/MM/YYYY'
         ELSE 'OTRO'
       END AS formato,
       COUNT(*) AS filas, MIN(fecha_alta) AS min_txt, MAX(fecha_alta) AS max_txt
FROM raw_clientes
GROUP BY formato;

-- 4) Ciudad: collation binaria para ver variantes de mayúsculas; corchetes para ver espacios
SELECT CONCAT('[', c, ']') AS ciudad_visible, n
FROM (SELECT ciudad COLLATE utf8mb4_bin AS c, COUNT(*) AS n
      FROM raw_clientes GROUP BY c) t
ORDER BY c;

-- 5) Otros catálogos
SELECT sexo COLLATE utf8mb4_bin AS sexo, COUNT(*) AS filas
FROM raw_clientes GROUP BY 1 ORDER BY 1;
SELECT segmento COLLATE utf8mb4_bin AS segmento, COUNT(*) AS filas
FROM raw_clientes GROUP BY 1 ORDER BY 1;

-- 6) Formato de ID, espacios y emails
SELECT SUM(cliente_id NOT REGEXP '^LM-C[0-9]{6}$')                       AS ids_formato_raro,
       SUM(nombre <> TRIM(nombre) OR email <> TRIM(email))                AS campos_con_espacios,
       SUM(NULLIF(TRIM(email),'') IS NOT NULL
           AND email NOT REGEXP '^[^@ ]+@[^@ ]+\\.[^@ ]+$')               AS emails_invalidos,
       COUNT(NULLIF(TRIM(email),'')) - COUNT(DISTINCT NULLIF(TRIM(email),'')) AS emails_repetidos
FROM raw_clientes;
```

**Resultados reales de `clientes`:** 11,400 filas; 0 IDs repetidos; todas las fechas en `YYYY-MM-DD` (2019-01-01 a 2026-09-30); 45 emails vacíos; 16 ciudades vacías (cadenas de espacios); variantes de ciudad `APODACA` (17), `monterrey` (16), `MTY` (15) y `Sn Nicolas` (12); `sexo` = `F` 5,602 / `M` 5,567 / `N/E` 231; `segmento` limpio (`Frecuente` 5,190, `Nuevo` 2,823, `Inactivo` 2,030, `Premium` 1,357).

### Paso 3. Normalización — `cat_ciudad` y `stg_clientes`

```sql
USE lm_bi;

-- Catálogo canónico (variante -> ciudad estándar)
CREATE TABLE IF NOT EXISTS cat_ciudad (
    variante        VARCHAR(100) COLLATE utf8mb4_0900_ai_ci NOT NULL PRIMARY KEY,
    ciudad_canonica VARCHAR(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

TRUNCATE TABLE cat_ciudad;
INSERT INTO cat_ciudad (variante, ciudad_canonica) VALUES
 ('Tampico','Tampico'),       ('Monterrey','Monterrey'),
 ('Apodaca','Apodaca'),       ('San Nicolás','San Nicolás'),
 ('Escobedo','Escobedo'),     ('Reynosa','Reynosa'),
 ('Guadalupe','Guadalupe'),   ('Santa Catarina','Santa Catarina'),
 ('San Pedro','San Pedro'),   ('Saltillo','Saltillo'),
 ('MTY','Monterrey'),         ('Sn Nicolas','San Nicolás');
-- La collation _ai_ci ya cubre APODACA/monterrey y San Nicolas/San Nicolás

CREATE TABLE IF NOT EXISTS stg_clientes (
    cliente_id    VARCHAR(20)  NOT NULL PRIMARY KEY,
    nombre        VARCHAR(255) NULL,
    sexo          VARCHAR(5)   NULL,
    fecha_alta    DATE         NULL,
    ciudad        VARCHAR(100) NULL,
    ciudad_raw    VARCHAR(255) NULL,
    segmento      VARCHAR(50)  NULL,
    email         VARCHAR(255) NULL,
    _raw_row_id   INT UNSIGNED NOT NULL,
    _procesado_en DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

TRUNCATE TABLE stg_clientes;

INSERT INTO stg_clientes
    (cliente_id, nombre, sexo, fecha_alta, ciudad, ciudad_raw, segmento, email, _raw_row_id)
SELECT
    UPPER(TRIM(r.cliente_id)),
    NULLIF(TRIM(r.nombre), ''),
    UPPER(NULLIF(TRIM(r.sexo), '')),
    CASE
      WHEN TRIM(r.fecha_alta) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
           THEN STR_TO_DATE(TRIM(r.fecha_alta), '%Y-%m-%d')
      WHEN TRIM(r.fecha_alta) REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'
           THEN STR_TO_DATE(TRIM(r.fecha_alta), '%d/%m/%Y')
    END,
    c.ciudad_canonica,
    r.ciudad,
    CONCAT(UPPER(LEFT(NULLIF(TRIM(r.segmento),''),1)),
           LOWER(SUBSTRING(NULLIF(TRIM(r.segmento),''),2))),
    LOWER(NULLIF(TRIM(r.email), '')),
    r._row_id
FROM (
    SELECT x.*,
           ROW_NUMBER() OVER (PARTITION BY UPPER(TRIM(x.cliente_id))
                              ORDER BY x._row_id) AS rn
    FROM raw_clientes x
    WHERE NULLIF(TRIM(x.cliente_id), '') IS NOT NULL
) r
LEFT JOIN cat_ciudad c
       ON TRIM(r.ciudad) COLLATE utf8mb4_0900_ai_ci = c.variante
WHERE r.rn = 1;
```

Verificación (valores esperados entre comentarios):

```sql
SELECT COUNT(*) AS filas FROM stg_clientes;                      -- 11400

SELECT ciudad, COUNT(*) AS filas
FROM stg_clientes GROUP BY ciudad ORDER BY ciudad;
-- Tampico 1217, Monterrey 1182, Apodaca 1159, San Nicolás 1147, Escobedo 1129,
-- Reynosa 1121, Guadalupe 1115, Santa Catarina 1115, San Pedro 1103, Saltillo 1096, NULL 16

SELECT COUNT(*) AS ciudad_sin_mapear                             -- 0
FROM stg_clientes
WHERE ciudad IS NULL AND NULLIF(TRIM(ciudad_raw),'') IS NOT NULL;

SELECT SUM(ciudad IS NULL)     AS ciudad_nula,                   -- 16
       SUM(email IS NULL)      AS email_nulo,                    -- 45
       SUM(fecha_alta IS NULL) AS fecha_nula                     -- 0
FROM stg_clientes;

SELECT sexo, COUNT(*) FROM stg_clientes GROUP BY sexo;           -- F 5602, M 5567, N/E 231
```

### Paso 1 (cont.). Tabla de observaciones del perfilado

La guía pide guardar los resultados del perfilado en una tabla. Ejecutar **después** del Paso 3 (usa `stg_clientes`).

```sql
USE lm_bi;

CREATE TABLE IF NOT EXISTS etl_observaciones (
    obs_id        BIGINT AUTO_INCREMENT PRIMARY KEY,
    fuente        VARCHAR(50)  NOT NULL,
    metrica       VARCHAR(100) NOT NULL,
    valor         BIGINT       NULL,
    registrada_en DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

DELETE FROM etl_observaciones WHERE fuente = 'raw_clientes';

INSERT INTO etl_observaciones (fuente, metrica, valor)
SELECT 'raw_clientes','filas', COUNT(*) FROM raw_clientes
UNION ALL SELECT 'raw_clientes','ids_repetidos', COUNT(*) - COUNT(DISTINCT cliente_id) FROM raw_clientes
UNION ALL SELECT 'raw_clientes','ciudad_vacia',  SUM(NULLIF(TRIM(ciudad),'') IS NULL) FROM raw_clientes
UNION ALL SELECT 'raw_clientes','email_vacio',   SUM(NULLIF(TRIM(email),'')  IS NULL) FROM raw_clientes
UNION ALL SELECT 'raw_clientes','fecha_no_iso',  SUM(fecha_alta NOT REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$') FROM raw_clientes
UNION ALL SELECT 'raw_clientes','ciudad_variante_no_canonica',
         SUM(ciudad IS NOT NULL AND ciudad_raw COLLATE utf8mb4_bin <> ciudad) FROM stg_clientes;

SELECT * FROM etl_observaciones WHERE fuente = 'raw_clientes';
-- Esperado: 11400, 0, 16, 45, 0, 60
```

### Paso 4. Validación y rechazos

```sql
USE lm_bi;

CREATE TABLE IF NOT EXISTS etl_rechazos (
    rechazo_id     BIGINT AUTO_INCREMENT PRIMARY KEY,
    tabla_origen   VARCHAR(50)  NOT NULL,
    raw_row_id     INT UNSIGNED NOT NULL,
    llave_negocio  VARCHAR(50)  NULL,
    motivo         VARCHAR(50)  NOT NULL,
    valor_original VARCHAR(500) NULL,
    rechazado_en   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_rechazo (tabla_origen, raw_row_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

DELETE FROM etl_rechazos WHERE tabla_origen = 'raw_clientes';

INSERT INTO etl_rechazos (tabla_origen, raw_row_id, llave_negocio, motivo, valor_original)
SELECT 'raw_clientes',
       r._row_id,
       NULLIF(TRIM(r.cliente_id), ''),
       CASE
         WHEN NULLIF(TRIM(r.cliente_id), '') IS NULL THEN 'ID_VACIO'
         WHEN s.cliente_id IS NULL                   THEN 'ID_DUPLICADO'
         WHEN s.fecha_alta IS NULL                   THEN 'FECHA_INVALIDA'
         WHEN s.fecha_alta > CURDATE()               THEN 'FECHA_FUTURA'
       END,
       CONCAT_WS(' | ', r.cliente_id, r.nombre, r.fecha_alta)
FROM raw_clientes r
LEFT JOIN stg_clientes s ON s._raw_row_id = r._row_id
WHERE NULLIF(TRIM(r.cliente_id), '') IS NULL
   OR s.cliente_id IS NULL
   OR s.fecha_alta IS NULL
   OR s.fecha_alta > CURDATE();

-- Vista de clientes válidos (versión FINAL: etiqueta NO_IDENTIFICADO, igual que el cliente semilla)
CREATE OR REPLACE VIEW v_clientes_validos AS
SELECT s.cliente_id, s.nombre, s.sexo, s.fecha_alta,
       COALESCE(s.ciudad, 'NO_IDENTIFICADO') AS ciudad,
       s.segmento, s.email, s._raw_row_id
FROM stg_clientes s
WHERE NOT EXISTS (SELECT 1 FROM etl_rechazos x
                  WHERE x.tabla_origen = 'raw_clientes'
                    AND x.raw_row_id = s._raw_row_id);
```

Verificación:

```sql
SELECT motivo, COUNT(*) AS filas
FROM etl_rechazos WHERE tabla_origen = 'raw_clientes' GROUP BY motivo;   -- sin filas

SELECT (SELECT COUNT(*) FROM raw_clientes)                                      AS leidas,
       (SELECT COUNT(*) FROM v_clientes_validos)                                AS validas,
       (SELECT COUNT(*) FROM etl_rechazos WHERE tabla_origen = 'raw_clientes')  AS rechazadas;
-- 11400 = 11400 + 0
```

`clientes` no genera rechazos: sus problemas eran de normalización, no de validez.

### Paso 5. Carga incremental (UPSERT) a `dim_cliente`

**Antes:** comprobar que ninguna FK dependa de `dim_cliente.cliente_id`.

```sql
USE lm_bi;
SELECT table_name, column_name, constraint_name, referenced_column_name
FROM information_schema.key_column_usage
WHERE table_schema = 'lm_bi' AND referenced_table_name = 'dim_cliente';
-- Si alguna fila muestra referenced_column_name = cliente_id, NO hacer el ALTER.
```

**Ajuste de esquema (una sola vez):** el ID de negocio es texto (`LM-C000001`), pero `dim_cliente.cliente_id` era `BIGINT`. El índice `UNIQUE KEY cliente_id` ya existía y es el que hace posible el UPSERT.

```sql
ALTER TABLE dim_cliente MODIFY cliente_id VARCHAR(20) NULL;   -- el semilla -1 pasa a '-1'
```

**UPSERT:**

```sql
INSERT INTO dim_cliente (cliente_id, nombre, tipo_cliente, segmento_cliente, ciudad, limite_credito)
SELECT v.cliente_id, v.nombre, NULL, UPPER(v.segmento), v.ciudad, NULL
FROM v_clientes_validos v
ON DUPLICATE KEY UPDATE
    nombre           = VALUES(nombre),
    segmento_cliente = VALUES(segmento_cliente),
    ciudad           = VALUES(ciudad);
```

Salen 3 warnings 1287 (`VALUES()` está deprecado). Son inocuos y no hay alternativa con `INSERT ... SELECT`.

Verificación e idempotencia:

```sql
SELECT COUNT(*) AS filas, SUM(cliente_key) AS suma_keys FROM dim_cliente;
-- 11401 filas (11,400 + semilla); suma_keys = 64997101

SELECT segmento_cliente, COUNT(*) FROM dim_cliente GROUP BY segmento_cliente;
-- FRECUENTE 5190, NUEVO 2823, INACTIVO 2030, PREMIUM 1357, NO_IDENTIFICADO 1 (semilla)

SELECT COUNT(*) AS ciudad_no_identificada FROM dim_cliente
WHERE ciudad = 'NO_IDENTIFICADO';                                   -- 16

SELECT COUNT(*) AS validos_sin_dim                                  -- 0
FROM v_clientes_validos v
LEFT JOIN dim_cliente d ON d.cliente_id = v.cliente_id
WHERE d.cliente_key IS NULL;
```

Volver a ejecutar **solo** el UPSERT y repetir el primer `SELECT`: debe dar `0 row(s) affected` y los mismos números. Confirmado: 1.ª ejecución `11400 row(s) affected`, 2.ª ejecución `0 row(s) affected`.

### Paso 6. Conciliación y bitácora

```sql
USE lm_bi;

SET @leidas     = (SELECT COUNT(*) FROM raw_clientes);
SET @rechazadas = (SELECT COUNT(*) FROM etl_rechazos WHERE tabla_origen = 'raw_clientes');
SET @cargadas   = (SELECT COUNT(*) FROM v_clientes_validos v
                   JOIN dim_cliente d ON d.cliente_id = v.cliente_id);
SET @en_dim     = (SELECT COUNT(*) FROM dim_cliente WHERE cliente_id <> '-1');

INSERT INTO etl_log
    (proceso, inicio, fin, filas_leidas, filas_cargadas, filas_rechazadas, estatus, detalle)
VALUES
    ('clientes',
     (SELECT MIN(_cargado_en) FROM raw_clientes),
     NOW(),
     @leidas, @cargadas, @rechazadas,
     CASE WHEN @leidas = @cargadas + @rechazadas AND @cargadas = @en_dim
          THEN 'OK' ELSE 'DESCUADRE' END,
     CONCAT('raw_clientes -> stg_clientes -> dim_cliente; filas en dim sin semilla = ', @en_dim));

SELECT run_id, proceso, inicio, fin, filas_leidas, filas_cargadas,
       filas_rechazadas, estatus, detalle
FROM etl_log ORDER BY run_id DESC LIMIT 1;
-- Esperado: 11400 / 11400 / 0 / OK

-- Conciliación de atributos vista vs dimensión (binaria, para no ocultar diferencias de mayúsculas)
SELECT COUNT(*) AS filas_con_diferencias          -- esperado: 0
FROM v_clientes_validos v
JOIN dim_cliente d ON d.cliente_id = v.cliente_id
WHERE NOT (d.nombre           COLLATE utf8mb4_bin <=> v.nombre)
   OR NOT (d.segmento_cliente COLLATE utf8mb4_bin <=> UPPER(v.segmento))
   OR NOT (d.ciudad           COLLATE utf8mb4_bin <=> v.ciudad);
```

`etl_log` es una bitácora de solo añadir: cada ejecución inserta una fila nueva. La conciliación de **importes** no aplica a `clientes` (no tiene montos); se hará con `detalle_ventas` y `devoluciones`.

---

## 5. Decisiones tomadas (y por qué)

| Decisión | Motivo |
|---|---|
| `raw_` permanentes, todo `VARCHAR` | Zona de aterrizaje inmutable; ningún dato sucio rompe la carga. |
| `N/E` en `sexo` se conserva como valor válido | Es un código consistente del sistema, no un error. |
| Ciudad vacía → no se rechaza; se carga como `NO_IDENTIFICADO` | Responde a la pregunta de la guía ("¿se rechaza el cliente o se agrupa como no identificado?"): un cliente sin ciudad sigue teniendo ventas válidas, y rechazarlo dejaría esas ventas huérfanas. Coincide con el cliente semilla. |
| Email vacío → `NULL`; emails en minúsculas | Normalización mínima, sin inventar datos. |
| `dim_cliente.cliente_id` pasa a `VARCHAR(20)` | El ID de negocio es `LM-C......`; es la misma clave que usa `ventas.csv`. |
| `tipo_cliente` y `limite_credito` quedan en `NULL` | No existen en el CSV; poner un valor sería inventar datos. El `UPDATE` no los toca. |
| `sexo`, `fecha_alta` y `email` no se cargan a `dim_cliente` | La dimensión no tiene esas columnas (siguen en `stg_clientes`). Si hace falta antigüedad del cliente, añadir `fecha_alta` a la dimensión. |
| `cliente_key` puede tener huecos | InnoDB reserva valores de `AUTO_INCREMENT` aun cuando la fila resulta duplicada. Las filas existentes conservan su llave. Nunca asumir llaves consecutivas. |
| Fila de `etl_log` al final (Paso 6) | `filas_cargadas` no existe hasta terminar la carga (Paso 5). |

Respuestas parciales a las preguntas de la guía:

- **¿Por qué una clave estable permite idempotencia?** Porque el UPSERT identifica cada fila por su clave de negocio: si ya existe, se actualiza (o no cambia); si no, se inserta. Re-ejecutar sin datos nuevos no añade filas.
- **¿Por qué el total bruto puede diferir del válido?** Lo bruto incluye duplicados, claves vacías y registros inválidos; lo válido los excluye. Con `clientes` la diferencia es 0; la evidencia real vendrá de ventas/devoluciones.
- **No modificar los originales:** permite reproducir el proceso, auditar qué se corrigió y demostrar que ningún dato fue alterado a mano.

---

## 6. Hallazgos del resto de fuentes (perfilado preliminar)

> **Advertencia:** esta revisión se hizo con Python solo como mapa para planear. El perfilado formal debe repetirse **en SQL sobre las `raw_`** (es lo que pide el laboratorio y lo que es reproducible), guardando los resultados en `etl_observaciones`.

### 6.1 Resumen por archivo

| Archivo | Filas | Claves | Lo que se observó |
|---|---:|---|---|
| `sucursales` | 17 | `sucursal_id` | Sin vacíos ni duplicados. Ciudad y estado limpios (14 en Nuevo León, 1 en Coahuila, 2 en Tamaulipas). Sin `region`. |
| `productos` | 1,420 | `producto_id`, `sku` | Sin duplicados ni vacíos. `costo` siempre menor que `precio_lista`. 77 productos con `activo = NO`. `formato`: Físico / Digital / Audiolibro. |
| `catalogo_editorial` | 1,420 | `producto_id`, `isbn` | 1:1 con productos. ISBN de 13 caracteres, sin duplicados. Un solo autor por producto (sin separadores de coautoría). Sin género ni idioma. |
| `promociones` | 190 | `promocion_id` | Fechas ISO válidas (`fecha_fin` nunca antes de `fecha_inicio`). Descuentos 5 a 30 %. No hay llave que la una con `detalle_ventas`. |
| `ventas` | 145,000 | `venta_id` | Fechas ISO (2024-01-01 a 2026-09-30). Canales: Tienda, Web, App. Todos los clientes y sucursales existen. Ningún cliente anónimo (`-1` no se usa). |
| `detalle_ventas` | 343,281 | `venta_id` + `linea` | Cantidades 1 a 4, sin montos ≤ 0. Todas las ventas tienen detalle (1 a 4 líneas). Ver §6.4. |
| `devoluciones` | 10,298 | `devolucion_id` | Todas apuntan a una venta y producto existentes. Ver §6.5. |
| `proveedores` | 170 | `proveedor_id` | Sin hallazgos. |
| `existencias` | 24,140 | `sucursal_id` + `producto_id` | Sin duplicados. 149 filas con existencia 0 (válido). |
| `ordenes_compra` | 13,500 | `orden_id` | Sin hallazgos. Estatus: Recibida, Pendiente, Parcial, Cancelada. |

Según el README, los archivos RAW tienen problemas de calidad intencionales; en esta revisión rápida casi todos están limpios salvo los de abajo. Conviene confirmarlo con el perfilado en SQL (por ejemplo, formatos de fecha y variantes de texto) antes de dar una fuente por buena.

### 6.2 `sucursales`

- Aporta el `estado` que usan los indicadores "por estado". `dim_sucursal` también pide `region`, que **no viene** en el CSV: hay que decidir cómo derivarlo.

### 6.3 `productos` + `catalogo_editorial` → `dim_item`

- `dim_item` exige un `CHECK`: `LIBRO` requiere `isbn` y `PRODUCTO_NO_EDITORIAL` requiere `sku`. Pero los **1,420** productos tienen `sku` **y** `isbn`, incluidas categorías como `Papelería` y `Juegos`. Hace falta una regla explícita de clasificación (por ejemplo, por `categoria`) y confirmar cómo se trata `Digital`.
- Autor único por producto: `bridge_item_autor` quedaría con `factor_asignacion = 1`.

### 6.4 `ventas` + `detalle_ventas` → `fact_ventas`

- **Importe ya neto de descuento.** En el 100 % de las líneas `importe = cantidad × precio_unitario`, y cuando `descuento_pct > 0`, `precio_unitario = precio_lista × (1 − descuento_pct/100)`. Propuesta (validar contra el DDL de `fact_ventas`): `venta_bruta = cantidad × precio_lista`, `venta_neta = importe`, `descuento = venta_bruta − venta_neta`, `costo_total = cantidad × costo`, `margen = venta_neta − costo_total`.
- **Margen negativo:** 5,300 líneas se venden con precio unitario por debajo del costo.
- **Choque con el grano.** 224 ventas (448 líneas) repiten el mismo producto en dos líneas distintas, con precios o descuentos a veces distintos (solo 69 de los 224 pares coinciden en precio). Eso viola `UNIQUE (venta_id, item_key)`. Opciones:
  - **(a)** consolidar las líneas sumando cantidad e importe (pierde el detalle de precio y descuento por línea);
  - **(b)** cambiar la restricción a `UNIQUE (venta_id, linea)` y añadir `linea` a `fact_ventas` (conserva toda la información, pero toca una definición que el equipo documentó como inmutable).
  
  Decisión del equipo; (b) conserva más información.
- **Incoherencias de fechas:** 1,167 ventas son anteriores a la `fecha_apertura` de su sucursal y 25,668 anteriores a la `fecha_alta` de su cliente. No están entre las reglas de rechazo del documento de contexto; decidir si se rechazan o solo se reportan en `etl_observaciones`. Por volumen (17.7 % de las ventas), rechazarlas vaciaría buena parte de la tabla de hechos.
- **Productos inactivos:** 18,744 líneas son de productos con `activo = NO`. Probablemente sea normal (histórico), pero conviene dejarlo documentado.

### 6.5 `devoluciones` → `fact_devoluciones`

- Una devolución excede lo vendido: `LM-D0007617` (venta `LM-V00105586`, producto `LM-P00960`) devuelve 2 unidades por 943.32 cuando la línea vendida tiene 1 unidad por 589.57. Candidata a rechazo con motivo `DEVOLUCION_EXCEDE_VENTA`.
- `devoluciones` **no trae `linea`**; se une con el detalle por `venta_id` + `producto_id`. Verificar si alguna devolución cae sobre uno de los 224 pares repetidos, porque la unión sería ambigua.

---

## 7. Errores y lecciones (para no repetirlos)

| Qué pasó | Causa | Lección |
|---|---|---|
| Error 2068 al cargar el CSV | Faltaba `OPT_LOCAL_INFILE=1` del lado **cliente** (Workbench), aunque el servidor ya estaba en `ON` | `local_infile` se activa en servidor **y** cliente; reconectar después de guardar. |
| `SHOW VARIABLES` seguía en `OFF` tras el `SET PERSIST` | La rejilla mostraba la lectura anterior al `SET` | Ejecutar el `SHOW` de nuevo después del `SET`. |
| Error 1008 en `DROP DATABASE dm_libromundo` | La base ya no existía (la unificación ya estaba hecha) | Inofensivo. |
| Primer script de `raw_clientes` con columnas inventadas y `\r\n` | Se supuso el encabezado sin leer el archivo | Ver el encabezado real y el tipo de salto de línea antes de escribir el `LOAD`. |
| `GROUP BY ciudad` ocultaba `APODACA` frente a `Apodaca` | La collation `_ai_ci` ignora mayúsculas y acentos | Usar `COLLATE utf8mb4_bin` al perfilar. |
| El Paso 1 no guardaba resultados | Se olvidó la tabla de observaciones que pide la guía | Insertar las métricas en `etl_observaciones`. |
| `cliente_id` era `BIGINT` | El DDL no consideró IDs tipo `LM-C000001` | Verificar `SHOW CREATE TABLE` antes de escribir el UPSERT. |
| 3 warnings 1287 en el UPSERT | `VALUES()` está deprecado | Inofensivo; no hay alternativa con `INSERT ... SELECT`. |

---

## 8. Cómo retomar mañana

1. Abrir Workbench, `USE lm_bi;` y verificar `SHOW VARIABLES LIKE 'local_infile';` (debe dar `ON`).
2. Resolver las decisiones de §1.2 (al menos la del grano y la de `dim_item`, porque bloquean `productos` y `ventas`).
3. Empezar por **`sucursales`**: aporta `estado` y es corta (17 filas). Repetir el patrón de §1.3 y §4, pidiendo antes el encabezado real del CSV para no suponer columnas.
4. Seguir el orden recomendado de §1.3 y marcar cada casilla de §0.
