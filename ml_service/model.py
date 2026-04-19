import torch
from torch import nn


class LSTMForecaster(nn.Module):
    def __init__(self, input_size=1, hidden_size=64, num_layers=2, dropout=0.2):
        super().__init__()
        self.lstm = nn.LSTM(
            input_size, hidden_size, num_layers, dropout=dropout, batch_first=True
        )
        self.head = nn.Sequential(
            nn.Linear(hidden_size, 64), nn.ReLU(), nn.Linear(64, 1)
        )

    def forward(self, x):
        out, _ = self.lstm(x)  # (B, T, H)
        out = out[:, -1, :]  # last step
        return self.head(out)  # (B, 1)
