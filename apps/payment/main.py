from src.app_factory import create_app

app = create_app()


if __name__ == "__main__":
    import uvicorn

    from src.config import settings

    uvicorn.run("main:app", host="0.0.0.0", port=settings.app_port, reload=False)
