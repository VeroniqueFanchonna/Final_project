# 🏠 Real Estate Decision-Support System: Predictive Scoring for Modular Housing

## 📝 Project Overview

This project aims to identify "Launchpad" areas in France where traditional real estate is expensive but where modular housing (Tiny Houses, Container homes) offers a viable path to homeownership. By cross-referencing real estate transactions (**DVF**), public services density (**BPE**), and socio-economic indicators (**INSEE/IPS**), we provide a predictive score for over **9,000 municipalities**.

---

## 📁 Project Structure

* **`/app`**: Core API logic using FastAPI and SQLAlchemy.
* **`/notebooks`**: Data cleaning, Exploratory Data Analysis (EDA), and Machine Learning model training.
* **`/sql_scripts`**: Advanced SQL queries for data aggregation and table creation.

---

## ⚙️ Installation & Setup

### 1. Environment Configuration

Create a `.venv` and install the required dependencies:

```bash
pip install -r requirements.txt

```

### 2. Environment Variables

Create a `.env` file in the root directory (refer to `.env.template`):

```text
DB_USER=your_user
DB_PASSWORD=your_password
DB_HOST=127.0.0.1
DB_NAME=tiny_house_db
MY_API_KEY=your_secret_access_token

```
*Note: The API uses a secure token system for all data requests.
---

## 📊 Data Pipeline

1. **SQL Aggregation**: Data from DVF and BPE are joined to create a consolidated view of service density and real estate prices.
2. **Machine Learning**: A regression model is trained to predict the "potential score" based on income-to-price ratios and local amenities.
3. **Storage**: The final results are exported to the `final_market_predictive` table in MySQL for production use.

---

## 🚀 API Usage (REST Integration - C5)

The API is built with **FastAPI** to provide real-time access to our ML outcomes.

### Starting the server

```bash
uvicorn app.main:app --reload

```

### Interactive Documentation
Once the server is running, access the auto-generated **Swagger UI** at:
👉 [http://127.0.0.1:8000/docs](https://www.google.com/search?q=http://127.0.0.1:8000/docs)

### Main Endpoints
* **`GET /health`**: Checks the connection between the API and the MySQL database.
* **`GET /commune/{insee_code}`**: Returns specific predictive data (price/m², income, and attractiveness score) for a given city.
* **`GET /communes/list/all`**: Lists available cities in the database (default limit: 100).

---

## 🛡️ Security & Robustness
* **API Key Authentication**: All data-sensitive routes are protected by a header-based `access_token`.
* **Error Handling**: The system includes a custom logger and explicit HTTP exception management (403, 404, 500) to ensure high reliability.

