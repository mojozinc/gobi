from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy.orm import DeclarativeBase
from app.config import settings

# Create async engine
# Fallback gracefully for testing, Supabase, or development
db_url = settings.DATABASE_URL
if db_url.startswith("postgresql://"):
    db_url = db_url.replace("postgresql://", "postgresql+asyncpg://", 1)

# Supabase connection poolers (PgBouncer/Supavisor on port 6543) require statement_cache_size=0 with asyncpg
connect_args = {}
if "supabase" in db_url or "pooler" in db_url or ":6543" in db_url:
    connect_args["statement_cache_size"] = 0

engine = create_async_engine(
    db_url,
    connect_args=connect_args,
    echo=(settings.ENV == "development" and False),
    future=True,
)

AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False,
)

class Base(DeclarativeBase):
    pass

async def get_db():
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()
