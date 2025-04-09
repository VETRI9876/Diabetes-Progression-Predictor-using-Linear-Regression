#!/bin/bash

# Update and install required packages
sudo apt update && sudo apt upgrade -y
sudo apt install python3 python3-pip python3-venv nginx -y

# Create a directory for the Flask app
mkdir -p ~/flaskapp
cd ~/flaskapp

# Create and activate virtual environment
python3 -m venv venv
source venv/bin/activate

# Install Python dependencies
pip install flask gunicorn scikit-learn

# Create app.py
cat << 'EOF' > app.py
from flask import Flask, request, jsonify, render_template_string
from sklearn.datasets import load_diabetes
from sklearn.linear_model import LinearRegression
import numpy as np

app = Flask(__name__)

# Train model
diabetes = load_diabetes()
X = diabetes.data[:, 2].reshape(-1, 1)
y = diabetes.target
model = LinearRegression()
model.fit(X, y)

# HTML Template
html_template = """
<!doctype html>
<html>
<head>
    <title>SLR BMI Prediction</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background: #f4f6f8;
            display: flex;
            height: 100vh;
            align-items: center;
            justify-content: center;
        }
        .container {
            background: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 0 10px rgba(0,0,0,0.1);
            text-align: center;
        }
        input[type="number"], input[type="submit"] {
            padding: 10px;
            margin-top: 10px;
            font-size: 16px;
        }
        input[type="submit"] {
            background-color: #007BFF;
            border: none;
            color: white;
            cursor: pointer;
            border-radius: 5px;
        }
        input[type="submit"]:hover {
            background-color: #0056b3;
        }
        h2, h3 {
            color: #333;
        }
    </style>
</head>
<body>
    <div class="container">
        <h2>Enter BMI to Predict Diabetes Progression</h2>
        <form method="post" action="/predict">
            <input type="number" step="any" name="bmi" placeholder="Enter BMI" required value="{{ bmi or '' }}">
            <br>
            <input type="submit" value="Predict">
        </form>
        {% if prediction %}
            <h3>Prediction Result: {{ prediction }}</h3>
        {% endif %}
    </div>
</body>
</html>
"""

@app.route('/')
def home():
    return render_template_string(html_template)

@app.route('/predict', methods=['POST'])
def predict():
    try:
        if request.is_json:
            bmi = float(request.get_json()['bmi'])
            prediction = model.predict(np.array([[bmi]]))
            return jsonify({'prediction': prediction[0]})
        else:
            bmi = float(request.form['bmi'])
            prediction = model.predict(np.array([[bmi]]))
            return render_template_string(html_template, prediction=round(prediction[0], 2), bmi=bmi)
    except Exception as e:
        return render_template_string(html_template, prediction=f"Error: {e}", bmi=request.form.get('bmi', ''))

if __name__ == '__main__':
    app.run(debug=True)
EOF

# Create Gunicorn systemd service
sudo tee /etc/systemd/system/flaskapp.service > /dev/null <<EOF
[Unit]
Description=Gunicorn instance to serve Flask App
After=network.target

[Service]
User=ubuntu
Group=www-data
WorkingDirectory=/home/ubuntu/flaskapp
Environment="PATH=/home/ubuntu/flaskapp/venv/bin"
ExecStart=/home/ubuntu/flaskapp/venv/bin/gunicorn --workers 3 --bind 127.0.0.1:8000 app:app

[Install]
WantedBy=multi-user.target
EOF

# Start and enable Gunicorn
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl start flaskapp
sudo systemctl enable flaskapp

# Configure Nginx
sudo tee /etc/nginx/sites-available/flaskapp > /dev/null <<EOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:8000;
        include proxy_params;
        proxy_redirect off;
    }
}
EOF

# Enable new site config and restart Nginx
sudo ln -s /etc/nginx/sites-available/flaskapp /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl restart nginx

echo "🚀 Flask app deployed! Visit http://<your-lightsail-public-ip>"
