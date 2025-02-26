from flask import Flask, request, jsonify
import sqlite3

app = Flask(__name__)

def db_connection():
    return sqlite3.connect("/opt/deploy_system/deploy_system.db")

@app.route("/register_device", methods=["POST"])
def register_device():
    data = request.json
    hostname = data.get("hostname")
    ip = request.remote_addr  # Usar la IP de la petición HTTP

    # Convertir `ip` a string si es una lista
    if isinstance(ip, list):
        ip = ip[0]

    conn = db_connection()
    cursor = conn.cursor()
    cursor.execute("INSERT OR REPLACE INTO devices (hostname, ip, status) VALUES (?, ?, 'idle')", (hostname, ip))
    conn.commit()
    conn.close()
    
    return jsonify({"message": "Device registered", "hostname": hostname, "ip": ip}), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
