from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from typing import List, Literal
from pathlib import Path
import sys, json, numpy as np, torch, joblib
from sklearn.preprocessing import MinMaxScaler

# Ensure we can import model.py from same folder
from pathlib import Path as _P

sys.path.insert(0, str(_P(__file__).parent))

from model import LSTMForecaster

app = FastAPI(title="Forex LSTM Service", version="1.0")
MODELS_DIR = Path("/models")
DEVICE = "cpu"


# ---------- Schemas ----------
class TrainRequest(BaseModel):
    currency: str
    target: Literal["mid", "buy", "sell"] = "mid"
    horizon: int = Field(7, ge=1, le=30)
    window: int = Field(60, ge=10, le=365)
    values: List[float]
    dates: List[str] = []


class TrainResponse(BaseModel):
    currency: str
    target: str
    horizon: int
    trained_until: str
    tag: str


class PredictRequest(BaseModel):
    currency: str
    target: Literal["mid", "buy", "sell"] = "mid"
    horizon: int = Field(7, ge=1, le=30)
    window: int = Field(60, ge=10, le=365)
    recent_values: List[float]


class PredictResponse(BaseModel):
    currency: str
    target: str
    horizon: int
    yhat: List[float]


# ---------- Helpers ----------
def train_and_save(values, window, horizon, save_dir, tag):
    y = np.array(values, dtype=np.float32).reshape(-1, 1)
    scaler = MinMaxScaler()
    y_scaled = scaler.fit_transform(y)

    X, Y = [], []
    for i in range(len(y_scaled) - window - horizon + 1):
        X.append(y_scaled[i : i + window])
        Y.append(y_scaled[i + window + horizon - 1])
    if len(X) == 0:
        raise ValueError("not enough history for given window and horizon")

    X = np.array(X)
    Y = np.array(Y)
    dl = [(torch.tensor(X[i]), torch.tensor(Y[i])) for i in range(len(X))]
    model = LSTMForecaster()
    opt = torch.optim.Adam(model.parameters(), lr=1e-3)
    loss = torch.nn.MSELoss()
    for _ in range(25):
        for x, ytrue in dl:
            opt.zero_grad()
            yhat = model(x.unsqueeze(0))
            l = loss(yhat, ytrue.unsqueeze(0))
            l.backward()
            opt.step()

    save_dir.mkdir(parents=True, exist_ok=True)
    torch.save(model.state_dict(), save_dir / f"{tag}.pt")
    joblib.dump(scaler, save_dir / f"{tag}_scaler.pkl")
    return model, scaler


def load_artifacts(currency, target, horizon):
    tag = f"{currency.lower()}_{target}_h{horizon}"
    mp = MODELS_DIR / f"{tag}.pt"
    sp = MODELS_DIR / f"{tag}_scaler.pkl"
    jp = MODELS_DIR / f"{tag}.json"
    if not (mp.exists() and sp.exists() and jp.exists()):
        raise FileNotFoundError(tag)
    model = LSTMForecaster()
    model.load_state_dict(torch.load(mp, map_location=DEVICE))
    model.eval()
    scaler = joblib.load(sp)
    meta = json.loads(jp.read_text())
    return model, scaler, meta


# ---------- Routes ----------
@app.get("/healthz")
def healthz():
    return {"ok": True}


@app.post("/train", response_model=TrainResponse)
def train_endpoint(req: TrainRequest):
    MODELS_DIR.mkdir(parents=True, exist_ok=True)
    tag = f"{req.currency.lower()}_{req.target}_h{req.horizon}"
    try:
        train_and_save(req.values, req.window, req.horizon, MODELS_DIR, tag)
    except ValueError as e:
        raise HTTPException(400, str(e))
    trained_until = req.dates[-1] if req.dates else "unknown"
    meta = {"tag": tag, "trained_until": trained_until, "framework": "pytorch"}
    (MODELS_DIR / f"{tag}.json").write_text(json.dumps(meta))
    return TrainResponse(
        currency=req.currency.upper(),
        target=req.target,
        horizon=req.horizon,
        trained_until=trained_until,
        tag=tag,
    )


@app.get("/metadata")
def metadata(currency: str, target: str, horizon: int):
    _, _, meta = load_artifacts(currency, target, horizon)
    return meta


@app.post("/predict", response_model=PredictResponse)
def predict(req: PredictRequest):
    try:
        model, scaler, _ = load_artifacts(req.currency, req.target, req.horizon)
    except FileNotFoundError:
        raise HTTPException(
            404, f"artifacts for {req.currency}-{req.target}-h{req.horizon} not found"
        )

    arr = np.array(req.recent_values, dtype=np.float32).reshape(-1, 1)
    if len(arr) < req.window:
        raise HTTPException(400, f"need window={req.window} values")

    x_scaled = scaler.transform(arr)
    seq = x_scaled.copy()

    preds_scaled = []
    for _ in range(req.horizon):
        x = torch.tensor(seq[-req.window :], dtype=torch.float32).unsqueeze(0)
        with torch.no_grad():
            y_scaled = model(x).numpy().reshape(1, 1)
        preds_scaled.append(y_scaled[0, 0])
        seq = np.vstack([seq, y_scaled])

    preds = (
        scaler.inverse_transform(np.array(preds_scaled).reshape(-1, 1))
        .flatten()
        .tolist()
    )
    return {
        "currency": req.currency.upper(),
        "target": req.target,
        "horizon": req.horizon,
        "yhat": preds,
    }
