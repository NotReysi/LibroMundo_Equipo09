# LibroMundo — Proyecto de bases de datos (MySQL 8.0+)

### Miembros
- 2227015 Uriel Samuel Bravo Castillo
- 2226968 Orlando Alvarado Vargas
- 2227010 Nelson Tadeo Muñoz Flores

---

## Descripción

Repositorio del equipo para la materia de bases de datos, caso LibroMundo (retail de libros, papelería y juegos). Reúne tres actividades: el modelo dimensional (Actividad 1), las consultas SQL empresariales con apoyo de IA sobre un data mart en MySQL (Actividad 2) y el laboratorio de ETL sobre los datos entregados por el profesor (Actividad 3). Cada actividad vive en una carpeta propia y sus scripts apuntan a bases de datos distintas.

## Mapa del repositorio

```text
.
├── README.md
├── ACTIVIDAD U2/                          Actividad 1: modelo dimensional (PDF)
├── ACTIVIDAD U3/                          Actividad 2: consultas SQL con apoyo de IA
│   ├── 01_modelo_unidad_2/                Copia de los PDF del modelo dimensional
│   ├── 02_ddl_y_datos/                    DDL MySQL 8, carga de datos simulados y validación de carga
│   │   └── Screenshots/                   Capturas (Bloque 1 a 5)
│   ├── 03_prompts_ia/                     Prompts y respuestas de la IA
│   ├── 04_consultas_sql/                  Consulta final (Top 5 por región, Q2 vs Q1)
│   ├── 05_validacion_y_explain/           Validaciones, Error 1055, EXPLAIN e índice
│   │   └── Screenshots/                   Capturas de validaciones, error y consultas
│   ├── 06_stored_procedure/               Procedimiento almacenado del reporte
│   └── 07_conclusion/                     Conclusión y hallazgos
└── ACTIVIDAD U4/                          Actividad 3: Laboratorio 4 (ETL de LibroMundo)
    ├── LibroMundo/                        Datos entregados por el profesor (RAW, diccionario, SQL base)
    ├── LibroMundo_DataMart_DDL_Corregido.sql
    ├── etl_*.sql                          Scripts ETL por fuente
    └── consulta_de_indicadores_finales.sql
```

Los nombres de las carpetas raíz corresponden a la unidad del curso, no al número de actividad: `ACTIVIDAD U2` es la Actividad 1, `ACTIVIDAD U3` la Actividad 2 y `ACTIVIDAD U4` la Actividad 3. Varias rutas contienen espacios; deben ir entre comillas en la terminal.

## Actividad 1: modelo dimensional

- **Objetivo:** diseñar el modelo dimensional de LibroMundo (diagramas y esquema estrella).
- **Carpeta:** `ACTIVIDAD U2/`
- **Archivos:**
  - `Actividad 2 - Equipo 9.pdf`: documento de la actividad.
  - `Diagramas_Modelo_LibroMundo.pdf`: diagramas del modelo.
  - `Esquema_Estrella_Final_LibroMundo.pdf`: esquema estrella final.
- Los mismos tres PDF se encuentran en `ACTIVIDAD U3/01_modelo_unidad_2/`.

## Actividad 2: consultas SQL con apoyo de IA

- **Objetivo:** construir en MySQL 8 el reporte de los cinco productos más rentables por región en el segundo trimestre de 2026, con su variación frente al primer trimestre, y validarlo con pruebas y `EXPLAIN`.
- **Carpeta:** `ACTIVIDAD U3/`
- **Base de datos:** `dm_libromundo`
- **Archivos:**
  - `02_ddl_y_datos/00_reset.sql`: elimina la base `dm_libromundo` para repetir el DDL.
  - `02_ddl_y_datos/LibroMundo_DataMart_DDL_MySQL8.sql`: DDL del data mart adaptado a MySQL 8.
  - `02_ddl_y_datos/03_carga_datos.sql`: carga de datos simulados (dimensión fecha de 2026 y el procedimiento `sp_generar_ventas`).
  - `02_ddl_y_datos/04_validacion_carga.sql`: verificación de volumen y cobertura por trimestre y región.
  - `02_ddl_y_datos/Screenshots/`: `Bloque 1.png` a `Bloque 5.png`.
  - `03_prompts_ia/prompt_inicial.md`, `rentabilidad_libromundo.md`, `respuestasIA.md`: prompts, definición de rentabilidad y respuestas de la IA.
  - `04_consultas_sql/consulta_final.sql`: consulta Top 5 de Q2 vs Q1.
  - `05_validacion_y_explain/validaciones.sql`: pruebas de validación.
  - `05_validacion_y_explain/error_1055.sql`: SELECT defectuoso (Error 1055) y SELECT corregido.
  - `05_validacion_y_explain/optimizacion_explain.sql`: `EXPLAIN` original, índice propuesto y `EXPLAIN` posterior.
  - `05_validacion_y_explain/evidencia_explain.md`: resultado escrito del análisis con `EXPLAIN`.
  - `05_validacion_y_explain/Screenshots/`: capturas de DDL, datos, validaciones, error y consultas.
  - `06_stored_procedure/procedimiento_reporte.sql`: procedimiento `sp_top5_rentabilidad_region` y `CALL` de prueba.
  - `07_conclusion/conclusion.md`: hallazgos, limitaciones y aprendizajes.

### Orden de ejecución (Actividad 2)

1. `ACTIVIDAD U3/02_ddl_y_datos/LibroMundo_DataMart_DDL_MySQL8.sql`: ejecutar en MySQL Workbench. El DDL no es re-ejecutable; para repetirlo, ejecutar antes `00_reset.sql`.
2. `ACTIVIDAD U3/02_ddl_y_datos/03_carga_datos.sql`: cargar datos Q1/Q2 2026 válidos (>= 1000 filas en `fact_ventas`, >= 3 regiones, >= 5 productos con actividad Q2 en cada región). Sin datos, los reportes quedan vacíos.
3. `ACTIVIDAD U3/02_ddl_y_datos/04_validacion_carga.sql`: confirmar volumen y cobertura.
4. `ACTIVIDAD U3/05_validacion_y_explain/validaciones.sql`: ejecutar las pruebas y guardar los resultados.
5. `ACTIVIDAD U3/04_consultas_sql/consulta_final.sql`: Top 5 para Q2 vs Q1.
6. `ACTIVIDAD U3/05_validacion_y_explain/error_1055.sql`: ejecutar por separado el SELECT defectuoso (captura del Error 1055) y el corregido.
7. `ACTIVIDAD U3/05_validacion_y_explain/optimizacion_explain.sql`: ejecutar `EXPLAIN`, agregar el índice propuesto, volver a ejecutar y comparar. El índice no tiene mejora garantizada.
8. `ACTIVIDAD U3/06_stored_procedure/procedimiento_reporte.sql`: crear el procedimiento y ejecutar el `CALL` de prueba.
9. `ACTIVIDAD U3/07_conclusion/conclusion.md`: documento de cierre (no se ejecuta).

### Decisiones y límites (Actividad 2)

- **Grano:** `fact_ventas` = ítem dentro de una transacción. El DDL restringe `(venta_id, item_key)` a único.
- **Región:** `dim_sucursal.region`, sucursal de origen de la venta.
- **Rentabilidad monetaria:** `SUM(fact_ventas.margen)` menos `SUM(fact_devoluciones.importe_devuelto)` asignado a la fecha de la venta original, respetando la regla del negocio.
- **Provisional:** no equivale a beneficio económico neto cuando la devolución recupera inventario, pues falta registrar el costo recuperado.
- **Descuentos:** incluidos en el `margen` generado a partir de `venta_neta`.
- **Cancelaciones:** el modelo no contiene columna de estado; no hay forma de excluirlas con una condición real.
- **Devoluciones:** se agregan por separado para evitar duplicar margen por JOIN 1:N. Solo entran si `(venta_id, item_key)` identifica una venta original.
- **Bridges:** no se usan los bridges de autores, géneros, promociones ni eventos en la consulta central, porque son uniones con cardinalidad potencialmente multiplicadora de filas.
- **Q1:** 2026-01-01 inclusive a 2026-04-01 exclusive. **Q2:** 2026-04-01 inclusive a 2026-07-01 exclusive.
- **Porcentaje de variación:** `(Q2-Q1) / ABS(Q1) * 100`. Se devuelve NULL cuando la base monetaria de Q1 es cero; el indicador distingue entre sin datos y base cero con registros.
- **Top 5:** `ROW_NUMBER() OVER(PARTITION BY region ORDER BY rentabilidad_q2 DESC, item_id, item_key)`; requiere actividad en Q2 (`registros_q2 > 0`). Incluye pérdidas si están entre los cinco primeros.

### Diferencias de motor PostgreSQL → MySQL

El DDL original de la Unidad 2 estaba en PostgreSQL; **no ejecutarlo en MySQL**. Cambios principales:

| PostgreSQL | MySQL |
|---|---|
| `GENERATED ALWAYS AS IDENTITY` | `AUTO_INCREMENT` |
| `CREATE SCHEMA` + `SET search_path` | `CREATE DATABASE` + `USE` |
| `ON CONFLICT` | `ON DUPLICATE KEY UPDATE` |
| `COMMENT ON TABLE` | eliminado |
| `FILTER (WHERE ...)` | `SUM(CASE WHEN ...)` |
| `::numeric` | `CAST(... AS DECIMAL)` |
| `ORDER BY ... NULLS LAST` | `ORDER BY` |
| `RAISE EXCEPTION` | `SIGNAL` |
| Procedimiento con cursor | `CALL` que ejecuta un `SELECT` |

La demostración de agrupación estricta usa el Error 1055 de MySQL bajo `ONLY_FULL_GROUP_BY`.

## Actividad 3: Laboratorio 4 (ETL de LibroMundo)

- **Objetivo:** construir un pipeline ETL en SQL (staging RAW, limpieza, dimensiones y hechos, bitácora) sobre los CSV de LibroMundo y consultar indicadores finales.
- **Carpeta:** `ACTIVIDAD U4/`
- **Base de datos:** `lm_bi`
- **Archivos:**
  - `LibroMundo/`: datos del profesor.
    - `MANIFEST.json`: conteo de registros por entidad.
    - `ALUMNO/DOCS/README_ALUMNO.md` y `diccionario_fuentes_raw.csv`: enunciado y diccionario de los CSV.
    - `ALUMNO/SQL_BASE/00_crear_bd_y_log.sql`: crea `lm_bi` y `etl_log`.
    - `ALUMNO/RAW/`: CSV fuente en `COMPRAS`, `CRM`, `ERP`, `ESPECIFICO`, `INVENTARIO`, `MARKETING`, `OPERACION` y `POS`.
  - `LibroMundo_DataMart_DDL_Corregido.sql`: DDL del data mart en `lm_bi` (incluye `etl_log`; llaves de negocio ajustadas a `VARCHAR`).
  - `etl_sucursales.sql`, `etl_clientes.sql`, `etl_productos_y_autores.sql`, `etl_promociones.sql`, `etl_ventas_y_detalle.sql`, `etl_devoluciones.sql`: ETL por fuente.
  - `consulta_de_indicadores_finales.sql`: ventas netas y pedidos por región, año y mes.
- **Fuente de datos compartida:** los datos del profesor están en `ACTIVIDAD U4/LibroMundo/`. Los scripts de la Actividad 2 no leen esos CSV (generan datos simulados en `03_carga_datos.sql`).

### Orden de ejecución (Actividad 3)

Orden deducido de las dependencias entre scripts (las dimensiones deben existir antes de los hechos):

1. `ACTIVIDAD U4/LibroMundo_DataMart_DDL_Corregido.sql`: crea `lm_bi`, `etl_log` y el modelo dimensional. (`LibroMundo/ALUMNO/SQL_BASE/00_crear_bd_y_log.sql` crea solo la base y `etl_log`; el DDL corregido ya incluye `etl_log`, por lo que ese paso es opcional.)
2. `ACTIVIDAD U4/etl_sucursales.sql`: `dim_sucursal`.
3. `ACTIVIDAD U4/etl_clientes.sql`: `dim_cliente`.
4. `ACTIVIDAD U4/etl_productos_y_autores.sql`: `dim_item`, `dim_autor`, `bridge_item_autor`.
5. `ACTIVIDAD U4/etl_promociones.sql`: `dim_promocion`.
6. `ACTIVIDAD U4/etl_ventas_y_detalle.sql`: `dim_canal`, `dim_fecha` y `fact_ventas`; requiere `dim_cliente`, `dim_item` y `dim_sucursal`.
7. `ACTIVIDAD U4/etl_devoluciones.sql`: `fact_devoluciones`; hereda llaves de `fact_ventas`.
8. `ACTIVIDAD U4/consulta_de_indicadores_finales.sql`: indicadores finales.

<!-- TODO: confirmar el orden de los pasos 2 a 5, ya que ningún script lo impone entre sí; solo los pasos 6 y 7 dependen de los anteriores. -->
<!-- TODO: confirmar dónde se crean las tablas `etl_observaciones` y `etl_rechazos`, usadas por los scripts ETL; no se encontraron en `LibroMundo_DataMart_DDL_Corregido.sql` ni en `00_crear_bd_y_log.sql`. -->

## Requisitos

- **MySQL 8.0.16 o superior**, para que las restricciones `CHECK` se apliquen. Se usa MySQL Workbench como cliente.
- **Actividad 3: `local_infile`.** Los scripts `etl_*.sql` cargan los CSV con `LOAD DATA LOCAL INFILE`, por lo que `local_infile` debe estar habilitado en el servidor (`SET GLOBAL local_infile = 1;`) y en la conexión del cliente.
- **Actividad 3: rutas de los CSV.** Los scripts contienen la ruta de ejemplo `C:/RUTA/AL/REPO/LibroMundo/ALUMNO/RAW/...`. Hay que reemplazar `C:/RUTA/AL/REPO` por la ruta local de `ACTIVIDAD U4` antes de ejecutarlos.
- **Actividad 2:** no requiere `local_infile`; los scripts de `ACTIVIDAD U3/` no usan `LOAD DATA`.