USE lm_bi;

-- 1. STAGING RAW (Paso 2)
DROP TABLE IF EXISTS raw_promociones;
CREATE TABLE raw_promociones (
    _row_id         INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    promocion_id    VARCHAR(255),
    nombre          VARCHAR(255),
    fecha_inicio    VARCHAR(255),
    descuento_pct   VARCHAR(255),
    fecha_fin       VARCHAR(255),
    _archivo_origen VARCHAR(100) NOT NULL DEFAULT 'MARKETING/promociones.csv',
    _cargado_en     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

LOAD DATA LOCAL INFILE 'C:/RUTA/AL/REPO/LibroMundo/ALUMNO/RAW/MARKETING/promociones.csv'
INTO TABLE raw_promociones CHARACTER SET utf8mb4 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES 
(promocion_id, nombre, fecha_inicio, descuento_pct, fecha_fin);

-- 2. PERFILADO BÁSICO (Paso 1)
INSERT INTO etl_observaciones (fuente, metrica, valor)
SELECT 'raw_promociones', 'filas', COUNT(*) FROM raw_promociones UNION ALL 
SELECT 'raw_promociones', 'ids_repetidos', COUNT(*) - COUNT(DISTINCT promocion_id) FROM raw_promociones;

-- 3. NORMALIZACIÓN (Paso 3)
DROP TABLE IF EXISTS stg_promociones;
CREATE TABLE stg_promociones AS
SELECT 
    UPPER(TRIM(promocion_id)) as promocion_id, TRIM(nombre) as nombre, 'DESCUENTO' as tipo_promocion,
    CONCAT('Descuento del ', TRIM(descuento_pct), '%') as descripcion,
    STR_TO_DATE(TRIM(fecha_inicio), '%Y-%m-%d') as fecha_inicio, STR_TO_DATE(TRIM(fecha_fin), '%Y-%m-%d') as fecha_fin, _row_id as _raw_row_id
FROM raw_promociones;

-- 4. VALIDACIÓN Y RECHAZOS (Paso 4)
INSERT INTO etl_rechazos (tabla_origen, raw_row_id, llave_negocio, motivo, valor_original)
SELECT 'raw_promociones', _raw_row_id, promocion_id, 
    CASE 
        WHEN NULLIF(promocion_id, '') IS NULL THEN 'ID_VACIO'
        WHEN fecha_inicio IS NULL OR fecha_fin IS NULL THEN 'FECHA_NULA'
        WHEN fecha_fin < fecha_inicio THEN 'FECHAS_INVERTIDAS'
    END, nombre
FROM stg_promociones 
WHERE NULLIF(promocion_id, '') IS NULL OR fecha_inicio IS NULL OR fecha_fin IS NULL OR fecha_fin < fecha_inicio;

CREATE OR REPLACE VIEW v_promociones_validas AS
SELECT * FROM stg_promociones
WHERE NOT EXISTS (SELECT 1 FROM etl_rechazos x WHERE x.tabla_origen = 'raw_promociones' AND x.raw_row_id = stg_promociones._raw_row_id);

-- 5. CARGA INCREMENTAL (Paso 5)
INSERT INTO dim_promocion (promocion_id, nombre, tipo_promocion, descripcion, fecha_inicio, fecha_fin)
SELECT promocion_id, nombre, tipo_promocion, descripcion, fecha_inicio, fecha_fin FROM v_promociones_validas
ON DUPLICATE KEY UPDATE nombre = VALUES(nombre), tipo_promocion = VALUES(tipo_promocion), descripcion = VALUES(descripcion), fecha_inicio = VALUES(fecha_inicio), fecha_fin = VALUES(fecha_fin);
    
-- 6. CONCILIACIÓN (Paso 6)
SET @leidas_prom     = (SELECT COUNT(*) FROM raw_promociones);
SET @rechazadas_prom = (SELECT COUNT(*) FROM etl_rechazos WHERE tabla_origen = 'raw_promociones');
SET @cargadas_prom   = (SELECT COUNT(*) FROM v_promociones_validas);

INSERT INTO etl_log (proceso, inicio, fin, filas_leidas, filas_cargadas, filas_rechazadas, estatus, detalle)
VALUES ('promociones', (SELECT MIN(_cargado_en) FROM raw_promociones), NOW(), @leidas_prom, @cargadas_prom, @rechazadas_prom, CASE WHEN @leidas_prom = @cargadas_prom + @rechazadas_prom THEN 'OK' ELSE 'DESCUADRE' END, 'raw_promociones -> stg_promociones -> dim_promocion');