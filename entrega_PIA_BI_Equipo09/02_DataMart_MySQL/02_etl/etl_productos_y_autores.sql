USE lm_bi;

-- 1. STAGING RAW (Paso 2)
DROP TABLE IF EXISTS raw_productos;
CREATE TABLE raw_productos (
    _row_id         INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, producto_id VARCHAR(255), sku VARCHAR(255),
    producto        VARCHAR(255), categoria VARCHAR(255), marca VARCHAR(255), costo VARCHAR(255),
    precio_lista    VARCHAR(255), activo VARCHAR(255), formato VARCHAR(255),
    _archivo_origen VARCHAR(100) NOT NULL DEFAULT 'ERP/productos.csv', _cargado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

LOAD DATA LOCAL INFILE 'C:/RUTA/AL/REPO/LibroMundo/ALUMNO/RAW/ERP/productos.csv'
INTO TABLE raw_productos CHARACTER SET utf8mb4 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES 
(producto_id, sku, producto, categoria, marca, costo, precio_lista, activo, formato);

DROP TABLE IF EXISTS raw_catalogo_editorial;
CREATE TABLE raw_catalogo_editorial (
    _row_id         INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, producto_id VARCHAR(255), autor VARCHAR(255),
    editorial       VARCHAR(255), anio_edicion VARCHAR(255), isbn VARCHAR(255),
    _archivo_origen VARCHAR(100) NOT NULL DEFAULT 'ESPECIFICO/catalogo_editorial.csv', _cargado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

LOAD DATA LOCAL INFILE 'C:/RUTA/AL/REPO/LibroMundo/ALUMNO/RAW/ESPECIFICO/catalogo_editorial.csv'
INTO TABLE raw_catalogo_editorial CHARACTER SET utf8mb4 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES 
(producto_id, autor, editorial, anio_edicion, isbn);

-- 2. PERFILADO BÁSICO (Paso 1)
INSERT INTO etl_observaciones (fuente, metrica, valor)
SELECT 'raw_productos', 'filas', COUNT(*) FROM raw_productos UNION ALL 
SELECT 'raw_catalogo_editorial', 'filas', COUNT(*) FROM raw_catalogo_editorial;

-- 3. NORMALIZACIÓN (Paso 3)
DROP TABLE IF EXISTS stg_productos;
CREATE TABLE stg_productos AS
SELECT 
    UPPER(TRIM(p.producto_id)) as item_id,
    CASE WHEN UPPER(TRIM(p.categoria)) IN ('PAPELERÍA', 'PAPELERIA', 'JUEGOS', 'REGALOS', 'MATERIAL ESCOLAR') THEN 'PRODUCTO_NO_EDITORIAL' ELSE 'LIBRO' END as tipo_item,
    TRIM(p.sku) as sku, TRIM(p.producto) as nombre, TRIM(p.categoria) as categoria_producto,
    NULLIF(TRIM(p.marca), '') as marca, NULLIF(TRIM(c.editorial), '') as editorial,
    CASE WHEN UPPER(TRIM(p.categoria)) IN ('PAPELERÍA', 'PAPELERIA', 'JUEGOS', 'REGALOS', 'MATERIAL ESCOLAR') THEN NULL ELSE TRIM(c.isbn) END as isbn,
    TRIM(c.autor) as autor_raw, p._row_id as _raw_row_id
FROM raw_productos p
LEFT JOIN raw_catalogo_editorial c ON TRIM(p.producto_id) COLLATE utf8mb4_0900_ai_ci = TRIM(c.producto_id) COLLATE utf8mb4_0900_ai_ci;

-- 4. VALIDACIÓN Y RECHAZOS (Paso 4)
INSERT INTO etl_rechazos (tabla_origen, raw_row_id, llave_negocio, motivo, valor_original)
SELECT 'raw_productos', _raw_row_id, item_id, 'ID_VACIO', nombre
FROM stg_productos WHERE NULLIF(item_id, '') IS NULL;

CREATE OR REPLACE VIEW v_productos_validos AS
SELECT * FROM stg_productos
WHERE NOT EXISTS (SELECT 1 FROM etl_rechazos x WHERE x.tabla_origen = 'raw_productos' AND x.raw_row_id = stg_productos._raw_row_id);

-- 5. CARGA INCREMENTAL (Paso 5)
INSERT INTO dim_item (item_id, tipo_item, sku, nombre, categoria_producto, marca, editorial, isbn)
SELECT item_id, tipo_item, sku, nombre, categoria_producto, marca, editorial, isbn FROM v_productos_validos
ON DUPLICATE KEY UPDATE tipo_item = VALUES(tipo_item), sku = VALUES(sku), nombre = VALUES(nombre), categoria_producto = VALUES(categoria_producto), marca = VALUES(marca), editorial = VALUES(editorial), isbn = VALUES(isbn);

INSERT INTO dim_autor (autor_id, nombre_autor)
SELECT DISTINCT UPPER(TRIM(autor_raw)), TRIM(autor_raw) FROM stg_productos WHERE NULLIF(TRIM(autor_raw), '') IS NOT NULL
ON DUPLICATE KEY UPDATE nombre_autor = VALUES(nombre_autor);

INSERT IGNORE INTO bridge_item_autor (item_key, autor_key, factor_asignacion)
SELECT d_item.item_key, d_autor.autor_key, 1.000000 AS factor_asignacion
FROM stg_productos s
JOIN dim_item d_item ON d_item.item_id = s.item_id
JOIN dim_autor d_autor ON d_autor.autor_id = UPPER(TRIM(s.autor_raw))
WHERE NULLIF(TRIM(s.autor_raw), '') IS NOT NULL;

-- 6. CONCILIACIÓN (Paso 6)
SET @leidas_p     = (SELECT COUNT(*) FROM raw_productos);
SET @rechazadas_p = (SELECT COUNT(*) FROM etl_rechazos WHERE tabla_origen = 'raw_productos');
SET @cargadas_p   = (SELECT COUNT(*) FROM v_productos_validos);

INSERT INTO etl_log (proceso, inicio, fin, filas_leidas, filas_cargadas, filas_rechazadas, estatus, detalle)
VALUES ('productos_catalogo', (SELECT MIN(_cargado_en) FROM raw_productos), NOW(), @leidas_p, @cargadas_p, @rechazadas_p, CASE WHEN @leidas_p = @cargadas_p + @rechazadas_p THEN 'OK' ELSE 'DESCUADRE' END, 'Cruce raw_productos + raw_catalogo_editorial -> dim_item');