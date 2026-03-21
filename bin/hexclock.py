#!/usr/bin/env python3

from flask import Flask, render_template
from datetime import datetime

app = Flask(__name__, template_folder='templates')

GRID_ROWS = 16
GRID_COLS = 6

HEX_DIGITS = [[hex(15 - r)[2:].upper() for _ in range(GRID_COLS)] for r in range(GRID_ROWS)]

def get_time_rgb_hex():
    now = datetime.now()  # local time
    r = int((now.hour / 23) * 255)
    g = int((now.minute / 59) * 255)
    b = int((now.second / 59) * 255)
    hex_val = f"{r:02X}{g:02X}{b:02X}"
    time_str = now.strftime("%H:%M:%S")
    hex_formatted = f"{hex_val[0:2]}:{hex_val[2:4]}:{hex_val[4:6]}"
    return hex_val, time_str, hex_formatted

def get_active_cells(hex_val):
    active = []
    mapping = [(hex_val[0],0), (hex_val[1],1),
               (hex_val[2],2), (hex_val[3],3),
               (hex_val[4],4), (hex_val[5],5)]
    for hex_char, col in mapping:
        for r in range(GRID_ROWS):
            if HEX_DIGITS[r][col] == hex_char.upper():
                active.append((r, col))
                break
    return active

@app.route('/')
def index():
    return render_template('hexclock.html', rows=GRID_ROWS, cols=GRID_COLS, hex_grid=HEX_DIGITS)

@app.route('/time_hex')
def time_hex():
    hex_val, time_str, hex_formatted = get_time_rgb_hex()
    active_cells = get_active_cells(hex_val)
    return {"hex": hex_val, "active": active_cells, "time": time_str, "hex_formatted": hex_formatted}

if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5000)
