USE lm_bi;

-- 1. STAGING RAW (Paso 2)
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
INTO TABLE raw_clientes CHARACTER SET utf8mb4 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES 
(cliente_id, nombre, sexo, fecha_alta, ciudad, segmento, email);

-- 2. PERFILADO BÁSICO (Paso 1)
INSERT INTO etl_observaciones (fuente, metrica, valor)
SELECT 'raw_clientes', 'filas', COUNT(*) FROM raw_clientes UNION ALL 
SELECT 'raw_clientes', 'ids_repetidos', COUNT(*) - COUNT(DISTINCT cliente_id) FROM raw_clientes UNION ALL 
SELECT 'raw_clientes', 'ciudad_vacia', SUM(NULLIF(TRIM(ciudad),'') IS NULL) FROM raw_clientes UNION ALL 
SELECT 'raw_clientes', 'email_vacio', SUM(NULLIF(TRIM(email),'') IS NULL) FROM raw_clientes UNION ALL 
SELECT 'raw_clientes', 'fecha_no_iso', SUM(fecha_alta NOT REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$') FROM raw_clientes;

-- 3. NORMALIZACIÓN (Paso 3)
CREATE TABLE IF NOT EXISTS cat_ciudad (
    variante VARCHAR(100) COLLATE utf8mb4_0900_ai_ci NOT NULL PRIMARY KEY, ciudad_canonica VARCHAR(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

TRUNCATE TABLE cat_ciudad;
INSERT INTO cat_ciudad (variante, ciudad_canonica) VALUES
('Tampico','Tampico'), ('Monterrey','Monterrey'), ('Apodaca','Apodaca'), ('San Nicolás','San Nicolás'),
('Escobedo','Escobedo'), ('Reynosa','Reynosa'), ('Guadalupe','Guadalupe'), ('Santa Catarina','Santa Catarina'),
('San Pedro','San Pedro'), ('Saltillo','Saltillo'), ('MTY','Monterrey'), ('Sn Nicolas','San Nicolás');

DROP TABLE IF EXISTS stg_clientes;
CREATE TABLE stg_clientes AS
SELECT 
    UPPER(TRIM(r.cliente_id)) as cliente_id, NULLIF(TRIM(r.nombre), '') as nombre, UPPER(NULLIF(TRIM(r.sexo), '')) as sexo,
    CASE 
      WHEN TRIM(r.fecha_alta) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN STR_TO_DATE(TRIM(r.fecha_alta), '%Y-%m-%d')
      WHEN TRIM(r.fecha_alta) REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$' THEN STR_TO_DATE(TRIM(r.fecha_alta), '%d/%m/%Y')
    END as fecha_alta,
    c.ciudad_canonica as ciudad, r.ciudad as ciudad_raw, 
    CONCAT(UPPER(LEFT(NULLIF(TRIM(r.segmento),''),1)), LOWER(SUBSTRING(NULLIF(TRIM(r.segmento),''),2))) as segmento,
    LOWER(NULLIF(TRIM(r.email), '')) as email, r._row_id as _raw_row_id
FROM (
    SELECT x.*, ROW_NUMBER() OVER (PARTITION BY UPPER(TRIM(x.cliente_id)) ORDER BY x._row_id) AS rn 
    FROM raw_clientes x WHERE NULLIF(TRIM(x.cliente_id), '') IS NOT NULL
) r
LEFT JOIN cat_ciudad c ON TRIM(r.ciudad) COLLATE utf8mb4_0900_ai_ci = c.variante
WHERE r.rn = 1;

-- 4. VALIDACIÓN Y RECHAZOS (Paso 4)
INSERT INTO etl_rechazos (tabla_origen, raw_row_id, llave_negocio, motivo, valor_original)
SELECT 'raw_clientes', r._row_id, NULLIF(TRIM(r.cliente_id), ''),
    CASE
      WHEN NULLIF(TRIM(r.cliente_id), '') IS NULL THEN 'ID_VACIO'
      WHEN s.cliente_id IS NULL THEN 'ID_DUPLICADO'
      WHEN s.fecha_alta IS NULL THEN 'FECHA_INVALIDA'
      WHEN s.fecha_alta > CURDATE() THEN 'FECHA_FUTURA'
    END, CONCAT_WS(' | ', r.cliente_id, r.nombre, r.fecha_alta)
FROM raw_clientes r
LEFT JOIN stg_clientes s ON s._raw_row_id = r._row_id
WHERE NULLIF(TRIM(r.cliente_id), '') IS NULL OR s.cliente_id IS NULL OR s.fecha_alta IS NULL OR s.fecha_alta > CURDATE();

CREATE OR REPLACE VIEW v_clientes_validos AS
SELECT s.cliente_id, s.nombre, s.sexo, s.fecha_alta, COALESCE(s.ciudad, 'NO_IDENTIFICADO') AS ciudad, s.segmento, s.email, s._raw_row_id
FROM stg_clientes s
WHERE NOT EXISTS (SELECT 1 FROM etl_rechazos x WHERE x.tabla_origen = 'raw_clientes' AND x.raw_row_id = s._raw_row_id);

-- 5. CARGA INCREMENTAL (Paso 5)
INSERT INTO dim_cliente (cliente_id, nombre, tipo_cliente, segmento_cliente, ciudad, limite_credito)
SELECT cliente_id, nombre, NULL, UPPER(segmento), ciudad, NULL FROM v_clientes_validos
ON DUPLICATE KEY UPDATE nombre = VALUES(nombre), segmento_cliente = VALUES(segmento_cliente), ciudad = VALUES(ciudad);

-- 6. CONCILIACIÓN (Paso 6)
SET @leidas     = (SELECT COUNT(*) FROM raw_clientes);
SET @rechazadas = (SELECT COUNT(*) FROM etl_rechazos WHERE tabla_origen = 'raw_clientes');
SET @cargadas   = (SELECT COUNT(*) FROM v_clientes_validos);

INSERT INTO etl_log (proceso, inicio, fin, filas_leidas, filas_cargadas, filas_rechazadas, estatus, detalle)
VALUES ('clientes', (SELECT MIN(_cargado_en) FROM raw_clientes), NOW(), @leidas, @cargadas, @rechazadas, CASE WHEN @leidas = @cargadas + @rechazadas THEN 'OK' ELSE 'DESCUADRE' END, 'raw_clientes -> stg_clientes -> dim_cliente');