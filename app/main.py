from flask import Flask, jsonify
import os

app = Flask(__name__)

@app.route('/health')
def health_check():
    return jsonify({
        "status": "fully operational",
        "service": "DevSecOps Server Monitor",
        "environment": os.getenv("ENV", "production")
    })

if __name__ == '__main__':
    # Running on port 8080 to avoid conflicts with reserved system ports
    app.run(host='0.0.0.0', port=8080)