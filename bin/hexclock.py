#!/usr/bin/env python3

import socket
from flask import Flask, render_template_string
from datetime import datetime

app = Flask(__name__)

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
    html = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Hex Clock Grid</title>
        <style>
            body {
                display:flex;
                flex-direction:column;
                justify-content:center;
                align-items:center;
                height:100vh;
                background:#111;
                margin:0;
                font-family:sans-serif;
            }
            #time-container {
                display:flex;
                flex-direction:column;
                align-items:center;
                margin-bottom:20px;
            }
            #time-display {
                font-size:32px;
                font-weight:bold;
                color:#fff;
            }
            #hex-display {
                font-size:24px;
                font-weight:bold;
                margin-top:4px;
            }
            #grid {
                display:grid;
                grid-template-columns: repeat({{cols}}, 40px);
                grid-template-rows: repeat({{rows}}, 40px);
                grid-gap:4px;
            }
            .cell {
                width:40px;
                height:40px;
                display:flex;
                justify-content:center;
                align-items:center;
                font-weight:bold;
                font-size:20px;
                color:#fff;
                border-radius:4px;
                background:#222;
                transition: background 0.2s;
            }
        </style>
    </head>
    <body>
        <div id="time-container">
            <div id="time-display">--:--:--</div>
            <div id="hex-display">--:--:--</div>
        </div>
        <div id="grid"></div>
        <script>
            const rows = {{rows}};
            const cols = {{cols}};
            const grid = document.getElementById("grid");
            const timeDisplay = document.getElementById("time-display");
            const hexDisplay = document.getElementById("hex-display");
            const hexGrid = {{hex_grid|safe}};

            const cells = [];
            for(let r=0;r<rows;r++){
                for(let c=0;c<cols;c++){
                    const cell = document.createElement("div");
                    cell.className = "cell";
                    cell.textContent = hexGrid[r][c];
                    grid.appendChild(cell);
                    cells.push({el: cell, row: r, col: c});
                }
            }

            async function updateGrid(){
                const res = await fetch('/time_hex');
                const data = await res.json();
                const hexColor = data.hex;
                const activeCells = data.active;
                const timeStr = data.time;
                const hexFormatted = data.hex_formatted;

                // dim all cells
                cells.forEach(cellObj => cellObj.el.style.backgroundColor = "#222");

                // light up active cells
                activeCells.forEach(c => {
                    const cellObj = cells.find(cell => cell.row === c[0] && cell.col === c[1]);
                    if(cellObj) cellObj.el.style.backgroundColor = "#" + hexColor;
                });

                // update time and hex displays
                timeDisplay.textContent = timeStr;
                hexDisplay.textContent = hexFormatted;
                hexDisplay.style.color = "#" + hexColor;  // set text color to match hex
            }

            updateGrid();
            setInterval(updateGrid, 1000);
        </script>
    </body>
    </html>
    """
    return render_template_string(html, rows=GRID_ROWS, cols=GRID_COLS, hex_grid=HEX_DIGITS)

@app.route('/time_hex')
def time_hex():
    hex_val, time_str, hex_formatted = get_time_rgb_hex()
    active_cells = get_active_cells(hex_val)
    return {"hex": hex_val, "active": active_cells, "time": time_str, "hex_formatted": hex_formatted}

if __name__ == "__main__":
    local_ip = socket.gethostbyname(socket.gethostname())
    app.run(host=local_ip, port=5000)
