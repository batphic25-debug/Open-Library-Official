from app.catalog import seed_catalog
from app.config import Config
from app.db import make_engine, make_session_factory


def main():
    engine = make_engine(Config.from_env().database_url)
    with make_session_factory(engine)() as db:
        print(f"Imported {seed_catalog(db)} books")
    engine.dispose()


if __name__ == "__main__":
    main()
