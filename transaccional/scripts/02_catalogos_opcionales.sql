-- Catalogos de ejemplo fundamentados en el funcionamiento descrito
-- en PPAI_Entrega1_SSD_G1.pdf. Ejecutar conectado a easa_oltp.
-- Los tipos y estados exactos son convenciones que deben contrastarse
-- con la implementacion del negocio. NO incluye operaciones ficticias.
BEGIN;
INSERT INTO ciudad (nombre) VALUES ('Villa María'), ('Villa Nueva')
ON CONFLICT (nombre) DO NOTHING;

INSERT INTO sucursal (nombre, direccion, ciudad_id, tiene_planta)
SELECT d.nombre, d.direccion, c.id, d.tiene_planta
FROM (VALUES
    ('Villa María Centro', 'Bv. Sarmiento 1250', 'Villa María', TRUE),
    ('Villa María Norte', 'Av. Sabattini 850', 'Villa María', FALSE),
    ('Villa María Este', 'Av. Colón 420', 'Villa María', TRUE),
    ('Villa María Sur', 'Calle Mendoza 780', 'Villa María', FALSE),
    ('Villa Nueva Centro', 'Av. Carranza 610', 'Villa Nueva', TRUE),
    ('Villa Nueva Norte', 'Calle Córdoba 340', 'Villa Nueva', FALSE)
) AS d(nombre, direccion, ciudad, tiene_planta)
JOIN ciudad c ON c.nombre = d.ciudad
ON CONFLICT (nombre) DO NOTHING;

INSERT INTO tipo_cliente(nombre) VALUES
    ('Mostrador'), ('Negocio'), ('Escuela'), ('Iglesia'), ('Donación')
ON CONFLICT (nombre) DO NOTHING;

INSERT INTO tipo_movimiento(nombre) VALUES
    ('Venta'), ('Compra'), ('Producción'), ('Ajuste')
ON CONFLICT (nombre) DO NOTHING;

INSERT INTO medio_pago(nombre) VALUES
    ('Efectivo'), ('Transferencia'), ('Cuenta corriente'), ('Cheque')
ON CONFLICT (nombre) DO NOTHING;

INSERT INTO estado(ambito, nombre) VALUES
    ('compra','Pendiente de pago'),
    ('compra','Parcialmente pagada'),
    ('compra','Totalmente pagada'),
    ('venta','Pendiente de cobro'),
    ('venta','Parcialmente cobrada'),
    ('venta','Totalmente cobrada'),
    ('cheque','Entregado'),
    ('cheque','Disponible'),
    ('cheque','Rechazado')
ON CONFLICT (ambito, nombre) DO NOTHING;
COMMIT;
