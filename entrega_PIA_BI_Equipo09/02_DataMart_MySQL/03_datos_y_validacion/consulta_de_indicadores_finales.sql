USE lm_bi;

-- PASO 7: INDICADORES (Ventas y pedidos por región y mes/año)
SELECT 
    s.region,
    f.anio,
    f.mes,
    COUNT(DISTINCT v.venta_id) AS total_pedidos,
    SUM(v.venta_neta) AS total_ventas_netas
FROM fact_ventas v
JOIN dim_sucursal s ON v.sucursal_key = s.sucursal_key
JOIN dim_fecha f ON v.fecha_key = f.fecha_key
GROUP BY 
    s.region, 
    f.anio,
    f.mes
ORDER BY 
    f.anio DESC, 
    f.mes DESC, 
    total_ventas_netas DESC;