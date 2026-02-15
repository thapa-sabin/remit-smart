from fastapi import FastAPI

app = FastAPI(title="Forex LSTM Service", version="1.0")


@app.get("/healthz")
def healthz():
    return {"ok": True}
