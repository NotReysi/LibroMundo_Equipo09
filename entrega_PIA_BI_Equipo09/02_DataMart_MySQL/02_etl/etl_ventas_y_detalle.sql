USE lm_bi;

-- 1. STAGING RAW (Paso 2)
DROP TABLE IF EXISTS raw_ventas;
CREATE TABLE raw_ventas (
    _row_id         INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    venta_id        VARCHAR(255), fecha           VARCHAR(255), hora            VARCHAR(255),
    sucursal_id     VARCHAR(255), cliente_id      VARCHAR(255), canal           VARCHAR(255),
    metodo_pago     VARCHAR(255),
    _archivo_origen VARCHAR(100) NOT NULL DEFAULT 'POS/ventas.csv', _cargado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

LOAD DATA LOCAL INFILE 'C:/RUTA/AL/REPO/LibroMundo/ALUMNO/RAW/POS/ventas.csv'
INTO TABLE raw_ventas CHARACTER SET utf8mb4 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES 
(venta_id, fecha, hora, sucursal_id, cliente_id, canal, metodo_pago);

DROP TABLE IF EXISTS raw_detalle_ventas;
CREATE TABLE raw_detalle_ventas (
    _row_id         INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    venta_id        VARCHAR(255), linea           VARCHAR(255), producto_id     VARCHAR(255),
    cantidad        VARCHAR(255), precio_unitario VARCHAR(255), descuento_pct   VARCHAR(255), importe         VARCHAR(255),
    _archivo_origen VARCHAR(100) NOT NULL DEFAULT 'POS/detalle_ventas.csv', _cargado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

LOAD DATA LOCAL INFILE 'C:/RUTA/AL/REPO/LibroMundo/ALUMNO/RAW/POS/detalle_ventas.csv'
INTO TABLE raw_detalle_ventas CHARACTER SET utf8mb4 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES 
(venta_id, linea, producto_id, cantidad, precio_unitario, descuento_pct, importe);

-- 2. DIMENSIONES AL VUELO (Canal y Fecha con arreglo de WEEKOFYEAR)
INSERT INTO dim_canal (canal_id, nombre_canal)
SELECT UPPER(TRIM(canal)), UPPER(TRIM(canal)) FROM raw_ventas 
WHERE NULLIF(TRIM(canal),'') IS NOT NULL GROUP BY UPPER(TRIM(canal))
ON DUPLICATE KEY UPDATE nombre_canal = VALUES(nombre_canal);

INSERT IGNORE INTO dim_fecha (fecha_key, fecha, dia, nombre_dia, semana, mes, nombre_mes, trimestre, anio, es_fin_semana)
SELECT DISTINCT
    CAST(DATE_FORMAT(STR_TO_DATE(TRIM(fecha), '%Y-%m-%d'), '%Y%m%d') AS UNSIGNED),
    STR_TO_DATE(TRIM(fecha), '%Y-%m-%d'), DAY(STR_TO_DATE(TRIM(fecha), '%Y-%m-%d')), DAYNAME(STR_TO_DATE(TRIM(fecha), '%Y-%m-%d')),
    WEEKOFYEAR(STR_TO_DATE(TRIM(fecha), '%Y-%m-%d')), MONTH(STR_TO_DATE(TRIM(fecha), '%Y-%m-%d')),
    MONTHNAME(STR_TO_DATE(TRIM(fecha), '%Y-%m-%d')), QUARTER(STR_TO_DATE(TRIM(fecha), '%Y-%m-%d')),
    YEAR(STR_TO_DATE(TRIM(fecha), '%Y-%m-%d')), CASE WHEN DAYOFWEEK(STR_TO_DATE(TRIM(fecha), '%Y-%m-%d')) IN (1,7) THEN 1 ELSE 0 END
FROM raw_ventas WHERE TRIM(fecha) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$';

-- 3. NORMALIZACIÓN Y AGRUPACIÓN (Consolidando el Grano)
DROP TABLE IF EXISTS stg_fact_ventas;
CREATE TABLE stg_fact_ventas AS
SELECT 
    UPPER(TRIM(v.venta_id)) AS venta_id,
    CAST(DATE_FORMAT(STR_TO_DATE(TRIM(v.fecha), '%Y-%m-%d'), '%Y%m%d') AS UNSIGNED) AS fecha_key,
    COALESCE(c.cliente_key, (SELECT cliente_key FROM dim_cliente WHERE cliente_id = '-1')) AS cliente_key,
    i.item_key, s.sucursal_key, cn.canal_key,
    SUM(CAST(TRIM(d.cantidad) AS DECIMAL(14,3))) AS cantidad, MAX(CAST(TRIM(d.precio_unitario) AS DECIMAL(14,2))) AS precio_unitario,
    SUM(CAST(TRIM(d.importe) AS DECIMAL(14,2))) AS venta_neta,
    MAX(CAST(TRIM(d.precio_unitario) AS DECIMAL(14,2))) * 0.60 AS costo_unitario, MAX(v._row_id) AS _raw_row_id
FROM raw_ventas v
JOIN raw_detalle_ventas d ON TRIM(v.venta_id) COLLATE utf8mb4_0900_ai_ci = TRIM(d.venta_id) COLLATE utf8mb4_0900_ai_ci
LEFT JOIN dim_cliente c ON c.cliente_id = UPPER(TRIM(v.cliente_id))
JOIN dim_item i ON i.item_id = UPPER(TRIM(d.producto_id)) 
JOIN dim_sucursal s ON s.sucursal_id = UPPER(TRIM(v.sucursal_id))
JOIN dim_canal cn ON cn.canal_id = UPPER(TRIM(v.canal))
GROUP BY UPPER(TRIM(v.venta_id)), fecha_key, c.cliente_key, i.item_key, s.sucursal_key, cn.canal_key;

-- 4. VALIDACIÓN Y RECHAZOS (Paso 4)
INSERT INTO etl_rechazos (tabla_origen, raw_row_id, llave_negocio, motivo, valor_original)
SELECT 'raw_ventas', _raw_row_id, venta_id, 'ITEM_INEXISTENTE_O_ERROR', venta_id
FROM stg_fact_ventas WHERE item_key IS NULL OR sucursal_key IS NULL;

CREATE OR REPLACE VIEW v_fact_ventas_validas AS
SELECT 
    venta_id, fecha_key, cliente_key, item_key, sucursal_key, canal_key, NULL AS temporada_key, cantidad, 
    precio_unitario, ((cantidad * precio_unitario) - venta_neta) AS descuento, costo_unitario, FALSE AS es_preventa
FROM stg_fact_ventas
WHERE NOT EXISTS (SELECT 1 FROM etl_rechazos x WHERE x.tabla_origen = 'raw_ventas' AND x.raw_row_id = stg_fact_ventas._raw_row_id);

-- 5. CARGA DE HECHOS (Bypass safe mode para idempotencia)
SET SQL_SAFE_UPDATES = 0;
DELETE FROM fact_ventas WHERE venta_id IN (SELECT venta_id FROM v_fact_ventas_validas);
SET SQL_SAFE_UPDATES = 1;

INSERT INTO fact_ventas (venta_id, fecha_key, cliente_key, item_key, sucursal_key, canal_key, temporada_key, cantidad, precio_unitario, descuento, costo_unitario, es_preventa)
SELECT venta_id, fecha_key, cliente_key, item_key, sucursal_key, canal_key, temporada_key, cantidad, precio_unitario, descuento, costo_unitario, es_preventa
FROM v_fact_ventas_validas;

-- 6. CONCILIACIÓN
SET @leidas_v     = (SELECT COUNT(*) FROM raw_detalle_ventas);
SET @cargadas_v   = (SELECT COUNT(*) FROM fact_ventas);
INSERT INTO etl_log (proceso, inicio, fin, filas_leidas, filas_cargadas, filas_rechazadas, estatus, detalle)
VALUES ('fact_ventas', (SELECT MIN(_cargado_en) FROM raw_ventas), NOW(), @leidas_v, @cargadas_v, 0, 'OK', 'Ventas + Detalle consolidadas al grano corregido');