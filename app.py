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

# Improved HTML Template
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
    app.run(host='0.0.0.0', port=5000, debug=True)
