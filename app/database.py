import sqlite3

def init_db():
    conn = sqlite3.connect("deploy_system.db")
    cursor = conn.cursor()

    cursor.execute('''
    CREATE TABLE IF NOT EXISTS devices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        hostname TEXT UNIQUE,
        ip TEXT,
        status TEXT DEFAULT 'idle',
        task TEXT DEFAULT NULL
    )
    ''')

    conn.commit()
    conn.close()

if __name__ == "__main__":
    init_db()
