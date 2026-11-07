USE lm_bi;

-- 1. STAGING RAW
DROP TABLE IF EXISTS raw_devoluciones;
CREATE TABLE raw_devoluciones (
    _row_id           INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    devolucion_id     VARCHAR(255), venta_id          VARCHAR(255), producto_id       VARCHAR(255),
    cantidad_devuelta VARCHAR(255), importe_devuelto  VARCHAR(255), motivo            VARCHAR(255),
    _archivo_origen   VARCHAR(100) NOT NULL DEFAULT 'POS/devoluciones.csv', _cargado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

LOAD DATA LOCAL INFILE 'C:/RUTA/AL/REPO/LibroMundo/ALUMNO/RAW/POS/devoluciones.csv'
INTO TABLE raw_devoluciones CHARACTER SET utf8mb4 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES 
(devolucion_id, venta_id, producto_id, cantidad_devuelta, importe_devuelto, motivo);

-- 2. NORMALIZACIÓN Y CRUCE (Heredando llaves de fact_ventas)
DROP TABLE IF EXISTS stg_devoluciones;
CREATE TABLE stg_devoluciones AS
SELECT 
    UPPER(TRIM(r.devolucion_id)) AS devolucion_id, UPPER(TRIM(r.venta_id)) AS venta_id,
    i.item_key, v.fecha_key, v.sucursal_key, TRIM(r.motivo) AS motivo_devolucion,
    CAST(TRIM(r.cantidad_devuelta) AS DECIMAL(14,3)) AS cantidad_devuelta,
    CAST(TRIM(r.importe_devuelto) AS DECIMAL(14,2)) AS importe_devuelto,
    v.cantidad AS cantidad_vendida, r._row_id AS _raw_row_id
FROM raw_devoluciones r
JOIN dim_item i ON i.item_id = UPPER(TRIM(r.producto_id))
LEFT JOIN fact_ventas v ON v.venta_id = UPPER(TRIM(r.venta_id)) AND v.item_key = i.item_key;

-- 3. VALIDACIÓN Y RECHAZOS 
INSERT INTO etl_rechazos (tabla_origen, raw_row_id, llave_negocio, motivo, valor_original)
SELECT 'raw_devoluciones', _raw_row_id, devolucion_id,
    CASE
        WHEN item_key IS NULL OR fecha_key IS NULL THEN 'VENTA_O_ITEM_INEXISTENTE'
        WHEN cantidad_devuelta > cantidad_vendida THEN 'DEVOLUCION_EXCEDE_VENTA'
    END, venta_id
FROM stg_devoluciones
WHERE item_key IS NULL OR fecha_key IS NULL OR cantidad_devuelta > cantidad_vendida;

CREATE OR REPLACE VIEW v_devoluciones_validas AS
SELECT devolucion_id, venta_id, fecha_key, item_key, sucursal_key, motivo_devolucion, importe_devuelto, cantidad_devuelta
FROM stg_devoluciones
WHERE NOT EXISTS (SELECT 1 FROM etl_rechazos x WHERE x.tabla_origen = 'raw_devoluciones' AND x.raw_row_id = stg_devoluciones._raw_row_id);

-- 4. CARGA A HECHOS
SET SQL_SAFE_UPDATES = 0;
DELETE FROM fact_devoluciones WHERE devolucion_id IN (SELECT devolucion_id FROM v_devoluciones_validas);
SET SQL_SAFE_UPDATES = 1;

INSERT INTO fact_devoluciones (devolucion_id, venta_id, fecha_key, item_key, sucursal_key, motivo_devolucion, importe_devuelto, cantidad_devuelta)
SELECT devolucion_id, venta_id, fecha_key, item_key, sucursal_key, motivo_devolucion, importe_devuelto, cantidad_devuelta
FROM v_devoluciones_validas;

-- 5. CONCILIACIÓN
SET @leidas_d     = (SELECT COUNT(*) FROM raw_devoluciones);
SET @cargadas_d   = (SELECT COUNT(*) FROM fact_devoluciones);
INSERT INTO etl_log (proceso, inicio, fin, filas_leidas, filas_cargadas, filas_rechazadas, estatus, detalle)
VALUES ('devoluciones', (SELECT MIN(_cargado_en) FROM raw_devoluciones), NOW(), @leidas_d, @cargadas_d, (SELECT COUNT(*) FROM etl_rechazos WHERE tabla_origen='raw_devoluciones'), 'OK', 'Devoluciones heredando fecha y sucursal de fact_ventas');