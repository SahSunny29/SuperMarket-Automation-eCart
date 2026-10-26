#!/usr/bin/env python3
"""
Central Store Server - Database Seeding Script
Idempotently initializes SQLite/PostgreSQL schema and seeds:
1. In-store retail product catalog with optical barcodes matching Pi & Flutter apps.
2. Active smart trolley hardware records (e.g. CART_01).
3. Default shopper account (U12345 / Sunny Kumar Sah).
4. Past transaction order history for customer app display.
"""

import json
import logging
import sys
from datetime import datetime, timezone

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    except Exception:
        pass

from database import init_db, SessionLocal
from models import Product, ActiveCart, User, Order, CartItem, SecurityAlert, CartSession

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(name)s: %(message)s")
logger = logging.getLogger("SeedScript")


DEFAULT_PRODUCTS = [
    {
        "barcode": "8904406805028",
        "sku": "MAGGI-NOODLE-204G",
        "name": "Maggi 2-Minute Masala Noodles",
        "brand": "Nestlé",
        "category": "Instant Snack",
        "aisle": "Aisle 4 • Sec 2",
        "shelf_section": "Sec 2",
        "map_x_coord": 72.5,
        "map_y_coord": 38.0,
        "mrp": 56.00,
        "sale_price": 52.00,
        "stock_qty": 42,
        "unit_weight_grams": 204,
        "image_url": "https://lh3.googleusercontent.com/aida-public/AB6AXuB72MIl67Yc3bRr8aekPpwAWkc1CFbVabndWuUYISCEP3HmZxjzOuSICRDuq4LW9icFsQurH_iiaoxWF-IZmHDHR2cHa7ENGJUzdGIkkhbJ84ZhK6vLmPNPu81qFey9F472b2TtAZFMX5lxKbtfUBRjxoZ06VEw0n2LIaPaYOR85L5YHYTfkzHIbKh_nm8n4gBduL4qQVp9zZy_sJ37E5PFQBTuL2ZX-rGRYFvvekEd7HNwnWc64eF-_A",
    },
    {
        "barcode": "8901058005783",
        "sku": "MAGGI-RED-SPECIAL-70G",
        "name": "Maggi Special Masala Noodles (70g)",
        "brand": "Nestlé",
        "category": "Instant Snack",
        "aisle": "Aisle 4 • Sec 2",
        "shelf_section": "Sec 2",
        "map_x_coord": 72.5,
        "map_y_coord": 39.0,
        "mrp": 15.00,
        "sale_price": 14.00,
        "stock_qty": 42,
        "unit_weight_grams": 70,
        "image_url": "https://lh3.googleusercontent.com/aida-public/AB6AXuB72MIl67Yc3bRr8aekPpwAWkc1CFbVabndWuUYISCEP3HmZxjzOuSICRDuq4LW9icFsQurH_iiaoxWF-IZmHDHR2cHa7ENGJUzdGIkkhbJ84ZhK6vLmPNPu81qFey9F472b2TtAZFMX5lxKbtfUBRjxoZ06VEw0n2LIaPaYOR85L5YHYTfkzHIbKh_nm8n4gBduL4qQVp9zZy_sJ37E5PFQBTuL2ZX-rGRYFvvekEd7HNwnWc64eF-_A",
    },
    {
        "barcode": "8901030383848",
        "sku": "AMUL-BUTTER-500G",
        "name": "Amul Pasteurised Butter 500g",
        "brand": "Amul",
        "category": "Dairy Fresh",
        "aisle": "Chillers A1",
        "shelf_section": "Chillers A1",
        "map_x_coord": 25.0,
        "map_y_coord": 80.0,
        "mrp": 275.00,
        "sale_price": 245.00,
        "stock_qty": 45,
        "unit_weight_grams": 508,
        "image_url": "https://lh3.googleusercontent.com/aida-public/AB6AXuCD-xZzjsgcXuaDvRNyovzM61lWts0vBd2LQ5aa9ott1gmGnSNJ9rPanqidN6a-JbeYyGV-HALBSnOq3T1DlUMfTnSP9H8oM_VPLQXzkXp6gZgT4UClC58fHVjL_AFWhcKKYeBNy4jUCnkzUS3zHbNGCeVnYqaso1I5Xs4b_NRKJkKY3AYeB1YMYwx-QovSfDtTh0HieSkqzqC68ZPV2U29-OzIcdcuL62bz16j383vf6WMnB3Sz_c9ow",
    },
    {
        "barcode": "8901725181222",
        "sku": "AASHIRVAAD-ATTA-5KG",
        "name": "Aashirvaad Shudh Chakki Atta 5kg",
        "brand": "ITC",
        "category": "100% Whole Wheat",
        "aisle": "Aisle 2A",
        "shelf_section": "Sec 1",
        "map_x_coord": 40.0,
        "map_y_coord": 30.0,
        "mrp": 320.00,
        "sale_price": 265.00,
        "stock_qty": 35,
        "unit_weight_grams": 5010,
        "image_url": "https://lh3.googleusercontent.com/aida-public/AB6AXuBZLIqsI8dVdIityH1UduggSeH5uKaj7JjDEeWir3emyLw0NQL7aZe0rx6RCaiFo25gZoqNqJ_aDfVvowa5gT80hyVKZaX1lYmOHe8coYgfJsqBLzYpIWwL9DUTN1FxOSz-7-fe9vixxCtbDt1YaDRji-DNUS4c544gktglt06nWp_0Y_TWIu9v3CInhlhggfhg-HPBw_wiDH1G2hm-4D0EXapxyUAFh2EQMKuUcbvik8SW-WG2McdVLg",
    },
    {
        "barcode": "8901030383855",
        "sku": "TATA-SALT-1KG",
        "name": "Tata Salt Vacuum Evaporated 1kg",
        "brand": "Tata",
        "category": "Cooking Essentials",
        "aisle": "Aisle 3A",
        "shelf_section": "Sec 4",
        "map_x_coord": 55.0,
        "map_y_coord": 45.0,
        "mrp": 30.00,
        "sale_price": 28.00,
        "stock_qty": 90,
        "unit_weight_grams": 1000,
        "image_url": "https://lh3.googleusercontent.com/aida-public/AB6AXuDtxS-UXxysAWe18wPRCdPYZYOM17ZQ05sr_6ul8JC9rY_tA7oTTAMC9SJn56r2pAs5Vg4Su6J0qFUdJ2Ii1QQegQAMhe8xf_vOYQdqJCRWLYpfAcxbJv4AvXnl8vGnXN1DP27riY_ayx3fv8Y6jnq7iNIb6ksUa7h4hfbdlHx4Vs4nUubMknjR-e0tpmuEryrbrbP-S3tno5afBn1yO081P9yAGzOv2_VH0zqqE7bfTIgDANJz3-sChA",
    },
    {
        "barcode": "8901030383862",
        "sku": "SURF-EXCEL-1KG",
        "name": "Surf Excel Quick Wash Detergent 1kg",
        "brand": "HUL",
        "category": "Household Care",
        "aisle": "Aisle 5C",
        "shelf_section": "Sec 3",
        "map_x_coord": 85.0,
        "map_y_coord": 70.0,
        "mrp": 160.00,
        "sale_price": 145.00,
        "stock_qty": 50,
        "unit_weight_grams": 1000,
        "image_url": "https://lh3.googleusercontent.com/aida-public/AB6AXuA4gHb3gXOhchdZ8BFsyCAS83mWj38-RAW3bBuMQWP561qNE_9T5qTfyKod3I6AsYuhK-q7auBG89ClvzJiA1uLfkedKAq0ZZzz1OA1ll6dl-RPV9tHfknPzwgsougjNBNjYvwSoDG78VjTZ4LDfw_vBdS_rvcLHVydY24fHB0HMHw3qfmF29H9Mn1E-GOd5I2AKXeDVi3t7vm-lQFOt6O6TwQneBrZlT6b17k_GVeVhXqamPrw77fTVA",
    },
    {
        "barcode": "8901030383879",
        "sku": "PARLE-G-250G",
        "name": "Parle-G Original Gluco Biscuits 250g",
        "brand": "Parle",
        "category": "Snacks & Biscuits",
        "aisle": "Aisle 1C",
        "shelf_section": "Sec 1",
        "map_x_coord": 20.0,
        "map_y_coord": 20.0,
        "mrp": 12.00,
        "sale_price": 10.00,
        "stock_qty": 120,
        "unit_weight_grams": 250,
        "image_url": "https://lh3.googleusercontent.com/aida-public/AB6AXuD4TxNmm2Sa4SHNoklkM9kmr_HUUSXFIqYJ9KMELeyE9TLKqMGkZBwA7_a7qqNAVyzgtzkAplIVwUnHsyTz19yeswP8wRgMHtfotDlkc5i3fBMf8h4gg_reqtdtp9p3Y48TSPhHpzgljLDX-yHpaUNwn1qgjCLo7FdEMvDPrQNVns6N1EBnGxmXbvEyUaNMfALXaYb8SwpH6bLsrmlQ0Sdr-aM8-q_EMMe6eKCEe3XlNRcCg8hdDPCY5g",
    },
    {
        "barcode": "8901058852258",
        "sku": "MAGGI-SAUCE-500G",
        "name": "Maggi Hot & Sweet Chilli Sauce (500g)",
        "brand": "Nestlé",
        "category": "Sauces & Masala",
        "aisle": "Aisle 3 • Sec 1",
        "shelf_section": "Sec 1",
        "map_x_coord": 45.0,
        "map_y_coord": 50.0,
        "mrp": 130.00,
        "sale_price": 115.00,
        "stock_qty": 20,
        "unit_weight_grams": 500,
        "image_url": "https://lh3.googleusercontent.com/aida-public/AB6AXuCNuqw3kYKh8dfPJOiMpdJjsPyyZjatnNzWA3LZyYSI28vSosOXSq8vwHFfb-1WzwUwDUubxrMXt5cDs1UEIEb948G7DSBl81cBpOjqKGJMrZQUeUyaJ5FyqpG6_1FzvEO2heC4W5AenWNyEtVP1DhpLT5a556Ck3sBTQGfuGVXj8g1xbrfr9DbcYQgIDcTuYk-M4Sig34BYnQGJcSPIMPgLlDFgmGEQQYFuUuwbf-AP482Q5OqqAwYIQ",
    },
]


def seed_database():
    """Seed initial records idempotently."""
    init_db()
    db = SessionLocal()

    try:
        logger.info("[Seed] Seeding Default Users...")
        default_user = db.query(User).filter(User.id == "U12345").first()
        if not default_user:
            default_user = User(
                id="U12345",
                name="Sunny Kumar Sah",
                phone="+91 98765 43210",
                loyalty_tier="Gold",
                reward_points=2450,
            )
            db.add(default_user)
            logger.info("  + Created user: U12345 (Sunny Kumar Sah)")
        else:
            logger.info("  * User U12345 already exists.")

        logger.info("[Seed] Clearing stale session items and test security alerts...")
        db.query(CartItem).delete()
        db.query(SecurityAlert).delete()

        logger.info("[Seed] Seeding & Resetting Smart Trolleys (active_carts)...")
        cart_01 = db.query(ActiveCart).filter(ActiveCart.cart_id == "CART_01").first()
        if not cart_01:
            cart_01 = ActiveCart(
                cart_id="CART_01",
                store_id="DMART_HSR_01",
                status="IDLE",
                total_amount=0.0,
                item_count=0,
                battery_level=88,
                ip_address="127.0.0.1",
            )
            db.add(cart_01)
            logger.info("  + Created active_cart: CART_01 (Status: IDLE, Battery: 88%)")
        else:
            cart_01.status = "IDLE"
            cart_01.user_id = None
            cart_01.session_id = None
            cart_01.total_amount = 0.0
            cart_01.item_count = 0
            cart_01.receipt_id = None
            cart_01.exit_pass_token = None
            if not cart_01.ip_address:
                cart_01.ip_address = "127.0.0.1"
            logger.info(f"  * Reset active_cart: CART_01 (Status: IDLE, IP: {cart_01.ip_address})")

        cart_02 = db.query(ActiveCart).filter(ActiveCart.cart_id == "CART_02").first()
        if not cart_02:
            cart_02 = ActiveCart(
                cart_id="CART_02",
                store_id="DMART_HSR_01",
                status="IDLE",
                total_amount=0.0,
                item_count=0,
                battery_level=94,
                ip_address="192.168.1.106",
            )
            db.add(cart_02)
            logger.info("  + Created active_cart: CART_02 (Status: IDLE, Battery: 94%)")
        else:
            cart_02.status = "IDLE"
            cart_02.user_id = None
            cart_02.session_id = None
            cart_02.total_amount = 0.0
            cart_02.item_count = 0
            logger.info("  * Reset active_cart: CART_02 (Status: IDLE)")

        logger.info("[Seed] Seeding Retail Products...")
        seeded_count = 0
        for item in DEFAULT_PRODUCTS:
            prod = db.query(Product).filter(Product.barcode == item["barcode"]).first()
            if not prod:
                prod = Product(**item)
                db.add(prod)
                seeded_count += 1
            else:
                # Update attributes if needed to keep in sync
                for key, val in item.items():
                    setattr(prod, key, val)

        logger.info(f"  + Added/Updated {len(DEFAULT_PRODUCTS)} products in catalog ({seeded_count} new).")

        logger.info("[Seed] Seeding Demo Order History...")
        demo_order = db.query(Order).filter(Order.order_id == "ORD-98421").first()
        if not demo_order:
            order_items = [
                {
                    "name": "Maggi 2-Minute Masala Noodles",
                    "quantity": 1,
                    "price": 52.00,
                    "original_price": 56.00,
                    "weight_grams": 204,
                },
                {
                    "name": "Amul Pasteurised Butter 500g",
                    "quantity": 1,
                    "price": 245.00,
                    "original_price": 275.00,
                    "weight_grams": 508,
                },
                {
                    "name": "Aashirvaad Shudh Chakki Atta 5kg",
                    "quantity": 1,
                    "price": 265.00,
                    "original_price": 320.00,
                    "weight_grams": 5010,
                },
            ]
            demo_order = Order(
                order_id="ORD-98421",
                user_id="U12345",
                cart_id="CART_01",
                store_name="D-Mart • HyperPulse HSR",
                total_mrp=651.00,
                total_paid=562.00,
                total_savings=89.00,
                items_count=3,
                payment_method="UPI_FASTPAY (PhonePe)",
                receipt_id="REC-892348",
                exit_token="PASS_CART_01_PAID_1729616400",
                status="Completed",
                items_json=json.dumps(order_items),
            )
            db.add(demo_order)
            logger.info("  + Created demo order: ORD-98421 (Paid ₹562.00, 3 items)")

        db.commit()
        logger.info("[Seed] Database seeding completed successfully!")

    except Exception as e:
        db.rollback()
        logger.error(f"[Seed] Error during seeding: {e}", exc_info=True)
        raise
    finally:
        db.close()


if __name__ == "__main__":
    seed_database()
