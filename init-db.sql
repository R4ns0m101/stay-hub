-- =====================================================
-- StayHub Database Schema
-- สำหรับการสอน SQL Injection Lab
-- =====================================================

-- ลบ tables เก่าถ้ามี
DROP TABLE IF EXISTS bookings CASCADE;
DROP TABLE IF EXISTS reviews CASCADE;
DROP TABLE IF EXISTS hotels CASCADE;
DROP TABLE IF EXISTS provinces CASCADE;
DROP TABLE IF EXISTS sessions CASCADE;
DROP TABLE IF EXISTS user_profiles CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS flags CASCADE;

-- สร้าง extension สำหรับ UUID
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- ตาราง users - เก็บข้อมูลผู้ใช้
-- =====================================================
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL, -- ในความเป็นจริงควร hash แต่เพื่อการสอนเราเก็บ plain text
    email VARCHAR(100) UNIQUE NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    role VARCHAR(20) DEFAULT 'user', -- user, admin
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- ตาราง user_profiles - ข้อมูลส่วนตัวเพิ่มเติม
-- =====================================================
CREATE TABLE user_profiles (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    phone VARCHAR(20),
    address TEXT,
    credit_card VARCHAR(19), -- เก็บแบบ plain text เพื่อการสอน (ห้ามทำในของจริง!)
    secret_note TEXT, -- ข้อมูลลับที่จะถูกเปิดเผยผ่าน SQL Injection
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- ตาราง sessions - เก็บ session tokens
-- =====================================================
CREATE TABLE sessions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    session_token VARCHAR(255) UNIQUE NOT NULL,
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL
);

-- =====================================================
-- ตาราง provinces - จังหวัดท่องเที่ยว
-- =====================================================
CREATE TABLE provinces (
    id SERIAL PRIMARY KEY,
    name_th VARCHAR(100) NOT NULL,
    name_en VARCHAR(100) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL, -- สำหรับ URL
    description TEXT,
    image_url VARCHAR(255),
    is_popular BOOLEAN DEFAULT FALSE,
    hotel_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- ตาราง hotels - โรงแรม
-- =====================================================
CREATE TABLE hotels (
    id SERIAL PRIMARY KEY,
    province_id INTEGER REFERENCES provinces(id) ON DELETE CASCADE,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    address TEXT,
    price_per_night DECIMAL(10,2) NOT NULL,
    star_rating INTEGER CHECK (star_rating >= 1 AND star_rating <= 5),
    amenities TEXT[], -- Array ของสิ่งอำนวยความสะดวก
    image_url VARCHAR(255),
    is_available BOOLEAN DEFAULT TRUE,
    total_rooms INTEGER DEFAULT 10,
    available_rooms INTEGER DEFAULT 10,
    -- Hidden flag สำหรับ SQL Injection challenge
    secret_flag VARCHAR(255), 
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- ตาราง bookings - การจองห้องพัก
-- =====================================================
CREATE TABLE bookings (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    hotel_id INTEGER REFERENCES hotels(id) ON DELETE CASCADE,
    check_in_date DATE NOT NULL,
    check_out_date DATE NOT NULL,
    num_guests INTEGER DEFAULT 1,
    total_price DECIMAL(10,2) NOT NULL,
    status VARCHAR(20) DEFAULT 'pending', -- pending, confirmed, cancelled
    special_requests TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- ตาราง reviews - รีวิวโรงแรม
-- =====================================================
CREATE TABLE reviews (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    hotel_id INTEGER REFERENCES hotels(id) ON DELETE CASCADE,
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- ตาราง flags - เก็บ flags สำหรับ CTF challenges
-- =====================================================
CREATE TABLE flags (
    id SERIAL PRIMARY KEY,
    step INTEGER NOT NULL,
    flag_name VARCHAR(100) NOT NULL,
    flag_value VARCHAR(255) NOT NULL,
    hint TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- Insert ข้อมูลเริ่มต้น
-- =====================================================

-- ใส่ผู้ใช้ตัวอย่าง
INSERT INTO users (username, password, email, full_name, role) VALUES
('admin', 'admin123', 'admin@stayhub.com', 'ผู้ดูแลระบบ', 'admin'),
('johndoe', 'password123', 'john@example.com', 'John Doe', 'user'),
('janedoe', 'jane2024', 'jane@example.com', 'Jane Doe', 'user'),
('somchai', 'somchai99', 'somchai@email.com', 'สมชาย ใจดี', 'user'),
('somying', 'ying2024', 'somying@email.com', 'สมหญิง สวยงาม', 'user');

-- ใส่ข้อมูลโปรไฟล์
INSERT INTO user_profiles (user_id, phone, address, credit_card, secret_note) VALUES
(1, '02-123-4567', '123 ถนนสุขุมวิท กรุงเทพฯ', '4532-1234-5678-9010', 'ADMIN_SECRET: รหัสผ่านหลักของระบบคือ RootAccess2024!'),
(2, '081-234-5678', '456 Silom Road, Bangkok', '5412-3456-7890-1234', 'My secret vacation spot is Maldives'),
(3, '089-345-6789', '789 Sukhumvit Rd, Bangkok', '4916-7890-1234-5678', 'Remember: Anniversary is June 15th'),
(4, '092-456-7890', '321 ถนนพระราม 4 กรุงเทพฯ', '6011-2345-6789-0123', 'บัญชีธนาคารลับ: 123-456-7890'),
(5, '093-567-8901', '654 ถนนเพชรบุรี กรุงเทพฯ', '3782-8224-6310-005', 'รหัส PIN บัตร ATM: 1234 (อย่าบอกใคร!)');

-- ใส่จังหวัด
INSERT INTO provinces (name_th, name_en, slug, description, image_url, is_popular, hotel_count) VALUES
('กรุงเทพมหานคร', 'Bangkok', 'bangkok', 'เมืองหลวงที่คึกคักพร้อมวัดวาอารามและตลาดริมน้ำ', 'https://images.unsplash.com/photo-1508009603885-50cf7c579365?w=800&h=600&fit=crop', TRUE, 234),
('ภูเก็ต', 'Phuket', 'phuket', 'เกาะสวรรค์แห่งทะเลอันดามันพร้อมชายหาดสวยงาม', 'https://images.unsplash.com/photo-1589394815804-964ed0be2eb5?w=800&h=600&fit=crop', TRUE, 189),
('เชียงใหม่', 'Chiang Mai', 'chiangmai', 'เมืองท่องเที่ยวทางภาคเหนือที่เต็มไปด้วยวัฒนธรรมล้านนา', 'https://images.unsplash.com/photo-1598935898639-81586f7d2129?w=800&h=600&fit=crop', TRUE, 156),
('พัทยา', 'Pattaya', 'pattaya', 'เมืองตากอากาศชายทะเลที่มีชีวิตชีวาตลอด 24 ชั่วโมง', 'https://images.unsplash.com/photo-1540541338287-41700207dee6?w=800&h=600&fit=crop', TRUE, 198),
('เกาะสมุย', 'Koh Samui', 'kohsamui', 'เกาะเขตร้อนในอ่าวไทยพร้อมรีสอร์ทหรูหรา', 'https://images.unsplash.com/photo-1537956965359-7573183d1f57?w=800&h=600&fit=crop', TRUE, 123);

-- ใส่โรงแรมในกรุงเทพฯ (พร้อม SECRET FLAG!)
INSERT INTO hotels (province_id, name, description, address, price_per_night, star_rating, amenities, image_url, is_available, secret_flag) VALUES
(1, 'Grand Palace Hotel Bangkok', 'โรงแรมหรูใกล้พระบรมมหาราชวัง พร้อมบริการระดับ 5 ดาว', '123 ถนนเจ้าฟ้า เขตพระนคร กรุงเทพฯ 10200', 3500.00, 5, ARRAY['WiFi ฟรี', 'สระว่ายน้ำ', 'ฟิตเนส', 'สปา', 'ร้านอาหาร'], 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800&h=600&fit=crop', TRUE, NULL),
(1, 'Riverside Boutique Hotel', 'โรงแรมบูติกริมแม่น้ำเจ้าพระยา วิวสวยงาม', '456 ถนนเจริญกรุง เขตบางรัก กรุงเทพฯ 10500', 2800.00, 4, ARRAY['WiFi ฟรี', 'ร้านอาหาร', 'บาร์ริมน้ำ', 'รับส่งสนามบิน'], 'https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=800&h=600&fit=crop', TRUE, NULL),
(1, 'Sukhumvit Business Hotel', 'โรงแรมใจกลางเมือง เหมาะสำหรับนักธุรกิจ', '789 ถนนสุขุมวิท เขตคลองเตย กรุงเทพฯ 10110', 2200.00, 4, ARRAY['WiFi ฟรี', 'ห้องประชุม', 'ฟิตเนส', 'ร้านกาแฟ'], 'https://images.unsplash.com/photo-1564501049412-61c2a3083791?w=800&h=600&fit=crop', TRUE, NULL),
(1, 'Silom Garden Resort', 'รีสอร์ทสไตล์สวนในเมือง บรรยากาศสงบ', '321 ซอยสีลม 5 เขตบางรัก กรุงเทพฯ 10500', 1800.00, 3, ARRAY['WiFi ฟรี', 'สวนสวย', 'ที่จอดรถ'], 'https://images.unsplash.com/photo-1582719508461-905c673771fd?w=800&h=600&fit=crop', TRUE, NULL),
(1, 'Secret Flag Hotel', 'โรงแรมปริศนาที่ซ่อนความลับอันมืดมน... 🚩', '999 ถนนลับ เขตลับ กรุงเทพฯ 10999', 9999.00, 5, ARRAY['WiFi ฟรี', 'ข้อมูลลับ', 'แฮกเกอร์เท่านั้น'], 'https://images.unsplash.com/photo-1551882547-ff40c63fe5fa?w=800&h=600&fit=crop', TRUE, 'FLAG{union_select_master_bangkok_2024}');

-- ใส่โรงแรมในภูเก็ต (พร้อม FLAG!)
INSERT INTO hotels (province_id, name, description, address, price_per_night, star_rating, amenities, image_url, is_available, secret_flag) VALUES
(2, 'Patong Beach Resort', 'รีสอร์ทหรูริมหาดป่าตอง วิวทะเลสวยงาม', '123 ถนนบางลา ตำบลป่าตอง อำเภอกะทู้ ภูเก็ต 83150', 4500.00, 5, ARRAY['WiFi ฟรี', 'สระว่ายน้ำ', 'ชายหาดส่วนตัว', 'สปา'], 'https://images.unsplash.com/photo-1571896349842-33c89424de2d?w=800&h=600&fit=crop', TRUE, NULL),
(2, 'Kata Villa Boutique', 'วิลล่าส่วนตัวบนเนินเขา วิวทะเลแบบพาโนรามา', '456 หาดกะตะ ตำบลกะรน อำเภอเมือง ภูเก็ต 83100', 3800.00, 4, ARRAY['WiFi ฟรี', 'สระส่วนตัว', 'ครัว', 'รับส่งสนามบิน'], 'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=800&h=600&fit=crop', TRUE, NULL),
(2, 'Phuket Old Town Hotel', 'โรงแรมในเมืองเก่าภูเก็ต บรรยากาศโนสทัลเจีย', '789 ถนนถลาง ตำบลตลาดใหญ่ อำเภอเมือง ภูเก็ต 83000', 1900.00, 3, ARRAY['WiFi ฟรี', 'ร้านอาหาร', 'ที่จอดรถ'], 'https://images.unsplash.com/photo-1445019980597-93fa8acb246c?w=800&h=600&fit=crop', TRUE, NULL),
(2, 'Rawai Beachfront Villa', 'วิลล่าหรูหน้าหาดราไวย์ เหมาะสำหรับครอบครัว', '321 หาดราไวย์ ตำบลราไวย์ อำเภอเมือง ภูเก็ต 83130', 5200.00, 5, ARRAY['WiFi ฟรี', 'สระว่ายน้ำ', 'ครัวครบครัน', 'พนักงานส่วนตัว'], 'https://images.unsplash.com/photo-1499793983690-e29da59ef1c2?w=800&h=600&fit=crop', TRUE, NULL),
(2, 'Hidden Treasure Resort Phuket', 'รีสอร์ทลับที่ซ่อนสมบัติทะเล 🏴‍☠️', '888 เกาะลับ ภูเก็ต 88888', 8888.00, 5, ARRAY['WiFi ฟรี', 'ขุมทรัพย์', 'แผนที่ลับ'], 'https://images.unsplash.com/photo-1540541338287-41700207dee6?w=800&h=600&fit=crop', TRUE, 'FLAG{sql_injection_beaches_paradise_phuket}');

-- ใส่โรงแรมในเชียงใหม่ (พร้อม FLAG!)
INSERT INTO hotels (province_id, name, description, address, price_per_night, star_rating, amenities, image_url, is_available, secret_flag) VALUES
(3, 'Chiang Mai Mountain Resort', 'รีสอร์ทบนเขาพร้อมวิวหุบเขาสวยงาม', '123 ถนนห้วยแก้ว ตำบลสุเทพ อำเภอเมือง เชียงใหม่ 50200', 2800.00, 4, ARRAY['WiFi ฟรี', 'สระว่ายน้ำ', 'ร้านอาหาร', 'กิจกรรมธรรมชาติ'], 'https://images.unsplash.com/photo-1596178065887-1198b6148b2b?w=800&h=600&fit=crop', TRUE, NULL),
(3, 'Old City Lanna Boutique', 'โรงแรมบูติกในเมืองเก่า สถาปัตยกรรมล้านนา', '456 ถนนราชดำเนิน ตำบลพระสิงห์ อำเภอเมือง เชียงใหม่ 50200', 2200.00, 4, ARRAY['WiFi ฟรี', 'สวนสวย', 'ร้านกาแฟ'], 'https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?w=800&h=600&fit=crop', TRUE, NULL),
(3, 'Nimman Modern Hotel', 'โรงแรมโมเดิร์นในย่านนิมมาน ใกล้ร้านอาหารและคาเฟ่', '789 ถนนนิมมานเหมินท์ ตำบลสุเทพ อำเภอเมือง เชียงใหม่ 50200', 1500.00, 3, ARRAY['WiFi ฟรี', 'ที่จอดรถ', 'ห้องอาหารเช้า'], 'https://images.unsplash.com/photo-1618773928121-c32242e63f39?w=800&h=600&fit=crop', TRUE, NULL),
(3, 'Doi Suthep View Resort', 'รีสอร์ทวิวดอยสุเทพ อากาศเย็นสบาย', '321 ถนนดอยสุเทพ ตำบลสุเทพ อำเภอเมือง เชียงใหม่ 50200', 3200.00, 5, ARRAY['WiFi ฟรี', 'สระว่ายน้ำ', 'สปา', 'กิจกรรมเดินป่า'], 'https://images.unsplash.com/photo-1615460549969-36fa19521a4f?w=800&h=600&fit=crop', TRUE, NULL),
(3, 'Lanna Secret Temple Hotel', 'โรงแรมลับแล้งในป่าใกล้วัดโบราณ 🏯', '777 ป่าลึก เชียงใหม่ 77777', 7777.00, 5, ARRAY['WiFi ฟรี', 'วัดลับ', 'สมาธิ'], 'https://images.unsplash.com/photo-1578683010236-d716f9a3f461?w=800&h=600&fit=crop', TRUE, 'FLAG{lanna_temple_secret_data_dump}');

-- ใส่โรงแรมในพัทยา (พร้อม FLAG!)
INSERT INTO hotels (province_id, name, description, address, price_per_night, star_rating, amenities, image_url, is_available, secret_flag) VALUES
(4, 'Pattaya Beach Tower', 'โรงแรมระฟ้าติดหาด วิวพาโนรามา 360 องศา', '123 ถนนหาดพัทยา ตำบลหนองปรือ อำเภอบางละมุง ชลบุรี 20150', 3200.00, 5, ARRAY['WiFi ฟรี', 'สระว่ายน้ำ', 'ฟิตเนส', 'ร้านอาหาร'], 'https://images.unsplash.com/photo-1455587734955-081b22074882?w=800&h=600&fit=crop', TRUE, NULL),
(4, 'Jomtien Family Resort', 'รีสอร์ทสำหรับครอบครัว หาดจอมเทียน', '456 ถนนหาดจอมเทียน ตำบลหนองปรือ อำเภอบางละมุง ชลบุรี 20150', 2400.00, 4, ARRAY['WiFi ฟรี', 'สระว่ายน้ำ', 'สนามเด็กเล่น', 'ที่จอดรถ'], 'https://images.unsplash.com/photo-1561501900-3701fa6a0864?w=800&h=600&fit=crop', TRUE, NULL),
(4, 'Walking Street Hotel', 'โรงแรมใจกลางย่านบันเทิง เดินสองก้าวถึง Walking Street', '789 ถนนวอล์คกิ้งสตรีท ตำบลหนองปรือ อำเภอบางละมุง ชลบุรี 20150', 1800.00, 3, ARRAY['WiFi ฟรี', 'บาร์', 'ห้องคาราโอเกะ'], 'https://images.unsplash.com/photo-1529290130-4ca3753253ae?w=800&h=600&fit=crop', TRUE, NULL),
(4, 'Naklua Quiet Resort', 'รีสอร์ทเงียบสงบย่านนาเกลือ ห่างจากความวุ่นวาย', '321 ถนนนาเกลือ ตำบลนาเกลือ อำเภอบางละมุง ชลบุรี 20150', 2000.00, 4, ARRAY['WiFi ฟรี', 'สระว่ายน้ำ', 'สวนสวย'], 'https://images.unsplash.com/photo-1584132967334-10e028bd69f7?w=800&h=600&fit=crop', TRUE, NULL),
(4, 'Pattaya Underground Club Hotel', 'โรงแรมใต้ดินที่เก็บงานปาร์ตี้ลับ 🎭', '666 ใต้ดิน พัทยา 66666', 6666.00, 5, ARRAY['WiFi ฟรี', 'คลับใต้ดิน', 'VIP เท่านั้น'], 'https://images.unsplash.com/photo-1590490360182-c33d955f4e24?w=800&h=600&fit=crop', TRUE, 'FLAG{nightlife_database_breach_pattaya}');

-- ใส่โรงแรมในเกาะสมุย (พร้อม FLAG!)
INSERT INTO hotels (province_id, name, description, address, price_per_night, star_rating, amenities, image_url, is_available, secret_flag) VALUES
(5, 'Chaweng Luxury Resort', 'รีสอร์ทหรูหน้าหาดเฉวง วิวพระอาทิตย์ตก', '123 หาดเฉวง ตำบลบ่อผุด อำเภอเกาะสมุย สุราษฎร์ธานี 84320', 5500.00, 5, ARRAY['WiFi ฟรี', 'สระว่ายน้ำ', 'สปา', 'ชายหาดส่วนตัว'], 'https://images.unsplash.com/photo-1573052905904-34ad8c27f0cc?w=800&h=600&fit=crop', TRUE, NULL),
(5, 'Lamai Beach Villa', 'วิลล่าส่วนตัวหาดละไม พร้อมสระส่วนตัว', '456 หาดละไม ตำบลมะเร็ต อำเภอเกาะสมุย สุราษฎร์ธานี 84310', 4200.00, 5, ARRAY['WiFi ฟรี', 'สระส่วนตัว', 'ครัว', 'บัตเลอร์ส่วนตัว'], 'https://images.unsplash.com/photo-1602002418816-5c0aeef426aa?w=800&h=600&fit=crop', TRUE, NULL),
(5, 'Bophut Fisherman Village Hotel', 'โรงแรมในหมู่บ้านชาวประมง บรรยากาศดั้งเดิม', '789 หาดบ่อผุด ตำบลบ่อผุด อำเภอเกาะสมุย สุราษฎร์ธานี 84320', 2600.00, 4, ARRAY['WiFi ฟรี', 'ร้านอาหารริมทะเล', 'ตลาดเดิน'], 'https://images.unsplash.com/photo-1551918120-9739cb430c6d?w=800&h=600&fit=crop', TRUE, NULL),
(5, 'Mae Nam Peaceful Resort', 'รีสอร์ทเงียบสงบหาดแม่น้ำ เหมาะพักผ่อน', '321 หาดแม่น้ำ ตำบลแม่น้ำ อำเภอเกาะสมุย สุราษฎร์ธานี 84330', 3000.00, 4, ARRAY['WiFi ฟรี', 'สระว่ายน้ำ', 'สวนมะพร้าว'], 'https://images.unsplash.com/photo-1586611292717-f828b167408c?w=800&h=600&fit=crop', TRUE, NULL),
(5, 'Island Secret Paradise', 'รีสอร์ทลับกลางเกาะที่มีเพียงคนพิเศษเท่านั้นที่รู้ 🏝️', '555 เกาะลับ สมุย 55555', 9999.00, 5, ARRAY['WiFi ฟรี', 'เกาะส่วนตัว', 'เฮลิคอปเตอร์'], 'https://images.unsplash.com/photo-1439066615861-d1af74d74000?w=800&h=600&fit=crop', TRUE, 'FLAG{tropical_island_sql_hack_samui}');

-- ใส่ flags สำหรับ CTF challenges
INSERT INTO flags (step, flag_name, flag_value, hint) VALUES
(1, 'Basic SQL Injection Login Bypass', 'FLAG{basic_login_bypass_success}', 'ลองใช้ '' OR ''1''=''1 ใน username'),
(2, 'Admin Access Gained', 'FLAG{admin_panel_accessed}', 'หลังจาก bypass login ให้เข้าหน้า /admin'),
(3, 'Union Based SQL Injection', 'FLAG{union_select_master_found}', 'ใช้ UNION SELECT เพื่อดึงข้อมูลจาก hotels table - ลองค้นหาด้วย '' UNION SELECT id,name,secret_flag,address FROM hotels--'),
(4, 'Credit Card Data Breach', 'FLAG{sensitive_data_exposed}', 'ใช้ SQL Injection ในหน้า search เพื่อดึงข้อมูล credit_card จาก user_profiles'),
(5, 'Complete Database Dump', 'FLAG{full_database_access_achieved}', 'ดึงข้อมูลจากทุกตารางในระบบ');

-- ใส่การจองตัวอย่าง
INSERT INTO bookings (user_id, hotel_id, check_in_date, check_out_date, num_guests, total_price, status) VALUES
(2, 1, '2026-02-15', '2026-02-18', 2, 10500.00, 'confirmed'),
(3, 6, '2026-03-01', '2026-03-05', 4, 18000.00, 'confirmed'),
(4, 11, '2026-02-20', '2026-02-23', 2, 8400.00, 'pending');

-- ใส่รีวิวตัวอย่าง
INSERT INTO reviews (user_id, hotel_id, rating, comment) VALUES
(2, 1, 5, 'โรงแรมสวยมาก บริการดีเยี่ยม วิวสวย แนะนำเลยครับ'),
(3, 6, 5, 'รีสอร์ทหรูมาก เหมาะกับครอบครัว ลูกชอบสระว่ายน้ำมาก'),
(4, 11, 4, 'ดีมาก อาหารเช้าอร่อย แต่ที่จอดรถค่อนข้างน้อย');

-- สร้าง indexes เพื่อประสิทธิภาพ
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_sessions_token ON sessions(session_token);
CREATE INDEX idx_hotels_province ON hotels(province_id);
CREATE INDEX idx_bookings_user ON bookings(user_id);
CREATE INDEX idx_bookings_hotel ON bookings(hotel_id);

-- แสดงข้อความเมื่อเสร็จสิ้น
DO $$
BEGIN
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'Database initialized successfully!';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'Admin credentials:';
    RAISE NOTICE 'Username: admin';
    RAISE NOTICE 'Password: admin123';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'Test user credentials:';
    RAISE NOTICE 'Username: johndoe / Password: password123';
    RAISE NOTICE 'Username: somchai / Password: somchai99';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'SQL Injection vulnerabilities:';
    RAISE NOTICE '1. Login page - username field';
    RAISE NOTICE '2. Search page - search field';
    RAISE NOTICE '==============================================';
END $$;
