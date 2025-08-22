from flask import Flask, request, jsonify, redirect, url_for, render_template, flash
from flask_login import LoginManager, UserMixin, login_user, login_required, logout_user, current_user
from flask_wtf import FlaskForm
from wtforms import StringField, PasswordField, SubmitField
from wtforms.validators import DataRequired
from werkzeug.security import generate_password_hash, check_password_hash
import os, sqlite3
import json
from datetime import datetime
from dotenv import load_dotenv
load_dotenv()

app = Flask(__name__)
app.secret_key = os.environ.get("SECRET_KEY", "defaultsecret")

UPLOAD_FOLDER = "uploads"
DB_PATH = "photo_log.db"
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# ------------------ Auth Setup ------------------ #
login_manager = LoginManager()
login_manager.init_app(app)
login_manager.login_view = "login"

# Set admin user
users = {
    os.environ.get("ADMIN_USER", "admin"):
    generate_password_hash(os.environ.get("ADMIN_PASS", "adminpass"))
}

class User(UserMixin):
    def __init__(self, id):
        self.id = id

@login_manager.user_loader
def load_user(user_id):
    if user_id in users:
        return User(user_id)
    return None

class LoginForm(FlaskForm):
    username = StringField("Username", validators=[DataRequired()])
    password = PasswordField("Password", validators=[DataRequired()])
    submit = SubmitField("Login")

# ------------------ Routes ------------------ #
@app.route("/login", methods=["GET", "POST"])
def login():
    form = LoginForm()
    if form.validate_on_submit():
        username = form.username.data
        password = form.password.data
        if username in users and check_password_hash(users[username], password):
            login_user(User(username))
            return redirect(url_for("gallery"))
        else:
            flash("Invalid credentials.")
    return render_template("login.html", form=form)

@app.route("/logout")
@login_required
def logout():
    logout_user()
    return redirect(url_for("login"))

@app.route("/upload", methods=["POST"])
def upload():
    if 'image' not in request.files or 'timestamp' not in request.form:
        return "Missing image or timestamp", 400
    img = request.files['image']
    timestamp = request.form['timestamp']
    filename = datetime.now().strftime("%Y%m%d_%H%M%S_") + img.filename
    save_path = os.path.join(UPLOAD_FOLDER, filename)
    img.save(save_path)

    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute("INSERT INTO photos (filename, timestamp) VALUES (?, ?)", (filename, timestamp))
    conn.commit()
    conn.close()

    return "Uploaded", 200

@app.route("/photos", methods=["GET"])
@login_required
def get_photos():
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute("SELECT * FROM photos ORDER BY id DESC")
    photos = [{"id": row[0], "filename": row[1], "timestamp": row[2]} for row in c.fetchall()]
    conn.close()
    return jsonify(photos)

@app.route("/gallery")
@login_required
def gallery():
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute("SELECT id, filename, timestamp FROM photos ORDER BY id DESC")
    photos = [{"id": row[0], "filename": row[1], "timestamp": row[2]} for row in c.fetchall()]
    conn.close()
    return render_template("gallery.html", photos=photos, photos_json=json.dumps(photos, indent=2))

from flask import send_from_directory

@app.route("/uploads/<filename>")
@login_required
def serve_file(filename):
    return send_from_directory(os.path.join(app.root_path, 'uploads'), filename)

def init_db():
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute('''
        CREATE TABLE IF NOT EXISTS photos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            filename TEXT,
            timestamp TEXT
        )
    ''')
    conn.commit()
    conn.close()

if __name__ == "__main__":
    init_db()
    app.run(host="0.0.0.0", port=5000, ssl_context=("cert.pem", "key.pem"))

