#!/usr/bin/env python3
"""
Central Store Server - Database Models & Pydantic Validation Schemas
Defines SQLAlchemy ORM entities matching Schema.md & Backend.md,
and strict Pydantic schemas compatible with Flutter, Next.js, and Pi clients.
"""

from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
from sqlalchemy import (
    Column,
    String,
    Integer,
    Float,
    Boolean,
    DateTime,
    ForeignKey,
    Text,
)
from sqlalchemy.orm import relationship
from pydantic import BaseModel, Field, ConfigDict

from database import Base


# ==============================================================================
# SQLAlchemy ORM Models
# ==============================================================================

class Product(Base):
    """Retail catalog product, barcode identification, aisle, and inventory."""
    __tablename__ = "products"

    barcode = Column(String(32), primary_key=True, index=True)
    sku = Column(String(64), unique=True, nullable=False)
    name = Column(String(256), nullable=False)
    brand = Column(String(128), nullable=False, default="Generic")
    category = Column(String(64), nullable=False, default="General")
    aisle = Column(String(64), nullable=False, default="Aisle 1")
    shelf_section = Column(String(64), nullable=False, default="Sec 1")
    map_x_coord = Column(Float, default=0.0)
    map_y_coord = Column(Float, default=0.0)
    mrp = Column(Float, nullable=False)
    sale_price = Column(Float, nullable=False)
    stock_qty = Column(Integer, nullable=False, default=50)
    unit_weight_grams = Column(Integer, nullable=False, default=250)
    image_url = Column(Text, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    # Relationships
    cart_items = relationship("CartItem", back_populates="product", cascade="all, delete-orphan")

    @property
    def price(self) -> float:
        return self.sale_price

    @property
    def original_price(self) -> float:
        return self.mrp

    @property
    def stock(self) -> int:
        return self.stock_qty


class ActiveCart(Base):
    """Smart shopping cart status, current shopper assignment, and basket totals."""
    __tablename__ = "active_carts"

    cart_id = Column(String(32), primary_key=True, index=True)
    user_id = Column(String(64), nullable=True)
    status = Column(String(32), nullable=False, default="IDLE")  # 'STANDBY', 'IDLE', 'ACTIVE', 'PAID', 'ALERT'
    total_amount = Column(Float, default=0.0)
    item_count = Column(Integer, default=0)
    store_id = Column(String(64), default="DMART_HSR_01")
    battery_level = Column(Integer, default=88)
    ip_address = Column(String(45), default="127.0.0.1")
    session_id = Column(String(64), nullable=True)
    receipt_id = Column(String(64), nullable=True)
    exit_pass_token = Column(String(256), nullable=True)
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    @property
    def running_total(self) -> float:
        return self.total_amount

    @property
    def items_count(self) -> int:
        return self.item_count


class CartItem(Base):
    """Line item stored in an active shopping cart."""
    __tablename__ = "cart_items"

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    cart_id = Column(String(32), nullable=True, index=True)
    session_id = Column(String(64), nullable=True, index=True)
    barcode = Column(String(32), ForeignKey("products.barcode"), nullable=False)
    product_name = Column(String(256), nullable=True)
    unit_price = Column(Float, nullable=False)
    original_price = Column(Float, default=0.0)
    quantity = Column(Integer, default=1, nullable=False)
    weight_grams = Column(Integer, default=250, nullable=False)
    vision_verified = Column(Boolean, default=True)
    added_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    # Relationships
    product = relationship("Product", back_populates="cart_items")

    @property
    def price(self) -> float:
        return self.unit_price

    @property
    def name(self) -> str:
        return self.product_name or (self.product.name if self.product else "Retail Item")


class SecurityAlert(Base):
    """Audit log of anti-theft security anomalies and weight deviations."""
    __tablename__ = "security_alerts"

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    cart_id = Column(String(32), nullable=False, index=True)
    session_id = Column(String(64), nullable=True)
    alert_type = Column(String(64), nullable=False, default="UNSCANNED_DROP")
    event_type = Column(String(64), nullable=False, default="UNSCANNED_DROP")
    detected_class = Column(String(64), default="item")
    message = Column(Text, nullable=False)
    timestamp = Column(Float, nullable=True)
    is_resolved = Column(Boolean, default=False)
    resolved = Column(Boolean, default=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))


class User(Base):
    """Registered shopper profile, loyalty tier, and reward points balance."""
    __tablename__ = "users"

    id = Column(String(64), primary_key=True, index=True)
    name = Column(String(128), nullable=False)
    phone = Column(String(20), unique=True, nullable=False, index=True)
    password_hash = Column(String(256), nullable=True)
    loyalty_tier = Column(String(32), default="Gold")
    reward_points = Column(Integer, default=2450)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))


class CartSession(Base):
    """Detailed shopping trip session binding shopper to physical cart."""
    __tablename__ = "cart_sessions"

    session_id = Column(String(64), primary_key=True, index=True)
    cart_id = Column(String(32), nullable=False, index=True)
    user_id = Column(String(64), nullable=False, index=True)
    status = Column(String(32), default="ACTIVE")  # 'ACTIVE', 'PAID', 'ABANDONED', 'CLOSED'
    total_mrp = Column(Float, default=0.0)
    running_total = Column(Float, default=0.0)
    total_savings = Column(Float, default=0.0)
    items_count = Column(Integer, default=0)
    payment_method = Column(String(64), nullable=True)
    receipt_id = Column(String(64), nullable=True)
    exit_pass_token = Column(String(256), nullable=True)
    started_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    ended_at = Column(DateTime, nullable=True)


class Order(Base):
    """Immutable completed retail transaction for invoices and history."""
    __tablename__ = "orders"

    order_id = Column(String(64), primary_key=True, index=True)
    user_id = Column(String(64), nullable=False, index=True)
    cart_id = Column(String(32), nullable=False)
    store_name = Column(String(128), nullable=False, default="D-Mart • HyperPulse HSR")
    total_mrp = Column(Float, nullable=False, default=0.0)
    total_paid = Column(Float, nullable=False, default=0.0)
    total_savings = Column(Float, nullable=False, default=0.0)
    items_count = Column(Integer, nullable=False, default=0)
    payment_method = Column(String(64), nullable=False, default="UPI_FASTPAY")
    receipt_id = Column(String(64), nullable=False)
    exit_token = Column(String(256), nullable=False)
    status = Column(String(32), default="Completed")
    items_json = Column(Text, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))


# ==============================================================================
# Pydantic Schemas (Request / Response Models)
# ==============================================================================

class ProductBase(BaseModel):
    model_config = ConfigDict(from_attributes=True, populate_by_name=True)

    barcode: str
    sku: str
    name: str
    brand: str = "Generic"
    category: str = "General"
    aisle: str = "Aisle 1"
    shelf_section: str = "Sec 1"
    map_x_coord: float = 0.0
    map_y_coord: float = 0.0
    mrp: float
    sale_price: float
    stock_qty: int = 50
    unit_weight_grams: int = 250
    image_url: Optional[str] = None


class ProductCreate(ProductBase):
    pass


class ProductResponse(ProductBase):
    price: float = Field(default=0.0)
    original_price: float = Field(default=0.0)
    stock: int = Field(default=50)

    def model_post_init(self, __context: Any) -> None:
        if not self.price:
            self.price = self.sale_price
        if not self.original_price:
            self.original_price = self.mrp
        if not self.stock:
            self.stock = self.stock_qty


class ProductSearchItem(BaseModel):
    model_config = ConfigDict(from_attributes=True, populate_by_name=True)

    id: str
    barcode: str
    sku: str
    name: str
    brand: str
    category: str
    aisle: str
    shelf_section: str
    map_x_coord: float
    map_y_coord: float
    price: float
    original_price: float
    stock: int
    distance_meters: float = 12.0
    image_url: Optional[str] = None


# --- Active Cart Schemas ---

class ActiveCartResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True, populate_by_name=True)

    cart_id: str
    user_id: Optional[str] = None
    status: str
    current_state: str = "IDLE"
    total_amount: float = 0.0
    running_total: float = 0.0
    item_count: int = 0
    items_count: int = 0
    store_id: str = "DMART_HSR_01"
    battery_level: int = 88
    ip_address: str = "127.0.0.1"
    session_id: Optional[str] = None
    receipt_id: Optional[str] = None
    exit_pass_token: Optional[str] = None
    updated_at: Optional[datetime] = None


# --- Cart Item Schemas ---

class CartItemPayload(BaseModel):
    model_config = ConfigDict(from_attributes=True, populate_by_name=True)

    barcode: str
    name: str
    price: float
    original_price: float = 0.0
    quantity: int = 1
    category: str = "Groceries"
    aisle: str = "Aisle 1"
    weight_grams: int = 250
    vision_verified: bool = True
    timestamp: Optional[Any] = None
    image_url: Optional[str] = None


class CartItemResponse(CartItemPayload):
    id: Optional[int] = None
    cart_id: Optional[str] = None
    session_id: Optional[str] = None


# --- Security Alert Schemas ---

class SecurityAlertCreate(BaseModel):
    model_config = ConfigDict(from_attributes=True, populate_by_name=True)

    cart_id: str
    alert_type: str = "UNSCANNED_DROP"
    event_type: Optional[str] = None
    detected_class: str = "item"
    message: str = "Unscanned physical item detected in cart basket."
    timestamp: Optional[float] = None
    is_resolved: bool = False
    resolved: bool = False


class SecurityAlertResponse(SecurityAlertCreate):
    id: int
    created_at: Optional[datetime] = None


class PiRegisterRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    cart_id: str = Field(..., description="Cart identifier, e.g. CART_01")
    pi_ip: str = Field(default="auto", alias="ip_address", description="Wi-Fi IPv4 address of Raspberry Pi")
    pi_port: int = Field(5000, alias="port", description="Port the Pi edge server is running on")


# --- Session Pairing Schemas ---

class SessionPairRequest(BaseModel):
    cart_id: str
    user_id: str
    timestamp: Optional[str] = None


class SessionPairResponse(BaseModel):
    status: str = "paired"
    session_id: str
    cart_id: str
    user_id: str
    current_state: str = "IDLE"
    store_name: str = "D-Mart • HyperPulse HSR"
    message: str = "Cart paired successfully"


# --- Checkout Schemas ---

class CheckoutRequest(BaseModel):
    cart_id: str
    status: str = "PAID"
    payment_method: str = "UPI_FASTPAY"
    amount: float = 0.0
    timestamp: Optional[str] = None


class CheckoutResponse(BaseModel):
    status: str = "PAID"
    cart_id: str
    session_id: str
    receipt_id: str
    exit_pass_token: str
    amount_paid: float
    timestamp: str
    message: str = "Checkout complete"


# --- Authentication Schemas ---

class LoginRequest(BaseModel):
    phone: str
    password: Optional[str] = None


class LoginResponse(BaseModel):
    status: str = "authenticated"
    user_id: str
    name: str
    phone: str
    loyalty_tier: str = "Gold"
    reward_points: int = 2450


# --- Upstream Pi Sync Schemas ---

class CartSyncRequest(BaseModel):
    cart_id: str
    action: str  # 'ADD_ITEM', 'REMOVE_ITEM', 'UNSCANNED_DROP'
    detected_class: str = "item"
    timestamp: Optional[float] = None
    barcode: Optional[str] = None


class CartSyncResponse(BaseModel):
    status: str = "success"
    action: str
    cart_id: str
    barcode: Optional[str] = None
    items_count: int = 0
    running_total: float = 0.0


# --- Admin Dashboard Metrics & Orders ---

class AdminStatsResponse(BaseModel):
    visitors_today: int = 124
    active_customers: int = 342
    active_baskets: int = 42
    avg_checkout_sec: int = 96
    avg_basket_val: float = 52.00
    total_revenue_today: float = 18450.00
    store_status: str = "Open"
    fleet_health_percent: float = 97.8


class OrderItemSnapshot(BaseModel):
    name: str
    quantity: int = 1
    price: float
    original_price: float
    weight_grams: int = 250


class OrderHistoryItem(BaseModel):
    order_id: str
    store_name: str
    created_at: str
    total_paid: float
    total_mrp: float
    total_savings: float
    items_count: int
    status: str = "Completed"
    receipt_id: str
    exit_token: str
    items: List[OrderItemSnapshot] = []
