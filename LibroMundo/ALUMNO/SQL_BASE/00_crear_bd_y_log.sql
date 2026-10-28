-- LibroMundo | Base inicial para el alumno | MySQL 8+
CREATE DATABASE IF NOT EXISTS `lm_bi`;
USE `lm_bi`;

CREATE TABLE etl_log (
  run_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  proceso VARCHAR(100), inicio DATETIME, fin DATETIME,
  filas_leidas BIGINT, filas_cargadas BIGINT, filas_rechazadas BIGINT,
  estatus VARCHAR(20), detalle VARCHAR(500)
);
-- El alumno debe crear las tablas staging a partir del diccionario de los CSV
-- y construir su modelo dimensional. No se incluye la solución del esquema estrella.
