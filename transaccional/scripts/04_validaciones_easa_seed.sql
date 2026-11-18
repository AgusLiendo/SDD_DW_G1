-- EASA | Consultas para revisar los datos simulados y planificar los cubos.
-- Ejecutar conectado a easa_oltp DESPUES de 03_poblar_easa_simulado.sql.

-- 1. Cobertura temporal de los hechos.
SELECT 'ventas' AS proceso, count(*) AS filas, min(fecha_hora)::date AS desde,
       max(fecha_hora)::date AS hasta,
       count(DISTINCT date_trunc('month',fecha_hora)) AS meses
FROM venta
UNION ALL
SELECT 'compras',count(*),min(fecha_hora)::date,max(fecha_hora)::date,
       count(DISTINCT date_trunc('month',fecha_hora)) FROM compra
UNION ALL
SELECT 'produccion',count(*),min(fecha_hora)::date,max(fecha_hora)::date,
       count(DISTINCT date_trunc('month',fecha_hora)) FROM instancia_de_produccion
UNION ALL
SELECT 'ajustes',count(*),min(fecha_hora)::date,max(fecha_hora)::date,
       count(DISTINCT date_trunc('month',fecha_hora)) FROM ajuste_stock;

-- 2. Cubo de demanda (Consulta 1): unidades por mes/producto/sucursal/segmento.
SELECT date_trunc('month',v.fecha_hora)::date AS mes,
       p.nombre AS producto,s.nombre AS sucursal,
       tc.nombre AS tipo_cliente,
       round(sum(dv.cantidad),3) AS unidades_vendidas,
       round(sum(dv.cantidad*dv.precio_unitario_historico),2) AS monto_vendido
FROM detalle_venta dv
JOIN venta v ON v.id=dv.venta_id
JOIN cliente c ON c.id=v.cliente_id
JOIN tipo_cliente tc ON tc.id=c.tipo_cliente_id
JOIN producto_sucursal ps ON ps.id=dv.producto_sucursal_id
JOIN producto p ON p.id=ps.producto_id
JOIN sucursal s ON s.id=ps.sucursal_id
GROUP BY 1,2,3,4 ORDER BY 1 DESC,2,3,4 LIMIT 30;

-- 3. Cubo de promociones (Consulta 2): ventas por promocion, producto y segmento.
-- Se informan solo ventas con promocion aplicada; las sin promocion
-- se analizan por separado, para no mezclar medidas.
SELECT pr.nombre AS promocion,p.nombre AS producto,tc.nombre AS tipo_cliente,
       round(sum(dv.cantidad*dv.precio_unitario_historico),2) AS monto,
       round(sum(dv.cantidad),3) AS unidades
FROM detalle_venta dv
JOIN promocion pr ON pr.id=dv.promocion_id
JOIN venta v ON v.id=dv.venta_id
JOIN cliente c ON c.id=v.cliente_id
JOIN tipo_cliente tc ON tc.id=c.tipo_cliente_id
JOIN producto_sucursal ps ON ps.id=dv.producto_sucursal_id
JOIN producto p ON p.id=ps.producto_id
GROUP BY 1,2,3 ORDER BY monto DESC LIMIT 30;

-- 4. Cubo de produccion/distribucion (Consulta 3): usar detalle_reparto como
-- unidad de analisis, SIN sumar varias veces la cantidad producida.
SELECT date_trunc('month',ip.fecha_hora)::date AS mes,
       p.nombre AS producto,origen.nombre AS planta_productora,
       destino.nombre AS sucursal_destino,
       round(sum(dr.cantidad),3) AS unidades_distribuidas
FROM detalle_reparto dr
JOIN reparto r ON r.id=dr.reparto_id
JOIN sucursal destino ON destino.id=r.sucursal_id
JOIN detalle_instancia_de_produccion dip ON dip.id=dr.detalle_instancia_produccion_id
JOIN instancia_de_produccion ip ON ip.id=dip.instancia_produccion_id
JOIN sucursal origen ON origen.id=ip.sucursal_id
JOIN producto p ON p.id=dip.producto_id
GROUP BY 1,2,3,4 ORDER BY 1 DESC,2,3,4 LIMIT 30;

-- 5. Compras y pagos: primero sumar cada lado POR COMPRA para evitar
-- multiplicacion de filas entre detalle_compra y detalle_pago.
WITH totales AS (
 SELECT dc.compra_id,round(sum(dc.cantidad*dc.precio_unitario_historico),2) AS monto_compra
 FROM detalle_compra dc GROUP BY dc.compra_id
), pagos AS (
 SELECT dp.compra_id,sum(dp.monto) AS monto_pagado
 FROM detalle_pago dp GROUP BY dp.compra_id
)
SELECT pr.razon_social AS proveedor,e.nombre AS estado,
       round(sum(t.monto_compra),2) AS monto_comprado,
       round(sum(coalesce(pg.monto_pagado,0)),2) AS monto_pagado,
       round(sum(t.monto_compra-coalesce(pg.monto_pagado,0)),2) AS pendiente
FROM compra c
JOIN proveedor pr ON pr.id=c.proveedor_id
JOIN estado e ON e.id=c.estado_id
JOIN totales t ON t.compra_id=c.id
LEFT JOIN pagos pg ON pg.compra_id=c.id
WHERE c.fecha_hora>=DATE '2025-05-01'
GROUP BY 1,2 ORDER BY pendiente DESC;

-- 6. Ajustes de INSUMOS (Consulta 5), con signo y valor absoluto separados.
SELECT date_trunc('month',a.fecha_hora)::date AS mes,
       s.nombre AS sucursal,i.nombre AS insumo,
       count(*) AS cantidad_ajustes,
       round(sum(a.cantidad),3) AS unidades_netas,
       round(sum(abs(a.cantidad)),3) AS unidades_ajustadas_absolutas
FROM ajuste_stock a
JOIN insumo_sucursal isu ON isu.id=a.insumo_sucursal_id
JOIN insumo i ON i.id=isu.insumo_id
JOIN sucursal s ON s.id=isu.sucursal_id
WHERE a.fecha_hora>=DATE '2026-05-01'
GROUP BY 1,2,3 ORDER BY mes DESC,s.nombre,i.nombre;

-- 7. Conciliacion del inventario final con movimientos.
SELECT 'productos' AS entidad,count(*) AS discrepancias
FROM producto_sucursal ps
WHERE abs(ps.stock_actual-coalesce((SELECT sum(ms.cantidad)
       FROM movimiento_stock ms WHERE ms.producto_sucursal_id=ps.id),0))>0.001
UNION ALL
SELECT 'insumos',count(*) FROM insumo_sucursal isu
WHERE abs(isu.stock_actual-coalesce((SELECT sum(ms.cantidad)
       FROM movimiento_stock ms WHERE ms.insumo_sucursal_id=isu.id),0))>0.001;

-- 8. Conciliacion de repartos: diferencia debe ser cero.
SELECT count(*) AS producciones_con_reparto_incorrecto
FROM (
 SELECT dip.id
 FROM detalle_instancia_de_produccion dip
 LEFT JOIN detalle_reparto dr ON dr.detalle_instancia_produccion_id=dip.id
 GROUP BY dip.id,dip.cantidad
 HAVING coalesce(sum(dr.cantidad),0)<>dip.cantidad
) t;
