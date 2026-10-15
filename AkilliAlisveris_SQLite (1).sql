-- ============================================================================
-- AKILLI ALIŞVERİŞ SİSTEMİ (AkilliAlisveris.db) SQLITE VERİTABANI ŞEMASI VE SORGULARI
-- Öğrenci: Elif Berber | Sınıf/No: 11/B 3050 | Seçmeli Yazılım Projesi
-- Teknoloji: C# Windows Forms (.NET Desktop) + SQLite
-- ============================================================================

PRAGMA foreign_keys = ON;

-- 1. TABLOLARI TEMİZLEME (Yeniden kurulum için)
DROP VIEW IF EXISTS vw_UrunListesi;
DROP VIEW IF EXISTS vw_SepetDetay;
DROP VIEW IF EXISTS vw_AkilliAlisverisOnerileri;
DROP VIEW IF EXISTS vw_KategoriAnalizi;

DROP TABLE IF EXISTS AlisverisDetay;
DROP TABLE IF EXISTS Alisveris;
DROP TABLE IF EXISTS SepetUrunu;
DROP TABLE IF EXISTS Sepet;
DROP TABLE IF EXISTS Urun;
DROP TABLE IF EXISTS Kategori;
DROP TABLE IF EXISTS Kullanici;

-- ============================================================================
-- 2. TABLO TANIMLAMALARI (DDL)
-- ============================================================================

-- 2.1 KULLANICI TABLOSU
CREATE TABLE IF NOT EXISTS Kullanici (
    KullaniciID INTEGER PRIMARY KEY AUTOINCREMENT,
    KullaniciAdi TEXT NOT NULL UNIQUE,
    Sifre TEXT NOT NULL,
    AdSoyad TEXT NOT NULL,
    Rol TEXT NOT NULL DEFAULT 'Musteri',
    Bakiye REAL NOT NULL DEFAULT 2500.00 CHECK (Bakiye >= 0),
    KayitTarihi TEXT NOT NULL DEFAULT (datetime('now', 'localtime'))
);

-- 2.2 KATEGORİ TABLOSU
CREATE TABLE IF NOT EXISTS Kategori (
    KategoriID INTEGER PRIMARY KEY AUTOINCREMENT,
    KategoriAdi TEXT NOT NULL UNIQUE,
    Ikon TEXT DEFAULT 'Layers',
    Aciklama TEXT
);

-- 2.3 ÜRÜN TABLOSU (BR-02: Fiyat ve Ad NOT NULL, BR-03: Fiyat > 0, Stok >= 0)
CREATE TABLE IF NOT EXISTS Urun (
    UrunID INTEGER PRIMARY KEY AUTOINCREMENT,
    UrunAdi TEXT NOT NULL,
    Fiyat REAL NOT NULL CHECK (Fiyat > 0),
    StokAdeti INTEGER NOT NULL CHECK (StokAdeti >= 0),
    KategoriID INTEGER NOT NULL,
    Barkod TEXT UNIQUE,
    KritikStok INTEGER NOT NULL DEFAULT 5 CHECK (KritikStok >= 0),
    Birim TEXT NOT NULL DEFAULT 'Adet',
    Ikon TEXT DEFAULT 'Package',
    AktifMi INTEGER NOT NULL DEFAULT 1,
    EklenmeTarihi TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
    FOREIGN KEY (KategoriID) REFERENCES Kategori(KategoriID) ON UPDATE CASCADE ON DELETE RESTRICT
);

-- 2.4 SEPET TABLOSU
CREATE TABLE IF NOT EXISTS Sepet (
    SepetID TEXT PRIMARY KEY,
    KullaniciID INTEGER NOT NULL,
    OlusturmaTarihi TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
    Durum TEXT NOT NULL DEFAULT 'Aktif',
    FOREIGN KEY (KullaniciID) REFERENCES Kullanici(KullaniciID) ON UPDATE CASCADE ON DELETE CASCADE
);

-- 2.5 SEPET ÜRÜNÜ TABLOSU (BR-01 Stok Kontrolü iş kuralı)
CREATE TABLE IF NOT EXISTS SepetUrunu (
    SepetUrunuID INTEGER PRIMARY KEY AUTOINCREMENT,
    SepetID TEXT NOT NULL,
    UrunID INTEGER NOT NULL,
    Adet INTEGER NOT NULL CHECK (Adet > 0),
    BirimFiyat REAL NOT NULL CHECK (BirimFiyat >= 0),
    EklenmeTarihi TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
    UNIQUE (SepetID, UrunID),
    FOREIGN KEY (SepetID) REFERENCES Sepet(SepetID) ON DELETE CASCADE,
    FOREIGN KEY (UrunID) REFERENCES Urun(UrunID) ON UPDATE CASCADE ON DELETE RESTRICT
);

-- 2.6 ALIŞVERİŞ (SİPARİŞ) TABLOSU
CREATE TABLE IF NOT EXISTS Alisveris (
    AlisverisID INTEGER PRIMARY KEY AUTOINCREMENT,
    FaturaNo TEXT NOT NULL UNIQUE,
    KullaniciID INTEGER NOT NULL,
    ToplamTutar REAL NOT NULL CHECK (ToplamTutar >= 0),
    Tarih TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
    OdemeTipi TEXT NOT NULL DEFAULT 'Kredi Kartı',
    UrunAdedi INTEGER NOT NULL DEFAULT 1,
    HedefButce REAL,
    TasarrufTutari REAL NOT NULL DEFAULT 0.00,
    ButceDurumu TEXT NOT NULL DEFAULT 'Bütçe Dahilinde',
    FOREIGN KEY (KullaniciID) REFERENCES Kullanici(KullaniciID) ON UPDATE CASCADE ON DELETE RESTRICT
);

-- 2.7 ALIŞVERİŞ DETAY TABLOSU
CREATE TABLE IF NOT EXISTS AlisverisDetay (
    DetayID INTEGER PRIMARY KEY AUTOINCREMENT,
    AlisverisID INTEGER NOT NULL,
    UrunID INTEGER NOT NULL,
    UrunAdi TEXT NOT NULL,
    Adet INTEGER NOT NULL CHECK (Adet > 0),
    BirimFiyat REAL NOT NULL CHECK (BirimFiyat >= 0),
    AraToplam REAL NOT NULL CHECK (AraToplam >= 0),
    FOREIGN KEY (AlisverisID) REFERENCES Alisveris(AlisverisID) ON DELETE CASCADE,
    FOREIGN KEY (UrunID) REFERENCES Urun(UrunID) ON UPDATE CASCADE ON DELETE RESTRICT
);

-- ============================================================================
-- 3. İNDEKSLER (PERFORMANS İYİLEŞTİRMELERİ)
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_urun_kategori ON Urun (KategoriID);
CREATE INDEX IF NOT EXISTS idx_urun_fiyat ON Urun (Fiyat);
CREATE INDEX IF NOT EXISTS idx_sepeturunu_sepet ON SepetUrunu (SepetID);
CREATE INDEX IF NOT EXISTS idx_alisveris_tarih ON Alisveris (Tarih);

-- ============================================================================
-- 4. VIEW (GÖRÜNÜM) TANIMLAMALARI
-- ============================================================================

-- 4.1 ÜRÜN LİSTESİ VE STOK ANALİZ GÖRÜNÜMÜ
CREATE VIEW IF NOT EXISTS vw_UrunListesi AS
SELECT 
    u.UrunID,
    u.Barkod,
    u.UrunAdi,
    k.KategoriAdi,
    u.Fiyat,
    u.StokAdeti,
    u.Birim,
    u.KritikStok,
    CASE 
        WHEN u.StokAdeti = 0 THEN 'Tükendi'
        WHEN u.StokAdeti <= u.KritikStok THEN 'Kritik Stok'
        ELSE 'Stokta Var'
    END AS StokDurumu,
    u.Ikon
FROM Urun u
JOIN Kategori k ON u.KategoriID = k.KategoriID
WHERE u.AktifMi = 1;

-- 4.2 SEPET DETAY VE KALEM BAZLI TUTAR GÖRÜNÜMÜ
CREATE VIEW IF NOT EXISTS vw_SepetDetay AS
SELECT 
    su.SepetUrunuID,
    su.SepetID,
    s.KullaniciID,
    kl.AdSoyad,
    u.UrunID,
    u.UrunAdi,
    k.KategoriAdi,
    su.Adet,
    su.BirimFiyat,
    ROUND((su.Adet * su.BirimFiyat), 2) AS Tutar,
    u.StokAdeti AS KalanStok
FROM SepetUrunu su
JOIN Sepet s ON su.SepetID = s.SepetID
JOIN Urun u ON su.UrunID = u.UrunID
JOIN Kategori k ON u.KategoriID = k.KategoriID
JOIN Kullanici kl ON s.KullaniciID = kl.KullaniciID;

-- 4.3 AKILLI ALIŞVERİŞ VE FİYAT-PERFORMANS GÖRÜNÜMÜ
CREATE VIEW IF NOT EXISTS vw_AkilliAlisverisOnerileri AS
SELECT 
    u.UrunID,
    u.UrunAdi,
    k.KategoriAdi,
    u.Fiyat,
    u.StokAdeti,
    ROUND((1000.0 / u.Fiyat), 2) AS ButcePuan,
    CASE 
        WHEN u.Fiyat < 100 THEN 'Ekonomik Fırsat'
        WHEN u.Fiyat BETWEEN 100 AND 500 THEN 'Standart Fiyat'
        ELSE 'Premium Ürün'
    END AS FiyatSegmenti
FROM Urun u
JOIN Kategori k ON u.KategoriID = k.KategoriID
WHERE u.StokAdeti > 0;

-- 4.4 KATEGORİ BAZLI SATIŞ VE FİYAT ANALİZİ
CREATE VIEW IF NOT EXISTS vw_KategoriAnalizi AS
SELECT 
    k.KategoriAdi,
    COUNT(u.UrunID) AS UrunSayisi,
    ROUND(AVG(u.Fiyat), 2) AS OrtalamaFiyat,
    MIN(u.Fiyat) AS EnUcuzFiyat,
    MAX(u.Fiyat) AS EnPahaliFiyat
FROM Kategori k
LEFT JOIN Urun u ON k.KategoriID = u.KategoriID
GROUP BY k.KategoriID;

-- ============================================================================
-- 5. BAŞLANGIÇ VERİLERİ (SEED DATA)
-- ============================================================================

-- 5.1 KATEGORİLER
INSERT INTO Kategori (KategoriID, KategoriAdi, Ikon, Aciklama) VALUES
(1, 'Elektronik & Aksesuar', 'Smartphone', 'Kulaklık, klavye, mouse, şarj cihazları ve aksesuarlar'),
(2, 'Gıda & Market', 'Coffee', 'Temel atıştırmalıklar, organik kahve, içecek ve sağlıklı ürünler'),
(3, 'Ev & Yaşam', 'Home', 'Termos, seramik kupa, çalışma masası lambası ve gereçleri'),
(4, 'Kırtasiye & Ofis', 'BookOpen', 'Defter, dolma kalem seti, ajanda ve ofis gereçleri'),
(5, 'Giyim & Moda', 'ShoppingBag', 'Tişört, sırt çantası, sweatshirt ve aksesuarlar');

-- 5.2 KULLANICILAR
INSERT INTO Kullanici (KullaniciID, KullaniciAdi, Sifre, AdSoyad, Rol, Bakiye) VALUES
(1, 'elifberber', '123456', 'Elif Berber', 'Yonetici', 3500.00),
(2, 'ahmet_ogrenci', '123456', 'Ahmet Yılmaz', 'Musteri', 1250.00),
(3, 'ayse_kaya', '123456', 'Ayşe Kaya', 'Musteri', 750.00);

-- 5.3 ÜRÜNLER (FR-01, FR-02)
INSERT INTO Urun (UrunID, Barkod, UrunAdi, KategoriID, Fiyat, StokAdeti, KritikStok, Birim, Ikon) VALUES
(101, '86900101', 'Bluetooth Kablosuz Kulaklık ANC', 1, 649.90, 24, 5, 'Adet', 'Headphones'),
(102, '86900102', 'RGB Mekanik Oyuncu Klavyesi', 1, 899.00, 15, 3, 'Adet', 'Keyboard'),
(103, '86900103', 'Ergonomik Kablosuz Mouse', 1, 299.50, 40, 8, 'Adet', 'Mouse'),
(104, '86900104', 'Hızlı Şarj Cihazı Type-C 65W GaN', 1, 389.00, 32, 6, 'Adet', 'Zap'),
(201, '86900201', 'Filtre Kahve Çekirdeği 250g', 2, 175.00, 50, 10, 'Paket', 'Coffee'),
(202, '86900202', 'Doğal Karışık Kuruyemiş 200g', 2, 120.00, 60, 12, 'Paket', 'Cookie'),
(203, '86900203', 'Organik Soğuk Sıkım Zeytinyağı 500ml', 2, 285.00, 18, 5, 'Şişe', 'Droplet'),
(204, '86900204', 'Bitkisel Yeşil Çay Seçkisi 20li', 2, 65.00, 85, 15, 'Kutu', 'Feather'),
(301, '86900301', 'Çelik Termos Matara 750ml', 3, 349.00, 28, 5, 'Adet', 'CupSoda'),
(302, '86900302', 'Seramik Tasarım Kupa', 3, 95.00, 45, 10, 'Adet', 'Coffee'),
(303, '86900303', 'LED Dokunmatik Masa Lambası', 3, 420.00, 12, 4, 'Adet', 'Sun'),
(401, '86900401', 'Sert Kapak Haftalık Ajanda 2026', 4, 140.00, 35, 8, 'Adet', 'Calendar'),
(402, '86900402', 'Metal Gövde Jel Kalem Seti (6lı)', 4, 115.00, 55, 10, 'Set', 'PenTool'),
(403, '86900403', 'Mantar Pano & Notluk 40x60cm', 4, 180.00, 20, 4, 'Adet', 'Grid'),
(501, '86900501', 'Su Geçirmez Laptop Sırt Çantası', 5, 750.00, 16, 3, 'Adet', 'Backpack'),
(502, '86900502', '%100 Pamuklu Minimalist Hoodie', 5, 590.00, 22, 5, 'Adet', 'Shirt'),
(503, '86900503', 'Polarize Güneş Gözlüğü', 5, 320.00, 3, 5, 'Adet', 'Glasses');

-- 5.4 BAŞLANGIÇ SEPETİ
INSERT INTO Sepet (SepetID, KullaniciID, Durum) VALUES
('SEPET-101', 1, 'Aktif');

INSERT INTO SepetUrunu (SepetID, UrunID, Adet, BirimFiyat) VALUES
('SEPET-101', 103, 1, 299.50),
('SEPET-101', 201, 2, 175.00),
('SEPET-101', 401, 1, 140.00);

-- 5.5 GEÇMİŞ ALIŞVERİŞ VE FATURALAR
INSERT INTO Alisveris (AlisverisID, FaturaNo, KullaniciID, ToplamTutar, Tarih, OdemeTipi, UrunAdedi, HedefButce, TasarrufTutari, ButceDurumu) VALUES
(1, 'FAT-20261001-001', 1, 789.90, '2026-10-09 14:32:00', 'Kredi Kartı', 2, 1000.00, 210.10, 'Bütçe İçi - Tasarruf Sağlandı'),
(2, 'FAT-20261005-002', 2, 435.00, '2026-10-11 11:15:00', 'Nakit', 3, 500.00, 65.00, 'Bütçe İçi - Tasarruf Sağlandı');

INSERT INTO AlisverisDetay (AlisverisID, UrunID, UrunAdi, Adet, BirimFiyat, AraToplam) VALUES
(1, 101, 'Bluetooth Kablosuz Kulaklık ANC', 1, 649.90, 649.90),
(1, 401, 'Sert Kapak Haftalık Ajanda 2026', 1, 140.00, 140.00),
(2, 201, 'Filtre Kahve Çekirdeği 250g', 1, 175.00, 175.00),
(2, 202, 'Doğal Karışık Kuruyemiş 200g', 1, 120.00, 120.00),
(2, 401, 'Sert Kapak Haftalık Ajanda 2026', 1, 140.00, 140.00);

-- ============================================================================
-- 6. ÖRNEK SQLITE AKILLI SORGULARI (QUERY EXAMPLES)
-- ============================================================================

-- Q1: 500 TL Altındaki Bütçeye Uygun Ürünler (Akıllı Filtre)
-- SELECT UrunAdi, KategoriAdi, Fiyat, StokAdeti FROM vw_UrunListesi WHERE Fiyat <= 500 ORDER BY Fiyat ASC;

-- Q2: Kritik Stok Seviyesindeki Ürünler
-- SELECT UrunAdi, StokAdeti, KritikStok FROM Urun WHERE StokAdeti <= KritikStok;

-- Q3: Kategoriye Göre Ürün Sayısı ve Ortalama Fiyat Listesi
-- SELECT * FROM vw_KategoriAnalizi;

-- Q4: Aktif Sepet ve Toplam Tutar Özeti
-- SELECT * FROM vw_SepetDetay WHERE SepetID = 'SEPET-101';
