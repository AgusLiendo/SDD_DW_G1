-- ============================================================================
-- EASA | PPAI SSD - Datos operacionales FICTICIOS para practicar ETL / OLAP
-- Compatible con easa_oltp_schema.sql / easa_oltp_docker_todo_en_uno.sql
-- PostgreSQL 15+ | SQL/PLpgSQL puro: funciona con psql y pgAdmin.
--
-- PERIODO: 2023-01-01 a 2026-10-31 (46 meses, HISTORICO SIMULADO).
-- IMPORTANTE: usar SOLO en una base DE PRUEBAS (easa_oltp).
-- Este script NO crea la base ni las tablas, NO crea el DW.
-- Ejecutar UNA SOLA VEZ con las tablas operacionales vacias.
-- El proceso es atomico: si falla, se revierte todo el poblamiento.
-- ============================================================================

BEGIN;
SET LOCAL client_min_messages TO warning;
SELECT setseed(0.271828);

-- Previene duplicacion al ejecutar dos veces y evita mezclar con operaciones
-- reales existentes. Se admiten los catalogos maestros preexistentes.
DO $control$
BEGIN
    IF EXISTS (SELECT 1 FROM venta)
       OR EXISTS (SELECT 1 FROM compra)
       OR EXISTS (SELECT 1 FROM instancia_de_produccion)
       OR EXISTS (SELECT 1 FROM movimiento_stock)
       OR EXISTS (SELECT 1 FROM ajuste_stock)
       OR EXISTS (SELECT 1 FROM cliente WHERE razon_social LIKE 'SIM Easa%') THEN
        RAISE EXCEPTION 'Seed cancelada: existen operaciones o clientes simulados. Ejecutar solo una vez en una OLTP nueva (sin transacciones).';
    END IF;
END
$control$;

-- 1. Catalogos iniciales (no importa si ya se ejecuto 02_catalogos_opcionales.sql).
INSERT INTO ciudad(nombre) VALUES ('Villa María'), ('Villa Nueva')
ON CONFLICT (nombre) DO NOTHING;
INSERT INTO sucursal(nombre,direccion,ciudad_id,tiene_planta)
SELECT d.nombre,d.direccion,c.id,d.tiene_planta
FROM (VALUES
 ('Villa María Centro','Bv. Sarmiento 1250','Villa María',TRUE),
 ('Villa María Norte','Av. Sabattini 850','Villa María',FALSE),
 ('Villa María Este','Av. Colón 420','Villa María',TRUE),
 ('Villa María Sur','Calle Mendoza 780','Villa María',FALSE),
 ('Villa Nueva Centro','Av. Carranza 610','Villa Nueva',TRUE),
 ('Villa Nueva Norte','Calle Córdoba 340','Villa Nueva',FALSE)
) AS d(nombre,direccion,ciudad,tiene_planta)
JOIN ciudad c ON c.nombre=d.ciudad
ON CONFLICT (nombre) DO NOTHING;
INSERT INTO tipo_cliente(nombre) VALUES
 ('Mostrador'),('Negocio'),('Escuela'),('Iglesia'),('Donación')
ON CONFLICT (nombre) DO NOTHING;
INSERT INTO estado(ambito,nombre) VALUES
 ('compra','Pendiente de pago'),('compra','Parcialmente pagada'),
 ('compra','Totalmente pagada'),('venta','Pendiente de cobro'),
 ('venta','Parcialmente cobrada'),('venta','Totalmente cobrada'),
 ('cheque','Entregado'),('cheque','Disponible'),('cheque','Rechazado')
ON CONFLICT (ambito,nombre) DO NOTHING;
INSERT INTO tipo_movimiento(nombre) VALUES
 ('Venta'),('Compra'),('Producción'),('Ajuste')
ON CONFLICT (nombre) DO NOTHING;
INSERT INTO medio_pago(nombre) VALUES
 ('Efectivo'),('Transferencia'),('Cuenta corriente'),('Cheque')
ON CONFLICT (nombre) DO NOTHING;

-- 2. Catalogos de productos, unidades, insumos y recetas FICTICIOS.
INSERT INTO unidad(nombre,descripcion,scope) VALUES
 ('Unidad','Unidad de producto','producto'),
 ('Kilogramo','Cantidad en kilogramos','producto'),
 ('Kilogramo','Cantidad en kilogramos','insumo'),
 ('Litro','Cantidad en litros','insumo'),
 ('Unidad','Unidad individual','insumo')
ON CONFLICT (nombre,scope) DO NOTHING;
INSERT INTO tipo_producto(nombre) VALUES
 ('Panes'),('Facturas'),('Salados'),('Pastelería'),('Sándwiches')
ON CONFLICT (nombre) DO NOTHING;
INSERT INTO producto(nombre,unidad_id,unidades_x_receta,cantidad_esperada_mes,
                     horas_mano_de_obra_x_receta,factor_complejidad,tipo_producto_id)
SELECT d.nombre, u.id, d.rendimiento, d.esperado, d.horas,d.complejidad,tp.id
FROM (VALUES
 ('Pan francés','Kilogramo',12.0,250,3.0,1.0,'Panes'),
 ('Pan miñón','Kilogramo',12.0,200,3.0,1.0,'Panes'),
 ('Pan integral','Kilogramo',10.0,120,3.5,1.5,'Panes'),
 ('Medialuna de manteca','Unidad',100.0,900,5.0,1.5,'Facturas'),
 ('Factura pastelera','Unidad',80.0,600,5.0,1.5,'Facturas'),
 ('Bizcochos salados','Kilogramo',8.0,130,3.0,1.0,'Salados'),
 ('Criollitos','Unidad',90.0,620,4.0,1.0,'Salados'),
 ('Prepizza','Unidad',30.0,350,3.0,1.0,'Salados'),
 ('Tarta dulce','Unidad',24.0,180,4.5,2.0,'Pastelería'),
 ('Budín de vainilla','Unidad',18.0,150,4.0,1.5,'Pastelería'),
 ('Galletitas','Kilogramo',10.0,130,3.5,1.0,'Pastelería'),
 ('Sándwiches de miga (docena)','Unidad',20.0,170,5.5,2.0,'Sándwiches')
) AS d(nombre,unidad,rendimiento,esperado,horas,complejidad,tipo)
JOIN unidad u ON u.nombre=d.unidad AND u.scope='producto'
JOIN tipo_producto tp ON tp.nombre=d.tipo
ON CONFLICT (nombre) DO NOTHING;

INSERT INTO insumo(nombre,unidad_id)
SELECT d.nombre, u.id FROM (VALUES
 ('Harina 000','Kilogramo'),('Harina integral','Kilogramo'),
 ('Azúcar','Kilogramo'),('Levadura','Kilogramo'),('Sal','Kilogramo'),
 ('Manteca','Kilogramo'),('Margarina','Kilogramo'),('Huevos','Unidad'),
 ('Leche','Litro'),('Aceite','Litro'),('Dulce de leche','Kilogramo'),
 ('Crema pastelera','Kilogramo'),('Polvo de hornear','Kilogramo'),
 ('Jamón','Kilogramo'),('Queso','Kilogramo'),('Tomate','Kilogramo')
) d(nombre,unidad)
JOIN unidad u ON u.nombre=d.unidad AND u.scope='insumo'
ON CONFLICT (nombre) DO NOTHING;

INSERT INTO item_receta(producto_id,insumo_id,cantidad)
SELECT p.id,i.id,d.cantidad
FROM (VALUES
 ('Pan francés','Harina 000',9.0),('Pan francés','Levadura',0.25),('Pan francés','Sal',0.18),
 ('Pan miñón','Harina 000',9.0),('Pan miñón','Levadura',0.26),('Pan miñón','Sal',0.18),
 ('Pan integral','Harina 000',3.0),('Pan integral','Harina integral',4.5),('Pan integral','Levadura',0.22),('Pan integral','Sal',0.15),
 ('Medialuna de manteca','Harina 000',5.0),('Medialuna de manteca','Manteca',2.0),('Medialuna de manteca','Azúcar',1.3),('Medialuna de manteca','Huevos',18.0),('Medialuna de manteca','Leche',1.5),
 ('Factura pastelera','Harina 000',5.0),('Factura pastelera','Margarina',1.5),('Factura pastelera','Azúcar',1.3),('Factura pastelera','Crema pastelera',2.0),('Factura pastelera','Huevos',12.0),
 ('Bizcochos salados','Harina 000',5.6),('Bizcochos salados','Margarina',1.5),('Bizcochos salados','Sal',0.11),
 ('Criollitos','Harina 000',5.4),('Criollitos','Margarina',1.2),('Criollitos','Sal',0.12),
 ('Prepizza','Harina 000',6.5),('Prepizza','Levadura',0.22),('Prepizza','Aceite',0.7),('Prepizza','Sal',0.12),
 ('Tarta dulce','Harina 000',4.5),('Tarta dulce','Azúcar',1.5),('Tarta dulce','Manteca',1.6),('Tarta dulce','Huevos',24.0),('Tarta dulce','Dulce de leche',1.8),
 ('Budín de vainilla','Harina 000',3.5),('Budín de vainilla','Azúcar',2.5),('Budín de vainilla','Huevos',22.0),('Budín de vainilla','Leche',1.6),('Budín de vainilla','Polvo de hornear',0.2),
 ('Galletitas','Harina 000',5.0),('Galletitas','Azúcar',2.0),('Galletitas','Manteca',2.0),('Galletitas','Huevos',12.0),
 ('Sándwiches de miga (docena)','Harina 000',4.0),('Sándwiches de miga (docena)','Jamón',2.0),('Sándwiches de miga (docena)','Queso',1.9),('Sándwiches de miga (docena)','Tomate',1.0)
) d(producto,insumo,cantidad)
JOIN producto p ON p.nombre=d.producto
JOIN insumo i ON i.nombre=d.insumo
ON CONFLICT (producto_id,insumo_id) DO NOTHING;

-- 3. Personal, usuarios ficticios, clientes y proveedores.
INSERT INTO area(nombre,descripcion) VALUES
 ('Producción y Venta','Actividad productiva y comercial'),
 ('Compras y Abastecimiento','Abastecimiento de sucursales'),
 ('Administración y Contabilidad','Gestión administrativa')
ON CONFLICT (nombre) DO NOTHING;
INSERT INTO rol_empleado(nombre,area_id)
SELECT d.nombre,a.id FROM (VALUES
 ('Panadero','Producción y Venta'),('Vendedor','Producción y Venta'),
 ('Encargado de sucursal','Producción y Venta'),
 ('Comprador','Compras y Abastecimiento'),
 ('Administrativo','Administración y Contabilidad')
) d(nombre,area) JOIN area a ON a.nombre=d.area
ON CONFLICT (nombre,area_id) DO NOTHING;
INSERT INTO empleado(nombre,apellido,salario_x_hora,rol_id,email)
SELECT 'SIM',d.apellido,d.salario,r.id,d.correo
FROM (VALUES
 ('Panadero 01',4200.00,'Panadero','sim_panadero_01@example.invalid'),
 ('Panadero 02',4300.00,'Panadero','sim_panadero_02@example.invalid'),
 ('Panadero 03',4400.00,'Panadero','sim_panadero_03@example.invalid'),
 ('Panadero 04',4100.00,'Panadero','sim_panadero_04@example.invalid'),
 ('Panadero 05',4500.00,'Panadero','sim_panadero_05@example.invalid'),
 ('Panadero 06',4350.00,'Panadero','sim_panadero_06@example.invalid'),
 ('Vendedor 01',3750.00,'Vendedor','sim_vendedor_01@example.invalid'),
 ('Vendedor 02',3700.00,'Vendedor','sim_vendedor_02@example.invalid'),
 ('Vendedor 03',3800.00,'Vendedor','sim_vendedor_03@example.invalid'),
 ('Comprador 01',4650.00,'Comprador','sim_comprador_01@example.invalid'),
 ('Administrativo 01',4750.00,'Administrativo','sim_administrativo_01@example.invalid')
) d(apellido,salario,rol,correo)
JOIN rol_empleado r ON r.nombre=d.rol;
INSERT INTO rol_usuario(nombre) VALUES ('Administrador'),('Operador')
ON CONFLICT (nombre) DO NOTHING;
-- Usuarios inutilizables para autenticacion; contrasena_hash es un marcador.
INSERT INTO usuario(nombre,email,contrasena_hash,rol_id)
SELECT d.nombre,d.email,'!CUENTA_DEMO_BLOQUEADA_SIN_PASSWORD!',r.id
FROM (VALUES
 ('sim_admin','sim_admin@example.invalid','Administrador'),
 ('sim_stock','sim_stock@example.invalid','Operador')
) d(nombre,email,rol)
JOIN rol_usuario r ON r.nombre=d.rol
ON CONFLICT (nombre) DO NOTHING;

INSERT INTO cliente(razon_social,email,tipo_cliente_id)
SELECT format('SIM Easa %s %s',tc.nombre,lpad(n::text,3,'0')),
       format('sim_easa_cliente_%s_%s@example.invalid',tc.id,n),tc.id
FROM tipo_cliente tc
CROSS JOIN LATERAL generate_series(1,CASE tc.nombre
 WHEN 'Mostrador' THEN 50 WHEN 'Negocio' THEN 20 WHEN 'Escuela' THEN 12
 WHEN 'Iglesia' THEN 7 WHEN 'Donación' THEN 5 ELSE 0 END) AS n
WHERE tc.nombre IN ('Mostrador','Negocio','Escuela','Iglesia','Donación');
INSERT INTO proveedor(razon_social,email)
SELECT d.nombre,format('sim_easa_proveedor_%s@example.invalid',d.n)
FROM (VALUES
 (1,'SIM Molinos del Centro'),(2,'SIM Distribuidora Láctea'),
 (3,'SIM Avícola Regional'),(4,'SIM Mayorista Panadero'),
 (5,'SIM Ingredientes Dulces'),(6,'SIM Verduras del Valle'),
 (7,'SIM Fiambres y Quesos'),(8,'SIM Abastecimiento Integral')
) d(n,nombre);

-- 4. Historicos de precios. Pesos ficticios NO equivalentes a precios reales.
WITH periodos(fecha_desde,factor) AS (
 VALUES (DATE '2023-01-01',1.00::numeric),
        (DATE '2024-01-01',2.10::numeric),
        (DATE '2025-01-01',3.90::numeric),
        (DATE '2026-01-01',5.40::numeric),
        (DATE '2026-07-01',6.40::numeric)
), productos AS (
 SELECT p.id,CASE p.nombre
 WHEN 'Pan francés' THEN 400 WHEN 'Pan miñón' THEN 420
 WHEN 'Pan integral' THEN 600 WHEN 'Medialuna de manteca' THEN 100
 WHEN 'Factura pastelera' THEN 130 WHEN 'Bizcochos salados' THEN 900
 WHEN 'Criollitos' THEN 90 WHEN 'Prepizza' THEN 240
 WHEN 'Tarta dulce' THEN 1100 WHEN 'Budín de vainilla' THEN 850
 WHEN 'Galletitas' THEN 880 WHEN 'Sándwiches de miga (docena)' THEN 1900
 END::numeric AS base
 FROM producto p
 WHERE p.nombre IN ('Pan francés','Pan miñón','Pan integral','Medialuna de manteca',
  'Factura pastelera','Bizcochos salados','Criollitos','Prepizza',
  'Tarta dulce','Budín de vainilla','Galletitas','Sándwiches de miga (docena)')
)
INSERT INTO precio_producto(producto_id,tipo_cliente_id,precio,fecha_desde,fecha_hasta)
SELECT p.id,tc.id,round(p.base*pd.factor * (CASE tc.nombre
 WHEN 'Mostrador' THEN 1.00 WHEN 'Negocio' THEN 0.88
 WHEN 'Escuela' THEN 0.82 WHEN 'Iglesia' THEN 0.85
 WHEN 'Donación' THEN 0.00 END)::numeric,4),
 pd.fecha_desde,
 CASE WHEN pd.fecha_desde = DATE '2026-07-01' THEN NULL
      ELSE (pd.fecha_desde + CASE WHEN pd.fecha_desde=DATE '2026-01-01'
                  THEN INTERVAL '6 months' ELSE INTERVAL '1 year' END
                  - INTERVAL '1 day')::date END
FROM productos p CROSS JOIN tipo_cliente tc CROSS JOIN periodos pd
WHERE tc.nombre IN ('Mostrador','Negocio','Escuela','Iglesia','Donación')
ON CONFLICT (producto_id,tipo_cliente_id,fecha_desde) DO NOTHING;

WITH periodos(fecha_desde,factor) AS (
 VALUES (DATE '2023-01-01',1.00::numeric),
        (DATE '2024-01-01',2.30::numeric),
        (DATE '2025-01-01',4.00::numeric),
        (DATE '2026-01-01',5.60::numeric),
        (DATE '2026-07-01',6.50::numeric)
)
INSERT INTO precio_insumo(insumo_id,proveedor_id,precio,fecha_desde,fecha_hasta)
SELECT i.id,p.id,
 round((CASE i.nombre
  WHEN 'Harina 000' THEN 300 WHEN 'Harina integral' THEN 420
  WHEN 'Azúcar' THEN 400 WHEN 'Levadura' THEN 1500 WHEN 'Sal' THEN 130
  WHEN 'Manteca' THEN 900 WHEN 'Margarina' THEN 680 WHEN 'Huevos' THEN 65
  WHEN 'Leche' THEN 300 WHEN 'Aceite' THEN 500
  WHEN 'Dulce de leche' THEN 800 WHEN 'Crema pastelera' THEN 760
  WHEN 'Polvo de hornear' THEN 1200 WHEN 'Jamón' THEN 1800
  WHEN 'Queso' THEN 1500 WHEN 'Tomate' THEN 450 END
 )::numeric * pd.factor * (0.94 + ((p.id % 5)::numeric / 50)),4),
 pd.fecha_desde,
 CASE WHEN pd.fecha_desde = DATE '2026-07-01' THEN NULL
      ELSE (pd.fecha_desde + CASE WHEN pd.fecha_desde=DATE '2026-01-01'
                       THEN INTERVAL '6 months' ELSE INTERVAL '1 year' END
             - INTERVAL '1 day')::date END
FROM insumo i CROSS JOIN proveedor p CROSS JOIN periodos pd
WHERE p.razon_social LIKE 'SIM %'
  AND i.nombre IN ('Harina 000','Harina integral','Azúcar','Levadura','Sal',
    'Manteca','Margarina','Huevos','Leche','Aceite','Dulce de leche',
    'Crema pastelera','Polvo de hornear','Jamón','Queso','Tomate')
ON CONFLICT (insumo_id,proveedor_id,fecha_desde) DO NOTHING;

-- 5. Promociones trimestrales: vigencia, productos y segmentos compatibles.
INSERT INTO tipo_promocion(nombre) VALUES ('Descuento porcentual')
ON CONFLICT (nombre) DO NOTHING;
DO $promociones$
DECLARE
 v_y int; v_q int; v_ini date; v_fin date; v_prom BIGINT;
BEGIN
 FOR v_y IN 2023..2026 LOOP
  FOR v_q IN 1..4 LOOP
   v_ini := make_date(v_y,1+(v_q-1)*3,1);
   v_fin := (v_ini + INTERVAL '2 months' - INTERVAL '1 day')::date;
   INSERT INTO promocion(nombre,fecha_desde,fecha_hasta,valor,tipo_promocion_id)
   SELECT format('SIM Easa %s T%s',v_y,v_q),v_ini,v_fin,
          (10 + ((v_y+v_q)%3)*5)::numeric,tp.id
   FROM tipo_promocion tp WHERE tp.nombre='Descuento porcentual'
   RETURNING id INTO v_prom;
   INSERT INTO promocion_tipo_cliente(promocion_id,tipo_cliente_id)
   SELECT v_prom,id FROM tipo_cliente
   WHERE nombre IN ('Mostrador','Negocio','Escuela','Iglesia')
   ON CONFLICT (promocion_id,tipo_cliente_id) DO NOTHING;
   INSERT INTO promocion_producto(promocion_id,producto_id)
   SELECT v_prom,t.id
   FROM (SELECT p.id,row_number() OVER (ORDER BY p.nombre) AS rn
         FROM producto p WHERE p.nombre IN
          ('Pan francés','Pan miñón','Pan integral','Medialuna de manteca',
           'Factura pastelera','Bizcochos salados','Criollitos','Prepizza',
           'Tarta dulce','Budín de vainilla','Galletitas','Sándwiches de miga (docena)')) t
   WHERE ((t.rn + v_y + v_q) % 3)=0
   ON CONFLICT (promocion_id,producto_id) DO NOTHING;
  END LOOP;
 END LOOP;
END
$promociones$;

-- 6. Stock por sucursal: productos en las seis; insumos solo en plantas.
INSERT INTO producto_sucursal(producto_id,sucursal_id,stock_actual,stock_minimo,activo)
SELECT p.id,s.id,0,CASE WHEN u.nombre='Kilogramo' THEN 15 ELSE 35 END,TRUE
FROM producto p JOIN unidad u ON u.id=p.unidad_id
CROSS JOIN sucursal s
WHERE p.nombre IN ('Pan francés','Pan miñón','Pan integral','Medialuna de manteca',
 'Factura pastelera','Bizcochos salados','Criollitos','Prepizza',
 'Tarta dulce','Budín de vainilla','Galletitas','Sándwiches de miga (docena)')
ON CONFLICT (producto_id,sucursal_id) DO NOTHING;
INSERT INTO insumo_sucursal(insumo_id,sucursal_id,stock_actual,stock_minimo)
SELECT i.id,s.id,0,CASE WHEN i.nombre IN ('Harina 000','Azúcar','Manteca') THEN 50 ELSE 10 END
FROM insumo i CROSS JOIN sucursal s
WHERE s.tiene_planta=TRUE
ON CONFLICT (insumo_id,sucursal_id) DO NOTHING;

-- Tablas temporales solo auxiliares de generacion (desaparecen al COMMIT).
CREATE TEMP TABLE sim_reparto_temporal (
 instancia_id BIGINT NOT NULL,
 reparto_id BIGINT NOT NULL,
 destino_id BIGINT NOT NULL,
 orden SMALLINT NOT NULL,
 PRIMARY KEY (instancia_id,orden)
) ON COMMIT DROP;

-- 7. COMPRAS + DETALLES + MOVIMIENTOS + PAGOS (46 meses).
DO $compras$
DECLARE
 v_mes timestamp;
 v_fecha timestamp;
 v_fecha_pago timestamp;
 v_sucursal_id bigint;
 v_proveedor_id bigint;
 v_compra_id bigint;
 v_pago_id bigint;
 v_cheque_id bigint;
 v_estado_id bigint;
 v_medio_id bigint;
 v_insumo record;
 v_i integer; v_n integer;
 v_precio numeric(14,4);
 v_cant numeric(16,3);
 v_total numeric(16,2);
 v_pagado numeric(16,2);
 v_estado text; v_medio text;
 v_aleatorio double precision;
BEGIN
 FOR v_mes IN
  SELECT gs::timestamp FROM generate_series(DATE '2023-01-01',
                         DATE '2026-10-01',INTERVAL '1 month') gs
 LOOP
  FOR v_i IN 1..12 LOOP
   v_fecha := v_mes + make_interval(days=>floor(random()*28)::int,
                                     hours=>8+floor(random()*8)::int,
                                     mins=>floor(random()*60)::int);
   SELECT s.id INTO v_sucursal_id FROM sucursal s
   WHERE s.tiene_planta=TRUE ORDER BY random() LIMIT 1;
   SELECT p.id INTO v_proveedor_id FROM proveedor p
   WHERE p.razon_social LIKE 'SIM %' ORDER BY random() LIMIT 1;

   v_aleatorio := random();
   IF v_mes < TIMESTAMP '2025-01-01' THEN
    v_estado := CASE WHEN v_aleatorio < 0.82 THEN 'Totalmente pagada'
                     WHEN v_aleatorio < 0.94 THEN 'Parcialmente pagada'
                     ELSE 'Pendiente de pago' END;
   ELSE
    v_estado := CASE WHEN v_aleatorio < 0.60 THEN 'Totalmente pagada'
                     WHEN v_aleatorio < 0.84 THEN 'Parcialmente pagada'
                     ELSE 'Pendiente de pago' END;
   END IF;
   SELECT e.id INTO v_estado_id FROM estado e
   WHERE e.ambito='compra' AND e.nombre=v_estado;
   INSERT INTO compra(fecha_hora,estado_id,proveedor_id)
   VALUES(v_fecha,v_estado_id,v_proveedor_id) RETURNING id INTO v_compra_id;

   v_total := 0;
   v_n := 2+floor(random()*3)::int;
   FOR v_insumo IN
    SELECT i_s.id AS insumo_sucursal_id,i_s.insumo_id
    FROM insumo_sucursal i_s JOIN insumo i ON i.id=i_s.insumo_id
    WHERE i_s.sucursal_id=v_sucursal_id
      AND i.nombre IN ('Harina 000','Harina integral','Azúcar','Levadura','Sal',
       'Manteca','Margarina','Huevos','Leche','Aceite','Dulce de leche',
       'Crema pastelera','Polvo de hornear','Jamón','Queso','Tomate')
    ORDER BY random() LIMIT v_n
   LOOP
    SELECT pi.precio INTO STRICT v_precio FROM precio_insumo pi
    WHERE pi.insumo_id=v_insumo.insumo_id
      AND pi.proveedor_id=v_proveedor_id
      AND pi.fecha_desde<=v_fecha::date
      AND (pi.fecha_hasta IS NULL OR pi.fecha_hasta>=v_fecha::date)
    ORDER BY pi.fecha_desde DESC LIMIT 1;
    v_cant := (10+floor(random()*90))::numeric;
    INSERT INTO detalle_compra(insumo_sucursal_id,cantidad,
       precio_unitario_historico,compra_id)
    VALUES(v_insumo.insumo_sucursal_id,v_cant,v_precio,v_compra_id);
    v_total := v_total+round(v_cant*v_precio,2);
    INSERT INTO movimiento_stock(cantidad,fecha_hora,tipo_id,insumo_sucursal_id)
    SELECT v_cant,v_fecha,tm.id,v_insumo.insumo_sucursal_id
    FROM tipo_movimiento tm WHERE tm.nombre='Compra';
   END LOOP;

   IF v_estado <> 'Pendiente de pago' THEN
    IF v_estado = 'Totalmente pagada' THEN
     v_pagado := v_total;
    ELSE
     v_pagado := round(v_total*((0.30+random()*0.50)::numeric),2);
    END IF;
    v_fecha_pago := least(TIMESTAMP '2026-11-15 20:00:00',
                    v_fecha+make_interval(days=>floor(random()*19)::int));
    v_aleatorio := random();
    v_medio := CASE WHEN v_aleatorio < 0.52 THEN 'Transferencia'
                    WHEN v_aleatorio < 0.85 THEN 'Efectivo'
                    ELSE 'Cheque' END;
    SELECT mp.id INTO v_medio_id FROM medio_pago mp WHERE mp.nombre=v_medio;
    v_cheque_id := NULL;
    IF v_medio='Cheque' THEN
      INSERT INTO cheque(titular,cuil,monto,fecha_emision,fecha_cobro,estado_id)
      SELECT 'SIM Easa - Emisor de pago',NULL,v_pagado,v_fecha_pago::date,NULL,e.id
      FROM estado e WHERE e.ambito='cheque' AND e.nombre='Entregado'
      RETURNING id INTO v_cheque_id;
    END IF;
    INSERT INTO pago(fecha_hora,medio_id,cheque_id,proveedor_id)
    VALUES(v_fecha_pago,v_medio_id,v_cheque_id,v_proveedor_id)
    RETURNING id INTO v_pago_id;
    INSERT INTO detalle_pago(monto,compra_id,pago_id)
    VALUES(v_pagado,v_compra_id,v_pago_id);
   END IF;
  END LOOP;
 END LOOP;
END
$compras$;

-- 8. VENTAS (25 por mes/sucursal) + DETALLES + PROMOCIONES + COBROS.
DO $ventas$
DECLARE
 v_mes timestamp;
 v_fecha timestamp;
 v_fecha_cobro timestamp;
 v_sucursal record;
 v_producto record;
 v_i integer; v_n integer;
 v_cliente_id bigint; v_tipo_cliente_id bigint;
 v_venta_id bigint; v_estado_id bigint;
 v_cobro_id bigint; v_medio_id bigint; v_cheque_id bigint;
 v_promo_id bigint;
 v_cantidad numeric(16,3);
 v_precio numeric(14,4);
 v_precio_final numeric(14,4);
 v_descuento numeric(14,2);
 v_total numeric(16,2);
 v_cobrado numeric(16,2);
 v_tipo text; v_estado text; v_medio text;
 v_aleatorio double precision;
BEGIN
 FOR v_mes IN
  SELECT gs::timestamp FROM generate_series(DATE '2023-01-01',
                         DATE '2026-10-01',INTERVAL '1 month') gs
 LOOP
  FOR v_sucursal IN SELECT s.id FROM sucursal s LOOP
   FOR v_i IN 1..25 LOOP
    v_fecha := v_mes + make_interval(days=>floor(random()*28)::int,
                            hours=>7+floor(random()*14)::int,
                            mins=>floor(random()*60)::int);
    v_aleatorio := random();
    v_tipo := CASE WHEN v_aleatorio < 0.58 THEN 'Mostrador'
                   WHEN v_aleatorio < 0.81 THEN 'Negocio'
                   WHEN v_aleatorio < 0.93 THEN 'Escuela'
                   WHEN v_aleatorio < 0.98 THEN 'Iglesia'
                   ELSE 'Donación' END;
    SELECT c.id,c.tipo_cliente_id INTO STRICT v_cliente_id,v_tipo_cliente_id
    FROM cliente c JOIN tipo_cliente tc ON tc.id=c.tipo_cliente_id
    WHERE c.razon_social LIKE 'SIM Easa %' AND tc.nombre=v_tipo
    ORDER BY random() LIMIT 1;

    v_aleatorio := random();
    IF v_tipo='Donación' THEN
      v_estado:='Totalmente cobrada'; -- importe cero, sin cobro.
    ELSE
      v_estado := CASE WHEN v_aleatorio < 0.77 THEN 'Totalmente cobrada'
                       WHEN v_aleatorio < 0.91 THEN 'Parcialmente cobrada'
                       ELSE 'Pendiente de cobro' END;
    END IF;
    SELECT e.id INTO v_estado_id FROM estado e
    WHERE e.ambito='venta' AND e.nombre=v_estado;
    INSERT INTO venta(fecha_hora,estado_id,cliente_id)
    VALUES(v_fecha,v_estado_id,v_cliente_id)
    RETURNING id INTO v_venta_id;

    v_total := 0;
    v_n := 1+floor(random()*4)::int;
    FOR v_producto IN
     SELECT ps.id AS producto_sucursal_id,ps.producto_id,u.nombre AS unidad
     FROM producto_sucursal ps JOIN producto p ON p.id=ps.producto_id
     JOIN unidad u ON u.id=p.unidad_id
     WHERE ps.sucursal_id=v_sucursal.id
      AND p.nombre IN ('Pan francés','Pan miñón','Pan integral','Medialuna de manteca',
       'Factura pastelera','Bizcochos salados','Criollitos','Prepizza',
       'Tarta dulce','Budín de vainilla','Galletitas','Sándwiches de miga (docena)')
     ORDER BY random() LIMIT v_n
    LOOP
     IF v_producto.unidad='Kilogramo' THEN
       v_cantidad := round((0.5+random()*5)::numeric,3);
     ELSE
       v_cantidad := (1+floor(random()*12))::numeric;
     END IF;
     SELECT pp.precio INTO STRICT v_precio FROM precio_producto pp
     WHERE pp.producto_id=v_producto.producto_id
       AND pp.tipo_cliente_id=v_tipo_cliente_id
       AND pp.fecha_desde<=v_fecha::date
       AND (pp.fecha_hasta IS NULL OR pp.fecha_hasta>=v_fecha::date)
     ORDER BY pp.fecha_desde DESC LIMIT 1;

     v_promo_id:=NULL;
     v_descuento:=0;
     IF random()<0.38 AND v_tipo<>'Donación' THEN
       SELECT prom.id,prom.valor INTO v_promo_id,v_descuento
       FROM promocion prom
       JOIN promocion_producto prp ON prp.promocion_id=prom.id
       JOIN promocion_tipo_cliente ptc ON ptc.promocion_id=prom.id
       WHERE prom.nombre LIKE 'SIM Easa %'
         AND v_fecha::date BETWEEN prom.fecha_desde AND prom.fecha_hasta
         AND prp.producto_id=v_producto.producto_id
         AND ptc.tipo_cliente_id=v_tipo_cliente_id
       ORDER BY random() LIMIT 1;
       -- Si no hubo promocion valida, conservar el precio normal.
       IF v_promo_id IS NULL THEN v_descuento:=0; END IF;
     END IF;
     v_precio_final:=round(v_precio*(1-v_descuento/100),4);
     INSERT INTO detalle_venta(producto_sucursal_id,cantidad,
              precio_unitario_historico,venta_id,promocion_id)
     VALUES(v_producto.producto_sucursal_id,v_cantidad,
            v_precio_final,v_venta_id,v_promo_id);
     v_total := v_total+round(v_cantidad*v_precio_final,2);
     INSERT INTO movimiento_stock(cantidad,fecha_hora,tipo_id,producto_sucursal_id)
     SELECT -v_cantidad,v_fecha,tm.id,v_producto.producto_sucursal_id
     FROM tipo_movimiento tm WHERE tm.nombre='Venta';
    END LOOP;

    IF v_total>0 AND v_estado<>'Pendiente de cobro' THEN
     IF v_estado='Totalmente cobrada' THEN v_cobrado:=v_total;
     ELSE v_cobrado:=round(v_total*((0.28+random()*0.61)::numeric),2);
     END IF;
     v_fecha_cobro := least(TIMESTAMP '2026-11-15 20:00:00',
                           v_fecha+make_interval(days=>floor(random()*10)::int));
     v_aleatorio:=random();
     v_medio := CASE WHEN v_aleatorio < 0.63 THEN 'Efectivo'
                     WHEN v_aleatorio < 0.93 THEN 'Transferencia'
                     ELSE 'Cheque' END;
     SELECT mp.id INTO v_medio_id FROM medio_pago mp WHERE mp.nombre=v_medio;
     v_cheque_id:=NULL;
     IF v_medio='Cheque' THEN
      INSERT INTO cheque(titular,cuil,monto,fecha_emision,fecha_cobro,estado_id)
      SELECT 'SIM Easa - Cliente',NULL,v_cobrado,v_fecha_cobro::date,
             v_fecha_cobro::date,e.id
      FROM estado e WHERE e.ambito='cheque' AND e.nombre='Disponible'
      RETURNING id INTO v_cheque_id;
     END IF;
     INSERT INTO cobro(fecha_hora,medio_id,cheque_id,cliente_id)
     VALUES(v_fecha_cobro,v_medio_id,v_cheque_id,v_cliente_id)
     RETURNING id INTO v_cobro_id;
     INSERT INTO detalle_cobro(monto,venta_id,cobro_id)
     VALUES(v_cobrado,v_venta_id,v_cobro_id);
    END IF;
   END LOOP;
  END LOOP;
 END LOOP;
END
$ventas$;

-- 9. PRODUCCIONES EN LAS 3 PLANTAS y repartos a 3 sucursales.
-- El total repartido de cada detalle es exactamente lo producido.
DO $produccion$
DECLARE
 v_mes timestamp;
 v_fecha timestamp;
 v_planta record;
 v_destino record;
 v_producto record;
 v_insumo record;
 v_asignacion record;
 v_i integer; v_n integer; v_orden integer;
 v_empleado_id bigint;
 v_instancia_id bigint; v_detalle_id bigint; v_reparto_id bigint;
 v_producto_sucursal_id bigint; v_insumo_sucursal_id bigint;
 v_cantidad numeric(16,3); v_consumo numeric(16,3);
 v_parte1 numeric(16,3); v_parte2 numeric(16,3); v_parte3 numeric(16,3);
BEGIN
 FOR v_mes IN
  SELECT gs::timestamp FROM generate_series(DATE '2023-01-01',
                         DATE '2026-10-01',INTERVAL '1 month') gs
 LOOP
  FOR v_planta IN SELECT s.id FROM sucursal s WHERE s.tiene_planta=TRUE LOOP
   FOR v_i IN 1..5 LOOP
    v_fecha:=v_mes + make_interval(days=>floor(random()*27)::int,
                          hours=>5+floor(random()*8)::int,
                          mins=>floor(random()*60)::int);
    SELECT e.id INTO STRICT v_empleado_id
    FROM empleado e JOIN rol_empleado r ON r.id=e.rol_id
    WHERE r.nombre='Panadero' AND e.email LIKE 'sim_panadero_%@example.invalid'
    ORDER BY random() LIMIT 1;
    INSERT INTO instancia_de_produccion(fecha_hora,empleado_id,sucursal_id)
    VALUES(v_fecha,v_empleado_id,v_planta.id)
    RETURNING id INTO v_instancia_id;

    -- Un reparto por destino y por instancia; varios productos en cada reparto.
    v_orden:=0;
    FOR v_destino IN
      SELECT s.id FROM sucursal s
      ORDER BY (s.id<>v_planta.id),random() LIMIT 3
    LOOP
      v_orden:=v_orden+1;
      INSERT INTO reparto(fecha_hora,instancia_produccion_id,sucursal_id)
      VALUES(v_fecha+make_interval(hours=>v_orden+2),v_instancia_id,v_destino.id)
      RETURNING id INTO v_reparto_id;
      INSERT INTO sim_reparto_temporal(instancia_id,reparto_id,destino_id,orden)
      VALUES(v_instancia_id,v_reparto_id,v_destino.id,v_orden);
    END LOOP;

    v_n:=2+floor(random()*2)::int;
    FOR v_producto IN
     SELECT p.id,p.unidades_x_receta,u.nombre AS unidad
     FROM producto p JOIN unidad u ON u.id=p.unidad_id
     WHERE p.nombre IN ('Pan francés','Pan miñón','Pan integral','Medialuna de manteca',
      'Factura pastelera','Bizcochos salados','Criollitos','Prepizza',
      'Tarta dulce','Budín de vainilla','Galletitas','Sándwiches de miga (docena)')
     ORDER BY random() LIMIT v_n
    LOOP
     IF v_producto.unidad='Kilogramo' THEN
       v_cantidad:=(30+floor(random()*61))::numeric;
     ELSE
       v_cantidad:=(90+floor(random()*141))::numeric;
     END IF;
     INSERT INTO detalle_instancia_de_produccion(producto_id,cantidad,
                                                    instancia_produccion_id)
     VALUES(v_producto.id,v_cantidad,v_instancia_id)
     RETURNING id INTO v_detalle_id;

     -- Consumo teorico de insumos, basado en la receta ya cargada.
     FOR v_insumo IN SELECT ir.insumo_id,ir.cantidad AS cantidad_receta
                     FROM item_receta ir WHERE ir.producto_id=v_producto.id
     LOOP
       SELECT isu.id INTO STRICT v_insumo_sucursal_id
       FROM insumo_sucursal isu
       WHERE isu.insumo_id=v_insumo.insumo_id
         AND isu.sucursal_id=v_planta.id;
       v_consumo:=greatest(0.001::numeric,
                    round(v_insumo.cantidad_receta*v_cantidad /
                                      v_producto.unidades_x_receta,3));
       INSERT INTO movimiento_stock(cantidad,fecha_hora,tipo_id,insumo_sucursal_id)
       SELECT -v_consumo,v_fecha,tm.id,v_insumo_sucursal_id
       FROM tipo_movimiento tm WHERE tm.nombre='Producción';
     END LOOP;

     -- Se distribuye 50-60% / 20-32% / resto, sin perder unidades.
     v_parte1:=round(v_cantidad*((0.50+random()*0.10)::numeric),3);
     v_parte2:=round(v_cantidad*((0.20+random()*0.12)::numeric),3);
     v_parte3:=v_cantidad-v_parte1-v_parte2;
     FOR v_asignacion IN
      SELECT t.reparto_id,t.destino_id,t.orden,r.fecha_hora
      FROM sim_reparto_temporal t JOIN reparto r ON r.id=t.reparto_id
      WHERE t.instancia_id=v_instancia_id ORDER BY t.orden
     LOOP
       SELECT ps.id INTO STRICT v_producto_sucursal_id
       FROM producto_sucursal ps
       WHERE ps.producto_id=v_producto.id
         AND ps.sucursal_id=v_asignacion.destino_id;
       INSERT INTO detalle_reparto(cantidad,reparto_id,
                                  detalle_instancia_produccion_id)
       VALUES(CASE v_asignacion.orden WHEN 1 THEN v_parte1
                                     WHEN 2 THEN v_parte2 ELSE v_parte3 END,
              v_asignacion.reparto_id,v_detalle_id);
       INSERT INTO movimiento_stock(cantidad,fecha_hora,tipo_id,producto_sucursal_id)
       SELECT CASE v_asignacion.orden WHEN 1 THEN v_parte1
                                     WHEN 2 THEN v_parte2 ELSE v_parte3 END,
              v_asignacion.fecha_hora,tm.id,v_producto_sucursal_id
       FROM tipo_movimiento tm WHERE tm.nombre='Producción';
     END LOOP;
    END LOOP;
   END LOOP;
  END LOOP;
 END LOOP;
END
$produccion$;

-- 10. AJUSTES de insumos (solo plantas) y productos (seis sucursales).
DO $ajustes$
DECLARE
 v_mes timestamp;
 v_sucursal record;
 v_ubicacion_id bigint;
 v_usuario_id bigint;
 v_fecha timestamp;
 v_delta numeric(16,3);
 v_i integer;
BEGIN
 SELECT id INTO STRICT v_usuario_id FROM usuario WHERE nombre='sim_stock';
 FOR v_mes IN
  SELECT gs::timestamp FROM generate_series(DATE '2023-01-01',
                         DATE '2026-10-01',INTERVAL '1 month') gs
 LOOP
  FOR v_sucursal IN SELECT s.id,s.tiene_planta FROM sucursal s LOOP
    v_fecha:=v_mes+make_interval(days=>1+floor(random()*27)::int,hours=>17);
    SELECT ps.id INTO STRICT v_ubicacion_id FROM producto_sucursal ps
    WHERE ps.sucursal_id=v_sucursal.id ORDER BY random() LIMIT 1;
    v_delta:=CASE WHEN random()<0.65 THEN -1 ELSE 1 END
                 *(1+floor(random()*7))::numeric;
    INSERT INTO ajuste_stock(cantidad,fecha_hora,motivo,producto_sucursal_id,usuario_id)
    VALUES(v_delta,v_fecha,'Conteo físico: diferencia simulada de producto',
           v_ubicacion_id,v_usuario_id);
    INSERT INTO movimiento_stock(cantidad,fecha_hora,tipo_id,producto_sucursal_id)
    SELECT v_delta,v_fecha,tm.id,v_ubicacion_id
    FROM tipo_movimiento tm WHERE tm.nombre='Ajuste';

    IF v_sucursal.tiene_planta THEN
      FOR v_i IN 1..3 LOOP
       v_fecha:=v_mes+make_interval(days=>1+floor(random()*27)::int,
                           hours=>17,mins=>floor(random()*60)::int);
       SELECT isu.id INTO STRICT v_ubicacion_id FROM insumo_sucursal isu
       WHERE isu.sucursal_id=v_sucursal.id ORDER BY random() LIMIT 1;
       v_delta:=CASE WHEN random()<0.67 THEN -1 ELSE 1 END
                    *round((0.4+random()*4)::numeric,3);
       INSERT INTO ajuste_stock(cantidad,fecha_hora,motivo,insumo_sucursal_id,usuario_id)
       VALUES(v_delta,v_fecha,'Conteo físico: diferencia simulada de insumo',
              v_ubicacion_id,v_usuario_id);
       INSERT INTO movimiento_stock(cantidad,fecha_hora,tipo_id,insumo_sucursal_id)
       SELECT v_delta,v_fecha,tm.id,v_ubicacion_id
       FROM tipo_movimiento tm WHERE tm.nombre='Ajuste';
      END LOOP;
    END IF;
  END LOOP;
 END LOOP;
END
$ajustes$;

-- 11. COSTOS INDIRECTOS MENSUALES (CIF): datos de demostracion.
INSERT INTO tipo_cif(nombre) VALUES ('Electricidad'),('Gas'),('Agua')
ON CONFLICT (nombre) DO NOTHING;
INSERT INTO cif(tipo_cif_id,fecha_hora,monto)
SELECT tc.id,gs::timestamp+INTERVAL '27 days',
       round((CASE tc.nombre WHEN 'Electricidad' THEN 32000
                            WHEN 'Gas' THEN 19000 ELSE 11500 END)::numeric
             * CASE WHEN gs::date<DATE '2024-01-01' THEN 1.0
                    WHEN gs::date<DATE '2025-01-01' THEN 2.1
                    WHEN gs::date<DATE '2026-01-01' THEN 3.9
                    ELSE 5.3 END
             * (0.9+random()*0.2)::numeric,2)
FROM tipo_cif tc CROSS JOIN generate_series(DATE '2023-01-01',
                   DATE '2026-10-01',INTERVAL '1 month') gs
WHERE tc.nombre IN ('Electricidad','Gas','Agua');

-- 12. INVENTARIO DE APERTURA CALCULADO para no obtener saldos negativos.
-- Se calcula el peor saldo acumulado de movimientos por item y se registra
-- una apertura previa al periodo. NO se inserta en ajuste_stock (por lo que
-- NO contamina el cubo de ajustes de la consulta 5).
CREATE TEMP TABLE sim_apertura_producto ON COMMIT DROP AS
SELECT ps.id AS ubicacion_id,
       greatest(0::numeric,-coalesce(min(x.saldo),0::numeric))
                         + ps.stock_minimo*2 + 10 AS apertura
FROM producto_sucursal ps
LEFT JOIN LATERAL (
 SELECT sum(m.cantidad) OVER (ORDER BY m.fecha_hora,m.id
                 ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS saldo
 FROM movimiento_stock m WHERE m.producto_sucursal_id=ps.id
) x ON TRUE
GROUP BY ps.id,ps.stock_minimo;

CREATE TEMP TABLE sim_apertura_insumo ON COMMIT DROP AS
SELECT isu.id AS ubicacion_id,
       greatest(0::numeric,-coalesce(min(x.saldo),0::numeric))
                         + isu.stock_minimo*2 + 10 AS apertura
FROM insumo_sucursal isu
LEFT JOIN LATERAL (
 SELECT sum(m.cantidad) OVER (ORDER BY m.fecha_hora,m.id
                 ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS saldo
 FROM movimiento_stock m WHERE m.insumo_sucursal_id=isu.id
) x ON TRUE
GROUP BY isu.id,isu.stock_minimo;

INSERT INTO movimiento_stock(cantidad,fecha_hora,tipo_id,producto_sucursal_id)
SELECT ap.apertura,TIMESTAMP '2022-12-31 08:00:00',tm.id,ap.ubicacion_id
FROM sim_apertura_producto ap CROSS JOIN tipo_movimiento tm
WHERE tm.nombre='Ajuste' AND ap.apertura>0;
INSERT INTO movimiento_stock(cantidad,fecha_hora,tipo_id,insumo_sucursal_id)
SELECT ai.apertura,TIMESTAMP '2022-12-31 08:00:00',tm.id,ai.ubicacion_id
FROM sim_apertura_insumo ai CROSS JOIN tipo_movimiento tm
WHERE tm.nombre='Ajuste' AND ai.apertura>0;

-- La foto de inventario final queda igual a la suma de movimientos historicos.
UPDATE producto_sucursal ps SET stock_actual = coalesce((
 SELECT sum(m.cantidad) FROM movimiento_stock m
 WHERE m.producto_sucursal_id=ps.id),0);
UPDATE insumo_sucursal isu SET stock_actual = coalesce((
 SELECT sum(m.cantidad) FROM movimiento_stock m
 WHERE m.insumo_sucursal_id=isu.id),0);

-- 13. AUDITORIA simulada de cada ajuste registrado.
INSERT INTO auditoria(fecha_hora,accion,entidad,id_entidad,usuario_id)
SELECT a.fecha_hora,'INSERT','ajuste_stock',a.id,a.usuario_id
FROM ajuste_stock a;

-- 14. VALIDACIONES: lanzar error y ROLLBACK si un invariante no se cumple.
DO $verificaciones$
DECLARE
 v_meses integer;
BEGIN
 IF EXISTS (SELECT 1 FROM producto_sucursal WHERE stock_actual<0)
    OR EXISTS (SELECT 1 FROM insumo_sucursal WHERE stock_actual<0) THEN
   RAISE EXCEPTION 'Inventario final negativo.';
 END IF;
 IF EXISTS (
  SELECT 1 FROM detalle_instancia_de_produccion dip
  LEFT JOIN detalle_reparto dr ON dr.detalle_instancia_produccion_id=dip.id
  GROUP BY dip.id,dip.cantidad
  HAVING coalesce(sum(dr.cantidad),0)<>dip.cantidad
 ) THEN
   RAISE EXCEPTION 'Los repartos no coinciden con la produccion.';
 END IF;
 IF EXISTS (
  SELECT 1 FROM detalle_venta dv JOIN venta v ON v.id=dv.venta_id
  JOIN cliente c ON c.id=v.cliente_id
  JOIN promocion p ON p.id=dv.promocion_id
  WHERE NOT (v.fecha_hora::date BETWEEN p.fecha_desde AND p.fecha_hasta)
     OR NOT EXISTS (SELECT 1 FROM promocion_tipo_cliente ptc
            WHERE ptc.promocion_id=p.id AND ptc.tipo_cliente_id=c.tipo_cliente_id)
     OR NOT EXISTS (SELECT 1 FROM promocion_producto pp
            JOIN producto_sucursal ps ON ps.producto_id=pp.producto_id
            WHERE pp.promocion_id=p.id AND ps.id=dv.producto_sucursal_id)
 ) THEN
   RAISE EXCEPTION 'Se detectaron promociones fuera de vigencia o segmento/producto.';
 END IF;
 SELECT count(DISTINCT date_trunc('month',fecha_hora)) INTO v_meses FROM venta;
 IF v_meses<>46 THEN
   RAISE EXCEPTION 'Se esperaban 46 meses de ventas y se obtuvieron %.',v_meses;
 END IF;
 IF EXISTS (
  SELECT 1 FROM compra c JOIN (
   SELECT dc.compra_id,sum(dc.cantidad*dc.precio_unitario_historico) total
   FROM detalle_compra dc GROUP BY dc.compra_id
  ) t ON t.compra_id=c.id
  JOIN (SELECT dp.compra_id,sum(dp.monto) pagado
        FROM detalle_pago dp GROUP BY dp.compra_id) p ON p.compra_id=c.id
  WHERE p.pagado > round(t.total,2)+0.01
 ) THEN
   RAISE EXCEPTION 'Se detectaron pagos superiores a compras.';
 END IF;
 IF EXISTS (
  SELECT 1 FROM venta v JOIN (
   SELECT dv.venta_id,sum(dv.cantidad*dv.precio_unitario_historico) total
   FROM detalle_venta dv GROUP BY dv.venta_id
  ) t ON t.venta_id=v.id
  JOIN (SELECT dc.venta_id,sum(dc.monto) cobrado
        FROM detalle_cobro dc GROUP BY dc.venta_id) c ON c.venta_id=v.id
  WHERE c.cobrado > round(t.total,2)+0.05
 ) THEN
   RAISE EXCEPTION 'Se detectaron cobros superiores a ventas.';
 END IF;
END
$verificaciones$;

COMMIT;

-- RESUMEN de control, ya fuera de la transaccion.
SELECT entidad,registros FROM (
 SELECT 1 orden,'clientes'::text entidad,count(*)::bigint registros FROM cliente
 UNION ALL SELECT 2,'productos',count(*) FROM producto
 UNION ALL SELECT 3,'insumos',count(*) FROM insumo
 UNION ALL SELECT 4,'promociones',count(*) FROM promocion
 UNION ALL SELECT 5,'compras',count(*) FROM compra
 UNION ALL SELECT 6,'detalle_compra',count(*) FROM detalle_compra
 UNION ALL SELECT 7,'pagos',count(*) FROM pago
 UNION ALL SELECT 8,'ventas',count(*) FROM venta
 UNION ALL SELECT 9,'detalle_venta',count(*) FROM detalle_venta
 UNION ALL SELECT 10,'ventas_con_promocion',count(*) FROM detalle_venta WHERE promocion_id IS NOT NULL
 UNION ALL SELECT 11,'cobros',count(*) FROM cobro
 UNION ALL SELECT 12,'producciones',count(*) FROM instancia_de_produccion
 UNION ALL SELECT 13,'detalle_produccion',count(*) FROM detalle_instancia_de_produccion
 UNION ALL SELECT 14,'repartos',count(*) FROM reparto
 UNION ALL SELECT 15,'detalle_reparto',count(*) FROM detalle_reparto
 UNION ALL SELECT 16,'ajustes_stock',count(*) FROM ajuste_stock
 UNION ALL SELECT 17,'movimientos_stock',count(*) FROM movimiento_stock
 UNION ALL SELECT 18,'cif',count(*) FROM cif
 UNION ALL SELECT 19,'cheques',count(*) FROM cheque
) resumen ORDER BY orden;

SELECT min(fecha_hora)::date AS fecha_primera_venta,
       max(fecha_hora)::date AS fecha_ultima_venta,
       count(DISTINCT date_trunc('month',fecha_hora)) AS meses_con_ventas
FROM venta;
