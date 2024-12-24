import sqlite3
import random



#User Table

def create_databases():
    try:
        cursor.execute("""
            CREATE TABLE users(
                userid INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT NOT NULL UNIQUE,
                password TEXT NOT NULL
            )
        """)
        
        # Meme table
        cursor.execute("""
            CREATE TABLE memes(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER,
                image_path TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                texts TEXT,
                FOREIGN KEY (user_id) REFERENCES users (userid)
            )
        """)
        
        connection.commit()
    except Exception as e:
        print("An error occurred:", e)
    finally:
        connection.close()


# Rastgele kullanıcı ve meme verisi oluşturma fonksiyonu
def randomize_data():
    try:
        # Rastgele kullanıcı ekleme
        for _ in range(5):  # 5 rastgele kullanıcı ekle
            username = f"user{random.randint(1, 100)}"
            password = "password123"
            cursor.execute("INSERT INTO users (username, password) VALUES (?, ?)", (username, password))

        # Rastgele meme ekleme
        for _ in range(5):  # 5 rastgele meme ekle
            user_id = random.randint(1, 5)  # Kullanıcı ID'si 1-5 arasında
            image_path = f"image{random.randint(1, 10)}.png"
            texts = "Rastgele metin"
            cursor.execute("INSERT INTO memes (user_id, image_path, texts) VALUES (?, ?, ?)", (user_id, image_path, texts))

        connection.commit()
    except Exception as e:
        print(f"Hata oluştu: {e}")
    finally:
        connection.close()  # Bağlantıyı her durumda kapat

if __name__ == "__main__":
    
    connection = sqlite3.connect("database_test.db")
    cursor = connection.cursor()
    create_databases()
    randomize_data()  # Rastgele verileri ekle

# Commit changes and close the connection
