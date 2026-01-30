from flask import Flask, render_template, request, redirect, url_for, session, jsonify
import psycopg2
import os
from datetime import datetime, timedelta
import secrets

app = Flask(__name__)
app.secret_key = os.getenv('SECRET_KEY', 'very-secret-key-for-session-2024')

# Database configuration
DB_CONFIG = {
    'host': os.getenv('DB_HOST', 'db'),
    'port': os.getenv('DB_PORT', '5432'),
    'database': os.getenv('DB_NAME', 'security_lab'),
    'user': os.getenv('DB_USER', 'dbadmin'),
    'password': os.getenv('DB_PASSWORD', 'SecurePass2024!')
}

def get_db_connection():
    """สร้าง connection ไปยัง PostgreSQL"""
    conn = psycopg2.connect(**DB_CONFIG)
    return conn

@app.route('/')
def index():
    """หน้าแรก"""
    if 'user_id' in session:
        return redirect(url_for('dashboard'))
    return redirect(url_for('login'))

@app.route('/login', methods=['GET', 'POST'])
def login():
    """หน้า Login - มีช่องโหว่ SQL Injection แบบง่าย"""
    if request.method == 'POST':
        username = request.form.get('username', '')
        password = request.form.get('password', '')
        
        conn = get_db_connection()
        cur = conn.cursor()
        
        # VULNERABLE: SQL Injection - ตั้งใจให้มีช่องโหว่
        # นักเรียนสามารถใช้ ' OR '1'='1 เพื่อ bypass login
        query = f"SELECT id, username, role FROM users WHERE username = '{username}' AND password = '{password}'"
        
        try:
            cur.execute(query)
            user = cur.fetchone()
            
            if user:
                session['user_id'] = user[0]
                session['username'] = user[1]
                session['role'] = user[2]
                
                # สร้าง session token
                session_token = secrets.token_hex(16)
                session['session_token'] = session_token
                
                # บันทึก session ลง database
                cur.execute(
                    "INSERT INTO sessions (user_id, session_token, expires_at, ip_address) VALUES (%s, %s, %s, %s)",
                    (user[0], session_token, datetime.now() + timedelta(hours=24), request.remote_addr)
                )
                conn.commit()
                
                cur.close()
                conn.close()
                return redirect(url_for('dashboard'))
            else:
                cur.close()
                conn.close()
                return render_template('login.html', error='Invalid username or password')
        except Exception as e:
            cur.close()
            conn.close()
            return render_template('login.html', error=f'Error: {str(e)}')
    
    return render_template('login.html')

@app.route('/signup', methods=['GET', 'POST'])
def signup():
    """หน้า Sign Up - ปกติไม่มีช่องโหว่"""
    if request.method == 'POST':
        username = request.form.get('username', '').strip()
        password = request.form.get('password', '')
        email = request.form.get('email', '').strip()
        full_name = request.form.get('full_name', '').strip()

        # ตรวจสอบข้อมูลว่าไม่ว่างเปล่า
        if not username or not password or not email or not full_name:
            return render_template('signup.html', error='กรุณากรอกข้อมูลให้ครบทุกช่อง')

        conn = get_db_connection()
        cur = conn.cursor()

        try:
            # ตรวจสอบว่า username ซ้ำหรือไม่
            cur.execute("SELECT id FROM users WHERE username = %s", (username,))
            if cur.fetchone():
                cur.close()
                conn.close()
                return render_template('signup.html', error='ชื่อผู้ใช้นี้ถูกใช้งานแล้ว กรุณาเลือกชื่อผู้ใช้อื่น')

            # ตรวจสอบว่า email ซ้ำหรือไม่
            cur.execute("SELECT id FROM users WHERE email = %s", (email,))
            if cur.fetchone():
                cur.close()
                conn.close()
                return render_template('signup.html', error='อีเมลนี้ถูกใช้งานแล้ว กรุณาใช้อีเมลอื่น')

            # ใช้ parameterized query (ปลอดภัย)
            cur.execute(
                "INSERT INTO users (username, password, email, full_name, role) VALUES (%s, %s, %s, %s, 'user') RETURNING id",
                (username, password, email, full_name)
            )
            user_id = cur.fetchone()[0]

            # สร้าง user profile ว่าง
            cur.execute(
                "INSERT INTO user_profiles (user_id, phone, address) VALUES (%s, '', '')",
                (user_id,)
            )

            conn.commit()
            cur.close()
            conn.close()

            # ไม่ auto-login หลัง signup เพื่อป้องกันปัญหา session persistence
            return redirect(url_for('login'))
        except Exception as e:
            conn.rollback()
            cur.close()
            conn.close()
            return render_template('signup.html', error='เกิดข้อผิดพลาดในการสมัครสมาชิก กรุณาลองใหม่อีกครั้ง')
    
    return render_template('signup.html')

@app.route('/dashboard')
def dashboard():
    """หน้า Dashboard - ต้อง login ก่อน"""
    if 'user_id' not in session:
        return redirect(url_for('login'))
    
    conn = get_db_connection()
    cur = conn.cursor()
    
    # ดึงข้อมูล user
    cur.execute("SELECT username, email, full_name, role FROM users WHERE id = %s", (session['user_id'],))
    user = cur.fetchone()
    
    # ดึงข้อมูลจังหวัดยอดนิยม
    cur.execute("SELECT id, name_th, slug, hotel_count FROM provinces WHERE is_popular = TRUE ORDER BY hotel_count DESC")
    popular_provinces = cur.fetchall()
    
    cur.close()
    conn.close()
    
    return render_template('dashboard.html', 
                          username=user[0], 
                          email=user[1], 
                          full_name=user[2], 
                          role=user[3],
                          session_token=session.get('session_token', 'N/A'),
                          popular_provinces=popular_provinces)

@app.route('/search', methods=['GET', 'POST'])
def search():
    """หน้าค้นหา User - มีช่องโหว่ SQL Injection Union Based สำหรับ Step 3"""
    if 'user_id' not in session:
        return redirect(url_for('login'))
    
    results = None
    search_query = ''
    error = None
    
    if request.method == 'POST':
        search_query = request.form.get('search', '')
        
        conn = get_db_connection()
        cur = conn.cursor()
        
        # VULNERABLE: SQL Injection Union Based
        # ตัวอย่างการโจมตี: ' UNION SELECT id, name, secret_flag, address FROM hotels--
        query = f"SELECT id, username, email, full_name FROM users WHERE username LIKE '%{search_query}%'"
        
        try:
            cur.execute(query)
            results = cur.fetchall()
            cur.close()
            conn.close()
        except Exception as e:
            error = str(e)
            cur.close()
            conn.close()
    
    return render_template('search.html', results=results, search_query=search_query, error=error)

@app.route('/provinces')
def provinces():
    """หน้าแสดงจังหวัดทั้งหมด"""
    if 'user_id' not in session:
        return redirect(url_for('login'))
    
    conn = get_db_connection()
    cur = conn.cursor()
    
    cur.execute("SELECT id, name_th, name_en, slug, description, hotel_count FROM provinces ORDER BY is_popular DESC, name_th")
    all_provinces = cur.fetchall()
    
    cur.close()
    conn.close()
    
    return render_template('provinces.html', provinces=all_provinces)

@app.route('/province/<slug>')
def province_detail(slug):
    """หน้ารายละเอียดจังหวัด - แสดงโรงแรมในจังหวัดนั้นๆ"""
    if 'user_id' not in session:
        return redirect(url_for('login'))
    
    conn = get_db_connection()
    cur = conn.cursor()
    
    # ดึงข้อมูลจังหวัด
    cur.execute("SELECT id, name_th, name_en, description FROM provinces WHERE slug = %s", (slug,))
    province = cur.fetchone()
    
    if not province:
        cur.close()
        conn.close()
        return "Province not found", 404
    
    # ดึงโรงแรมในจังหวัด
    cur.execute("""
        SELECT id, name, description, address, price_per_night, star_rating, amenities, is_available
        FROM hotels 
        WHERE province_id = %s AND is_available = TRUE
        ORDER BY star_rating DESC, price_per_night DESC
    """, (province[0],))
    hotels = cur.fetchall()
    
    cur.close()
    conn.close()
    
    return render_template('province_detail.html', 
                          province={
                              'id': province[0],
                              'name_th': province[1],
                              'name_en': province[2],
                              'description': province[3],
                              'slug': slug
                          },
                          hotels=hotels)

@app.route('/hotel/<int:hotel_id>')
def hotel_detail(hotel_id):
    """หน้ารายละเอียดโรงแรม"""
    if 'user_id' not in session:
        return redirect(url_for('login'))
    
    conn = get_db_connection()
    cur = conn.cursor()
    
    # ดึงข้อมูลโรงแรม
    cur.execute("""
        SELECT h.id, h.name, h.description, h.address, h.price_per_night, 
               h.star_rating, h.amenities, h.total_rooms, h.available_rooms,
               p.name_th, p.slug
        FROM hotels h
        JOIN provinces p ON h.province_id = p.id
        WHERE h.id = %s
    """, (hotel_id,))
    hotel = cur.fetchone()
    
    if not hotel:
        cur.close()
        conn.close()
        return "Hotel not found", 404
    
    # ดึงรีวิว
    cur.execute("""
        SELECT r.rating, r.comment, r.created_at, u.username
        FROM reviews r
        JOIN users u ON r.user_id = u.id
        WHERE r.hotel_id = %s
        ORDER BY r.created_at DESC
        LIMIT 10
    """, (hotel_id,))
    reviews = cur.fetchall()
    
    cur.close()
    conn.close()
    
    return render_template('hotel_detail.html',
                          hotel={
                              'id': hotel[0],
                              'name': hotel[1],
                              'description': hotel[2],
                              'address': hotel[3],
                              'price_per_night': hotel[4],
                              'star_rating': hotel[5],
                              'amenities': hotel[6],
                              'total_rooms': hotel[7],
                              'available_rooms': hotel[8],
                              'province_name': hotel[9],
                              'province_slug': hotel[10]
                          },
                          reviews=reviews)

@app.route('/book/<int:hotel_id>', methods=['GET', 'POST'])
def book_hotel(hotel_id):
    """หน้าจองโรงแรม"""
    if 'user_id' not in session:
        return redirect(url_for('login'))
    
    conn = get_db_connection()
    cur = conn.cursor()
    
    if request.method == 'POST':
        check_in = request.form.get('check_in')
        check_out = request.form.get('check_out')
        num_guests = int(request.form.get('num_guests', 1))
        special_requests = request.form.get('special_requests', '')
        
        # คำนวณจำนวนคืน
        check_in_date = datetime.strptime(check_in, '%Y-%m-%d')
        check_out_date = datetime.strptime(check_out, '%Y-%m-%d')
        num_nights = (check_out_date - check_in_date).days
        
        # ดึงราคาโรงแรม
        cur.execute("SELECT price_per_night FROM hotels WHERE id = %s", (hotel_id,))
        price_per_night = cur.fetchone()[0]
        total_price = price_per_night * num_nights
        
        # บันทึกการจอง
        cur.execute("""
            INSERT INTO bookings (user_id, hotel_id, check_in_date, check_out_date, 
                                num_guests, total_price, status, special_requests)
            VALUES (%s, %s, %s, %s, %s, %s, 'pending', %s)
            RETURNING id
        """, (session['user_id'], hotel_id, check_in, check_out, num_guests, total_price, special_requests))
        
        booking_id = cur.fetchone()[0]
        conn.commit()
        cur.close()
        conn.close()
        
        return redirect(url_for('booking_success', booking_id=booking_id))
    
    # ดึงข้อมูลโรงแรม
    cur.execute("SELECT id, name, price_per_night FROM hotels WHERE id = %s", (hotel_id,))
    hotel = cur.fetchone()
    
    cur.close()
    conn.close()
    
    if not hotel:
        return "Hotel not found", 404
    
    return render_template('book_hotel.html', hotel=hotel,
                           min_check_in=(datetime.now() + timedelta(days=1)).strftime('%Y-%m-%d'),
                           min_check_out=(datetime.now() + timedelta(days=2)).strftime('%Y-%m-%d'))

@app.route('/booking-success/<int:booking_id>')
def booking_success(booking_id):
    """หน้าแสดงผลการจองสำเร็จ"""
    if 'user_id' not in session:
        return redirect(url_for('login'))
    
    conn = get_db_connection()
    cur = conn.cursor()
    
    cur.execute("""
        SELECT b.id, h.name, b.check_in_date, b.check_out_date, 
               b.num_guests, b.total_price, b.status
        FROM bookings b
        JOIN hotels h ON b.hotel_id = h.id
        WHERE b.id = %s AND b.user_id = %s
    """, (booking_id, session['user_id']))
    
    booking = cur.fetchone()
    cur.close()
    conn.close()
    
    if not booking:
        return "Booking not found", 404
    
    return render_template('booking_success.html', booking=booking)

@app.route('/profile')
def profile():
    """หน้าโปรไฟล์ - แสดงข้อมูลส่วนตัว"""
    if 'user_id' not in session:
        return redirect(url_for('login'))
    
    conn = get_db_connection()
    cur = conn.cursor()
    
    # ดึงข้อมูลโปรไฟล์
    cur.execute("""
        SELECT u.username, u.email, u.full_name, u.role, 
               p.phone, p.address, p.credit_card, p.secret_note
        FROM users u
        LEFT JOIN user_profiles p ON u.id = p.user_id
        WHERE u.id = %s
    """, (session['user_id'],))
    
    profile = cur.fetchone()
    
    # ดึงการจองของผู้ใช้
    cur.execute("""
        SELECT b.id, h.name, b.check_in_date, b.check_out_date, 
               b.total_price, b.status, b.created_at
        FROM bookings b
        JOIN hotels h ON b.hotel_id = h.id
        WHERE b.user_id = %s
        ORDER BY b.created_at DESC
        LIMIT 10
    """, (session['user_id'],))
    
    bookings = cur.fetchall()
    
    cur.close()
    conn.close()
    
    if profile:
        profile_data = {
            'username': profile[0],
            'email': profile[1],
            'full_name': profile[2],
            'role': profile[3],
            'phone': profile[4],
            'address': profile[5],
            'credit_card': profile[6],
            'secret_note': profile[7]
        }
    else:
        profile_data = None
    
    return render_template('profile.html', profile=profile_data, bookings=bookings)

@app.route('/admin')
def admin():
    """หน้า Admin - เฉพาะ Admin เท่านั้น"""
    if 'user_id' not in session:
        return redirect(url_for('login'))
    
    if session.get('role') != 'admin':
        return "Access Denied! Admin only.", 403
    
    conn = get_db_connection()
    cur = conn.cursor()
    
    # แสดงข้อมูล users ทั้งหมด
    cur.execute("SELECT id, username, email, full_name, role, created_at FROM users ORDER BY id")
    all_users = cur.fetchall()
    
    # แสดง sessions ที่ active
    cur.execute("""
        SELECT s.id, u.username, s.session_token, s.created_at, s.expires_at, s.ip_address
        FROM sessions s
        JOIN users u ON s.user_id = u.id
        WHERE s.expires_at > NOW()
        ORDER BY s.created_at DESC
    """)
    active_sessions = cur.fetchall()
    
    # แสดง flags
    cur.execute("SELECT step, flag_name, flag_value, hint FROM flags ORDER BY step")
    flags = cur.fetchall()
    
    # สถิติระบบ
    cur.execute("SELECT COUNT(*) FROM users")
    total_users = cur.fetchone()[0]
    
    cur.execute("SELECT COUNT(*) FROM hotels")
    total_hotels = cur.fetchone()[0]
    
    cur.execute("SELECT COUNT(*) FROM bookings WHERE status = 'confirmed'")
    total_bookings = cur.fetchone()[0]
    
    cur.close()
    conn.close()
    
    return render_template('admin.html', 
                          users=all_users, 
                          sessions=active_sessions,
                          flags=flags,
                          stats={
                              'total_users': total_users,
                              'total_hotels': total_hotels,
                              'total_bookings': total_bookings
                          })

@app.route('/logout')
def logout():
    """Logout"""
    # ลบ session token ออกจาก database
    if 'session_token' in session:
        try:
            conn = get_db_connection()
            cur = conn.cursor()
            cur.execute("DELETE FROM sessions WHERE session_token = %s", (session['session_token'],))
            conn.commit()
            cur.close()
            conn.close()
        except:
            pass
    
    session.clear()
    return redirect(url_for('login'))

# API Endpoint สำหรับตรวจสอบ session (สำหรับ Session Hijacking Lab)
@app.route('/api/check-session')
def check_session():
    """API สำหรับตรวจสอบ session token"""
    token = request.args.get('token', '')
    
    if not token:
        return jsonify({'error': 'No token provided'}), 400
    
    conn = get_db_connection()
    cur = conn.cursor()
    
    cur.execute("""
        SELECT u.id, u.username, u.role 
        FROM sessions s
        JOIN users u ON s.user_id = u.id
        WHERE s.session_token = %s AND s.expires_at > NOW()
    """, (token,))
    
    result = cur.fetchone()
    cur.close()
    conn.close()
    
    if result:
        return jsonify({
            'valid': True,
            'user_id': result[0],
            'username': result[1],
            'role': result[2]
        })
    else:
        return jsonify({'valid': False}), 404

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
