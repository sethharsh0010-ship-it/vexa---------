-- =====================================================================
-- VEXA Relational Seed Data
-- =====================================================================

-- 1. Default Roles
INSERT INTO roles (id, name, description) VALUES
    ('00000000-0000-0000-0000-000000000001', 'owner', 'Master Brand Owner & Platform Administrator'),
    ('00000000-0000-0000-0000-000000000002', 'admin', 'Atelier Operations & Inventory Manager'),
    ('00000000-0000-0000-0000-000000000003', 'staff', 'Customer Concierge & Fulfillment Staff'),
    ('00000000-0000-0000-0000-000000000004', 'customer', 'Registered Patron Member')
ON CONFLICT (name) DO NOTHING;

-- 2. Core Permissions
INSERT INTO permissions (slug, module, description) VALUES
    ('products:create', 'products', 'Create new luxury piece in atelier catalogue'),
    ('products:update', 'products', 'Update piece pricing, description and images'),
    ('products:delete', 'products', 'Archive or delete product from catalogue'),
    ('inventory:manage', 'inventory', 'Adjust SKU variation stock quantities'),
    ('orders:view', 'orders', 'View patron orders and delivery details'),
    ('orders:status', 'orders', 'Update order logistics fulfillment timeline'),
    ('orders:refund', 'orders', 'Process return and issue refund to patron'),
    ('coupons:manage', 'discounts', 'Generate and toggle promotional discount codes'),
    ('security:audit', 'security', 'Access security logs, failed logins, and sessions')
ON CONFLICT (slug) DO NOTHING;

-- 3. Owner Bootstrap (Seeded with pre-hashed master credentials, TOTP enforcement required on first login)
INSERT INTO users (id, phone, phone_verified, email, email_verified, password_hash, full_name, role_id, status)
VALUES (
    '00000000-0000-0000-0000-000000000010',
    '+919829012345',
    TRUE,
    'sethharsh0010@gmail.com',
    TRUE,
    -- Default argon2id/bcrypt representation for initial deployment
    '\\\.f8C3rVvWf5hE4dK0J6j1vE0VwZq0qM7', 
    'Harsh',
    '00000000-0000-0000-0000-000000000001',
    'active'
)
ON CONFLICT (email) DO UPDATE SET role_id = EXCLUDED.role_id;

-- 4. Active Coupons
INSERT INTO coupons (code, type, discount_value, min_order_value, usage_limit, expires_at, description)
VALUES 
    ('JAIPURGOLD', 'fixed', 500.00, 2499.00, 5000, '2028-12-31 23:59:59+05:30', '₹500 Off on First Luxury Order over ₹2,499'),
    ('ATELIER10', 'percentage', 10.00, 4999.00, 2000, '2028-12-31 23:59:59+05:30', '10% Exclusive Atelier Patron Privilege'),
    ('FREESHIP', 'shipping', 149.00, 0.00, 10000, '2028-12-31 23:59:59+05:30', 'Complimentary Express Air Shipping Nationwide')
ON CONFLICT (code) DO NOTHING;
