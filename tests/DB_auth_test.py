import pyodbc
import sys
import os
from dotenv import load_dotenv

load_dotenv()

server = os.getenv('DB_SERVER')
database = os.getenv('DB_DATABASE')
username = os.getenv('DB_USERNAME')

connectionString = (
    f"Driver={{ODBC Driver 18 for SQL Server}};"
    f"Server=tcp:{server}.database.windows.net,1433;"
    f"Database={database};"
    f"Uid={username};"
    "Encrypt=yes;"
    "TrustServerCertificate=no;"
    "Connection Timeout=30;"
    "Authentication=ActiveDirectoryIntegrated"
)

def test_connection():
    print(f"Attempting to connect to {server}...")
    try:
        # connect to DB
        with pyodbc.connect(connectionString) as conn:
            print("Successfully connected to the database!")
            
            # Run a simple query to prove it works
            cursor = conn.cursor()
            cursor.execute("SELECT @@VERSION")
            row = cursor.fetchone()
            
            print("\n--- Database Info ---")
            print(f"SQL Version: {row[0]}")
            
    except pyodbc.Error as e:
        # Get the SQL state and error message
        sqlstate = e.args[0]
        print("\nConnection Failed!")
        print(f"SQL State: {sqlstate}")
        print(f"Error Details: {e}")
        
        if "IP address" in str(e):
            print("\nTIP: Check your Azure SQL Firewall settings. Your IP may be blocked.")
        elif "Login failed" in str(e):
            print("\nTIP: Double-check your username and password.")

if __name__ == "__main__":
    test_connection()