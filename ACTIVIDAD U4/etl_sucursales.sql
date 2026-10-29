USE lm_bi;

-- 1. STAGING RAW (Paso 2)
DROP TABLE IF EXISTS raw_sucursales;
CREATE TABLE raw_sucursales (
    _row_id         INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    sucursal_id     VARCHAR(255),
    sucursal        VARCHAR(255),
    ciudad          VARCHAR(255),
    estado          VARCHAR(255),
    m2              VARCHAR(255),
    fecha_apertura  VARCHAR(255),
    _archivo_origen VARCHAR(100) NOT NULL DEFAULT 'OPERACION/sucursales.csv',
    _cargado_en     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

LOAD DATA LOCAL INFILE 'C:/RUTA/AL/REPO/LibroMundo/ALUMNO/RAW/OPERACION/sucursales.csv'
INTO TABLE raw_sucursales CHARACTER SET utf8mb4 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES 
(sucursal_id, sucursal, ciudad, estado, m2, fecha_apertura);

-- 2. PERFILADO BÁSICO (Paso 1)
INSERT INTO etl_observaciones (fuente, metrica, valor)
SELECT 'raw_sucursales', 'filas', COUNT(*) FROM raw_sucursales UNION ALL 
SELECT 'raw_sucursales', 'ids_repetidos', COUNT(*) - COUNT(DISTINCT sucursal_id) FROM raw_sucursales;

-- 3. NORMALIZACIÓN (Paso 3)
CREATE TABLE IF NOT EXISTS cat_estado_region (
    estado VARCHAR(100) COLLATE utf8mb4_0900_ai_ci PRIMARY KEY, region VARCHAR(100) NOT NULL
);
TRUNCATE TABLE cat_estado_region;
INSERT INTO cat_estado_region (estado, region) VALUES ('Nuevo León', 'Noreste'), ('Coahuila', 'Noreste'), ('Tamaulipas', 'Noreste');

DROP TABLE IF EXISTS stg_sucursales;
CREATE TABLE stg_sucursales AS
SELECT UPPER(TRIM(r.sucursal_id)) as sucursal_id, TRIM(r.sucursal) as nombre, TRIM(r.ciudad) as ciudad, TRIM(r.estado) as estado, COALESCE(c.region, 'SIN_REGION') as region, r._row_id as _raw_row_id
FROM raw_sucursales r
LEFT JOIN cat_estado_region c ON TRIM(r.estado) COLLATE utf8mb4_0900_ai_ci = c.estado;

-- 4. VALIDACIÓN Y RECHAZOS (Paso 4)
INSERT INTO etl_rechazos (tabla_origen, raw_row_id, llave_negocio, motivo, valor_original)
SELECT 'raw_sucursales', _raw_row_id, sucursal_id, 'ID_VACIO', nombre
FROM stg_sucursales WHERE NULLIF(sucursal_id, '') IS NULL;

CREATE OR REPLACE VIEW v_sucursales_validas AS
SELECT * FROM stg_sucursales
WHERE NOT EXISTS (SELECT 1 FROM etl_rechazos x WHERE x.tabla_origen = 'raw_sucursales' AND x.raw_row_id = stg_sucursales._raw_row_id);

-- 5. CARGA INCREMENTAL (Paso 5)
INSERT INTO dim_sucursal (sucursal_id, nombre, ciudad, region)
SELECT sucursal_id, nombre, ciudad, region FROM v_sucursales_validas
ON DUPLICATE KEY UPDATE nombre = VALUES(nombre), ciudad = VALUES(ciudad), region = VALUES(region);

-- 6. CONCILIACIÓN (Paso 6)
SET @leidas_s     = (SELECT COUNT(*) FROM raw_sucursales);
SET @rechazadas_s = (SELECT COUNT(*) FROM etl_rechazos WHERE tabla_origen = 'raw_sucursales');
SET @cargadas_s   = (SELECT COUNT(*) FROM v_sucursales_validas);

INSERT INTO etl_log (proceso, inicio, fin, filas_leidas, filas_cargadas, filas_rechazadas, estatus, detalle)
VALUES ('sucursales', (SELECT MIN(_cargado_en) FROM raw_sucursales), NOW(), @leidas_s, @cargadas_s, @rechazadas_s, CASE WHEN @leidas_s = @cargadas_s + @rechazadas_s THEN 'OK' ELSE 'DESCUADRE' END, 'raw_sucursales -> stg_sucursales -> dim_sucursal');