-- =====================================================================
-- VEXA CLOTHING & FOOTWEAR COLLECTIVE | JAIPUR
-- Ultra-Premium Production Relational Database Schema
-- Database Engine: PostgreSQL 14+ / Supabase / Neon / AWS Aurora RDS
-- All 24 Required Relational Entities, Foreign Keys, Indexes & Constraints
-- =====================================================================

-- Enable Cryptographic & UUID Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ==================== 1. ROLES & PERMISSIONS ====================
CREATE TABLE IF NOT EXISTS roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(50) UNIQUE NOT NULL, -- 'owner', 'admin', 'staff', 'customer'
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug VARCHAR(100) UNIQUE NOT NULL, -- 'products:create', 'orders:refund', etc.
    module VARCHAR(50) NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS role_permissions (
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, permission_id)
);

-- ==================== 2. USERS MASTER TABLE ====================
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone VARCHAR(20) UNIQUE,
    phone_verified BOOLEAN DEFAULT FALSE,
    email VARCHAR(255) UNIQUE,
    email_verified BOOLEAN DEFAULT FALSE,
    password_hash VARCHAR(255), -- Argon2id / bcrypt hash (Owner / Staff)
    full_name VARCHAR(150) NOT NULL,
    role_id UUID REFERENCES roles(id) ON DELETE RESTRICT,
    totp_secret VARCHAR(64), -- Base32 TOTP secret for 2FA
    totp_enabled BOOLEAN DEFAULT FALSE,
    recovery_codes TEXT[], -- Hashed backup recovery codes
    status VARCHAR(30) DEFAULT 'active', -- 'active', 'suspended', 'locked'
    failed_login_attempts INT DEFAULT 0,
    lockout_until TIMESTAMP WITH TIME ZONE,
    last_login_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ==================== 3. USER PROFILES ====================
CREATE TABLE IF NOT EXISTS user_profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    gender VARCHAR(20),
    dob DATE,
    avatar_url TEXT,
    preferred_language VARCHAR(10) DEFAULT 'en',
    preferences JSONB DEFAULT '{}'::jsonb,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ==================== 4. USER ADDRESSES (MULTI-ADDRESS SUPPORT) ====================
CREATE TABLE IF NOT EXISTS user_addresses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    recipient_name VARCHAR(150) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    address_type VARCHAR(50) DEFAULT 'Home', -- 'Home', 'Work', 'Atelier'
    address_line_1 TEXT NOT NULL,
    address_line_2 TEXT,
    landmark VARCHAR(150),
    city VARCHAR(100) NOT NULL,
    state VARCHAR(100) NOT NULL,
    pincode VARCHAR(10) NOT NULL,
    country VARCHAR(100) DEFAULT 'India',
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ==================== 5. USER SESSIONS & AUTH SECURITY ====================
CREATE TABLE IF NOT EXISTS user_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    session_token_hash VARCHAR(64) UNIQUE NOT NULL, -- SHA-256 hash of random session token
    ip_address VARCHAR(45) NOT NULL,
    user_agent TEXT,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    revoked_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ==================== 6. PRODUCT CATEGORIES & SUBCATEGORIES ====================
CREATE TABLE IF NOT EXISTS product_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug VARCHAR(100) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    gender VARCHAR(50) NOT NULL, -- 'men', 'women', 'footwear', 'sneakers', 'kids', 'accessories'
    tagline TEXT,
    image_url TEXT,
    display_order INT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS product_subcategories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id UUID NOT NULL REFERENCES product_categories(id) ON DELETE CASCADE,
    slug VARCHAR(100) NOT NULL,
    name VARCHAR(100) NOT NULL,
    display_order INT DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(category_id, slug)
);

-- ==================== 7. PRODUCTS MASTER TABLE ====================
CREATE TABLE IF NOT EXISTS products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sku VARCHAR(100) UNIQUE NOT NULL, -- Master SKU (e.g. 'VX-M-BANDHGALA-01')
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(255) UNIQUE NOT NULL,
    category_id UUID NOT NULL REFERENCES product_categories(id) ON DELETE RESTRICT,
    subcategory_id UUID REFERENCES product_subcategories(id) ON DELETE SET NULL,
    gender VARCHAR(50) NOT NULL,
    brand VARCHAR(100) DEFAULT 'VEXA Atelier',
    regular_price DECIMAL(10, 2) NOT NULL,
    discount_price DECIMAL(10, 2) NOT NULL,
    tax_rate DECIMAL(4, 2) DEFAULT 0.12, -- GST 12% for Indian luxury textiles
    description TEXT NOT NULL,
    fabric_composition TEXT NOT NULL, -- e.g. '100% Single-Origin Giza Cotton'
    material TEXT,                    -- e.g. 'Handloom Weave / Italian Calfskin'
    weave_type TEXT,
    fit_type TEXT,
    wash_care TEXT,
    origin_atelier VARCHAR(150) DEFAULT 'Jaipur Atelier, Rajasthan, India',
    product_status VARCHAR(30) DEFAULT 'published', -- 'published', 'draft', 'archived'
    is_featured BOOLEAN DEFAULT FALSE,
    is_new BOOLEAN DEFAULT FALSE,
    is_bestseller BOOLEAN DEFAULT FALSE,
    is_limited BOOLEAN DEFAULT FALSE,
    meta_title VARCHAR(255),
    meta_description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ==================== 8. PRODUCT IMAGES (MULTIPLE HIGH-RES PHOTOS) ====================
CREATE TABLE IF NOT EXISTS product_images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    alt_text VARCHAR(255),
    display_order INT DEFAULT 0,
    is_primary BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ==================== 9. PRODUCT VARIANTS (SKU & STOCK PER SIZE/COLOR) ====================
CREATE TABLE IF NOT EXISTS product_variants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    size VARCHAR(20) NOT NULL,         -- 'S', 'M', 'L', 'XL', 'XXL', '40', '42', 'UK 8', etc.
    color_name VARCHAR(100) NOT NULL,  -- 'Ivory White', 'Matte Black', 'Royal Gold'
    color_hex VARCHAR(20) NOT NULL,
    sku_variant VARCHAR(120) UNIQUE NOT NULL, -- Unique Variant SKU (e.g. 'VX-M-SHIRT-IVR-M')
    stock_quantity INT NOT NULL DEFAULT 0 CHECK (stock_quantity >= 0),
    reserved_stock INT NOT NULL DEFAULT 0 CHECK (reserved_stock >= 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(product_id, size, color_name)
);

-- ==================== 10. INVENTORY AUDIT LOGS ====================
CREATE TABLE IF NOT EXISTS inventory_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    variant_id UUID NOT NULL REFERENCES product_variants(id) ON DELETE CASCADE,
    change_amount INT NOT NULL, -- Positive for restock, negative for deduction
    reason VARCHAR(50) NOT NULL, -- 'order_placed', 'order_cancelled', 'admin_restock', 'return_received'
    reference_id VARCHAR(100),   -- e.g. Order ID 'VX-2026-8942'
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ==================== 11. CARTS & CART ITEMS ====================
CREATE TABLE IF NOT EXISTS carts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    session_id VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS cart_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cart_id UUID NOT NULL REFERENCES carts(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    variant_id UUID NOT NULL REFERENCES product_variants(id) ON DELETE CASCADE,
    quantity INT NOT NULL DEFAULT 1 CHECK (quantity > 0),
    added_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(cart_id, variant_id)
);

-- ==================== 12. WISHLISTS ====================
CREATE TABLE IF NOT EXISTS wishlists (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, product_id)
);

-- ==================== 13. COUPONS & DISCOUNTS ====================
CREATE TABLE IF NOT EXISTS coupons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) UNIQUE NOT NULL,
    type VARCHAR(20) NOT NULL, -- 'percentage', 'fixed', 'shipping'
    discount_value DECIMAL(10, 2) NOT NULL,
    min_order_value DECIMAL(10, 2) DEFAULT 0.00,
    max_discount_value DECIMAL(10, 2),
    usage_limit INT DEFAULT 1000,
    used_count INT DEFAULT 0,
    starts_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ==================== 14. ORDERS MASTER TABLE ====================
CREATE TABLE IF NOT EXISTS orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_number VARCHAR(50) UNIQUE NOT NULL, -- 'VX-2026-8942'
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    customer_name VARCHAR(150) NOT NULL,
    customer_email VARCHAR(255),
    customer_phone VARCHAR(20) NOT NULL,
    shipping_address_line TEXT NOT NULL,
    shipping_city VARCHAR(100) NOT NULL,
    shipping_state VARCHAR(100) NOT NULL,
    shipping_pincode VARCHAR(10) NOT NULL,
    subtotal DECIMAL(10, 2) NOT NULL,
    discount_amount DECIMAL(10, 2) DEFAULT 0.00,
    shipping_fee DECIMAL(10, 2) DEFAULT 0.00,
    tax_amount DECIMAL(10, 2) NOT NULL, -- GST 12%
    total_amount DECIMAL(10, 2) NOT NULL,
    applied_coupon VARCHAR(50),
    order_status VARCHAR(50) DEFAULT 'Order Placed', 
    -- 'Order Placed', 'Confirmed', 'Processing', 'Packed', 'Shipped', 'Out for Delivery', 'Delivered', 'Cancelled', 'Refunded'
    payment_method VARCHAR(50) NOT NULL, -- 'UPI', 'Credit/Debit Card', 'Net Banking', 'Cash on Delivery'
    payment_status VARCHAR(50) DEFAULT 'Pending', -- 'Pending', 'Paid', 'Failed', 'Refunded'
    payment_id VARCHAR(100),
    razorpay_order_id VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ==================== 15. ORDER ITEMS ====================
CREATE TABLE IF NOT EXISTS order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    variant_id UUID REFERENCES product_variants(id) ON DELETE SET NULL,
    product_name VARCHAR(255) NOT NULL,
    sku_variant VARCHAR(120) NOT NULL,
    size VARCHAR(20) NOT NULL,
    color VARCHAR(100) NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    total_price DECIMAL(10, 2) NOT NULL,
    image_url TEXT
);

-- ==================== 16. PAYMENTS & GATEWAY AUDIT ====================
CREATE TABLE IF NOT EXISTS payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    gateway VARCHAR(50) NOT NULL, -- 'Razorpay', 'Cashfree', 'COD'
    gateway_order_id VARCHAR(100),
    gateway_payment_id VARCHAR(100),
    gateway_signature VARCHAR(255),
    amount DECIMAL(10, 2) NOT NULL,
    currency VARCHAR(10) DEFAULT 'INR',
    status VARCHAR(50) NOT NULL, -- 'Authorized', 'Captured', 'Failed', 'Refunded'
    idempotency_key VARCHAR(100) UNIQUE,
    error_code VARCHAR(100),
    error_description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ==================== 17. SHIPMENTS & TRACKING TIMELINE ====================
CREATE TABLE IF NOT EXISTS shipments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    carrier_name VARCHAR(100) DEFAULT 'BlueDart Express',
    tracking_number VARCHAR(100) UNIQUE,
    estimated_delivery DATE,
    actual_delivery TIMESTAMP WITH TIME ZONE,
    current_status VARCHAR(50) DEFAULT 'Order Placed',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS order_timeline (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    status VARCHAR(100) NOT NULL,
    note TEXT,
    completed BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ==================== 18. RETURNS & REFUNDS ====================
CREATE TABLE IF NOT EXISTS returns_refunds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    order_item_id UUID REFERENCES order_items(id) ON DELETE SET NULL,
    type VARCHAR(30) DEFAULT 'return', -- 'return', 'exchange'
    reason TEXT NOT NULL,
    status VARCHAR(50) DEFAULT 'Requested', -- 'Requested', 'Approved', 'Picked Up', 'Refunded', 'Rejected'
    refund_amount DECIMAL(10, 2),
    refund_transaction_id VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ==================== 19. PRODUCT REVIEWS & RATINGS ====================
CREATE TABLE IF NOT EXISTS product_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    reviewer_name VARCHAR(150) NOT NULL,
    reviewer_city VARCHAR(100),
    rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    verified_purchase BOOLEAN DEFAULT FALSE,
    helpful_votes INT DEFAULT 0,
    is_approved BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ==================== 20. NOTIFICATIONS ====================
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    link_url TEXT,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ==================== 21. ADMIN AUDIT LOGS (SECURITY & ACTIVITY) ====================
CREATE TABLE IF NOT EXISTS admin_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    actor_email VARCHAR(255) NOT NULL,
    actor_role VARCHAR(50) NOT NULL,
    action VARCHAR(100) NOT NULL, -- 'product_create', 'order_status_update', 'price_change', 'totp_enabled'
    resource_type VARCHAR(50) NOT NULL,
    resource_id VARCHAR(100),
    metadata JSONB DEFAULT '{}'::jsonb, -- Sanitized: NO passwords, tokens, or OTPs
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ==================== 22. SECURITY INCIDENTS & FAILED LOGINS ====================
CREATE TABLE IF NOT EXISTS security_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type VARCHAR(50) NOT NULL, -- 'failed_login', 'invalid_totp', 'rate_limit_exceeded', 'tamper_attempt'
    target_identifier VARCHAR(255),  -- Phone number or Email
    ip_address VARCHAR(45) NOT NULL,
    user_agent TEXT,
    details JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ==================== 23. HIGH PERFORMANCE INDEXES ====================
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category_id);
CREATE INDEX IF NOT EXISTS idx_products_gender ON products(gender);
CREATE INDEX IF NOT EXISTS idx_products_status ON products(product_status);
CREATE INDEX IF NOT EXISTS idx_products_price ON products(discount_price);
CREATE INDEX IF NOT EXISTS idx_variants_product ON product_variants(product_id);
CREATE INDEX IF NOT EXISTS idx_variants_sku ON product_variants(sku_variant);
CREATE INDEX IF NOT EXISTS idx_orders_user ON orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(order_status);
CREATE INDEX IF NOT EXISTS idx_orders_number ON orders(order_number);
CREATE INDEX IF NOT EXISTS idx_sessions_token ON user_sessions(session_token_hash);
CREATE INDEX IF NOT EXISTS idx_audit_created ON admin_audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reviews_product ON product_reviews(product_id);
