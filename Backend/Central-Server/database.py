#!/usr/bin/env python3
"""
Central Store Server - Database Configuration & Session Management
High-concurrency SQLite connection with WAL journal mode and thread safety,
with seamless environment-variable override for PostgreSQL.
"""

import os
import logging
from typing import Generator
from sqlalchemy import create_engine, event
from sqlalchemy.orm import declarative_base, sessionmaker, Session

logger = logging.getLogger("CentralServer.Database")

# Database URL from environment, defaulting to local SQLite file
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./retail_store.db")

# Connection arguments: check_same_thread=False for SQLite multithreaded / async access
connect_args = {}
if "sqlite" in DATABASE_URL:
    connect_args = {"check_same_thread": False}

engine = create_engine(
    DATABASE_URL,
    connect_args=connect_args,
    pool_pre_ping=True,
    echo=False,
)

# Enable SQLite Write-Ahead Logging (WAL) and foreign keys for high-concurrency performance
if "sqlite" in DATABASE_URL:
    @event.listens_for(engine, "connect")
    def set_sqlite_pragma(dbapi_connection, connection_record):
        cursor = dbapi_connection.cursor()
        try:
            cursor.execute("PRAGMA journal_mode=WAL;")
            cursor.execute("PRAGMA synchronous=NORMAL;")
            cursor.execute("PRAGMA foreign_keys=ON;")
            cursor.execute("PRAGMA busy_timeout=5000;")
        finally:
            cursor.close()

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=True,
    bind=engine,
    expire_on_commit=False,
)

Base = declarative_base()


def get_db() -> Generator[Session, None, None]:
    """FastAPI dependency for yielding database session with automatic cleanup."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db() -> None:
    """Initialize database tables and indexes cleanly."""
    logger.info(f"[Database] Initializing tables for engine: {DATABASE_URL} ...")
    import models  # Ensure all models are registered on Base.metadata
    Base.metadata.create_all(bind=engine)
    logger.info("[Database] All tables initialized successfully.")
