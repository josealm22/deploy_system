from flask import Flask, request, jsonify, render_template
import sqlite3

app = Flask(__name__)

# 🔹 Conexión a la base de datos
def db_connection():
    return sqlite3.connect("deploy_system.db")

# 🔹 Página principal
@app.route("/")
def index():
    return render_template("index.html")

# 🔹 Registrar un dispositivo
@app.route("/register_device", methods=["POST"])
def register_device():
    data = request.json
    hostname = data.get("hostname")
    ip = data.get("ip")

    conn = db_connection()
    cursor = conn.cursor()
    cursor.execute("INSERT OR REPLACE INTO devices (hostname, ip, status) VALUES (?, ?, 'idle')", (hostname, ip))
    conn.commit()
    conn.close()
    
    return jsonify({"message": "Device registered"}), 200

# 🔹 Obtener tarea asignada a un equipo
@app.route("/get_task", methods=["GET"])
def get_task():
    hostname = request.args.get("hostname")

    conn = db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT task FROM devices WHERE hostname=?", (hostname,))
    task = cursor.fetchone()
    conn.close()

    return jsonify({"task": task[0] if task else ""}), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
