﻿CREATE DATABASE QLSANBONG
GO

USE QLSANBONG
GO

CREATE TABLE ACCOUNT
(
	UserName VARCHAR(100) NOT NULL,
	Password VARCHAR(15) NOT NULL,
	DisplayName NVARCHAR(100) NOT NULL,
	Role INT DEFAULT 0,
	CONSTRAINT PK_ACCOUNT PRIMARY KEY (UserName)
)

CREATE TABLE LOAISAN
(
	MaLoai INT IDENTITY(1,1) NOT NULL,
	TenLoai NVARCHAR(100) NOT NULL,
	GiaThue decimal DEFAULT 100000,
	CONSTRAINT PK_LOAISAN PRIMARY KEY (MaLoai)
)

CREATE TABLE SANBONG 
(
	MaSan INT IDENTITY(1,1) NOT NULL,
	TenSan NVARCHAR(100) NOT NULL,
	MaLoai INT NOT NULL,
	CONSTRAINT PK_SANBONG PRIMARY KEY (MaSan),
	CONSTRAINT FK_SANBONG_LOAISAN FOREIGN KEY (MaLoai) REFERENCES LOAISAN(MaLoai)
)

CREATE TABLE KHACHHANG
(
	MaKH INT IDENTITY(1,1) NOT NULL,
	TenKH NVARCHAR(100) NOT NULL,
	DiaChi NVARCHAR(50) DEFAULT N'Chưa xác định',
	SDT VARCHAR(10) NOT NULL,
	CONSTRAINT PK_KHACHHANG PRIMARY KEY (MaKH)
)

CREATE TABLE LICHDATSAN
(
	MaLich INT IDENTITY(1,1) NOT NULL,
	ThoiGianBD DATETIME DEFAULT GETDATE(),
	ThoiGianKT DATETIME NOT NULL,
	MaKH INT NOT NULL,
	MaSan INT NOT NULL,
	ThanhTien decimal DEFAULT 0,
	CONSTRAINT PK_LICHDATSAN PRIMARY KEY (MaLich),
	CONSTRAINT FK_LICHDATSAN_KHACHHANG FOREIGN KEY (MaKH) REFERENCES KHACHHANG(MaKH),
	CONSTRAINT FK_LICHDATSAN_SANBONG FOREIGN KEY (MaSan) REFERENCES SANBONG(MaSan)
)

CREATE TABLE HOADON 
(
	MaHD INT IDENTITY(1,1) NOT NULL,
	NgayTao DATETIME DEFAULT GETDATE(),
	MaSan INT NOT NULL,
	MaKH INT NOT NULL,
	TongGio INT,
	DonGia decimal,
	TongTien FLOAT DEFAULT 0,
	CONSTRAINT PK_HOADON PRIMARY KEY (MaHD),
	CONSTRAINT FK_HOADON_SANBONG FOREIGN KEY (MaSan) REFERENCES SANBONG(MaSan),
	CONSTRAINT FK_HOADON_KHACHHANG FOREIGN KEY (MaKH) REFERENCES KHACHHANG(MaKH)
)

CREATE TABLE DICHVU
(
	MaDV INT IDENTITY(1,1) NOT NULL,
	TenDV NVARCHAR(30) NOT NULL,
	DonGia INT DEFAULT 10000,
	CONSTRAINT PK_DICHVU PRIMARY KEY (MaDV)
)

CREATE TABLE CHITIETHD
(
	MaDV INT NOT NULL,
	MaHD INT NOT NULL,
	SoLuong INT DEFAULT 1,
	CONSTRAINT PK_CHITIETHD PRIMARY KEY (MaDV,MaHD),
	CONSTRAINT PK_CHITIETHD_HOADON FOREIGN KEY (MaHD) REFERENCES HOADON(MaHD),
	CONSTRAINT PK_CHITIETHD_DICHVU FOREIGN KEY (MaDV) REFERENCES DICHVU(MaDV)
)

-- cập nhật lại thành tiền của lịch đặt sân khi thay đổi giá thuê của loại sân
GO
CREATE TRIGGER UpdateTotalLoaiSan
ON LOAISAN
AFTER UPDATE
AS
BEGIN
	DECLARE @GIATHUE DECIMAL
	SET @GIATHUE = (SELECT GIATHUE FROM inserted)

    UPDATE LICHDATSAN
    SET THANHTIEN = (@GIATHUE/60) * DATEDIFF(MINUTE, LICHDATSAN.THOIGIANBD, LICHDATSAN.THOIGIANKT)
    FROM LICHDATSAN, SANBONG
    WHERE (SELECT MALOAI FROM inserted) = SANBONG.MaLoai
	AND LICHDATSAN.MASAN = SANBONG.MASAN
END
GO

-- cập nhật thành tiền của lịch đặt sân khi đặt
GO
CREATE TRIGGER UpdateTotalLichDatSan
ON LICHDATSAN
AFTER INSERT,UPDATE
AS
BEGIN
	DECLARE @THOIGIANBD TIME,  @THOIGIANKT TIME
	SET @THOIGIANBD = (SELECT THOIGIANBD FROM inserted)
	SET @THOIGIANKT = (SELECT THOIGIANKT FROM inserted)

    UPDATE LICHDATSAN
    SET THANHTIEN = (GIATHUE/60) * DATEDIFF(MINUTE, @THOIGIANBD, @THOIGIANKT)
    FROM SANBONG, LOAISAN
    WHERE (SELECT MASAN FROM inserted) = SANBONG.MASAN
	AND LOAISAN.MALOAI = SANBONG.MaLoai
	AND LICHDATSAN.MASAN = (SELECT MASAN FROM inserted)
END
GO

CREATE TRIGGER DeleteTotalLichDatSan
ON LICHDATSAN
AFTER DELETE
AS
BEGIN
	DECLARE @MaSan INT,  @MaKH INT, @TongGio INT, @GiaThue DECIMAL, @ThanhTien DECIMAL
	SET @MaSan = (SELECT MaSan FROM deleted)
	SET @MaKH = (SELECT MaKH FROM deleted)
	DECLARE @THOIGIANBD TIME,  @THOIGIANKT TIME
	SET @THOIGIANBD = (SELECT THOIGIANBD FROM deleted)
	SET @THOIGIANKT = (SELECT THOIGIANKT FROM deleted)
	SET @ThanhTien = (select ThanhTien from deleted)
	SET @GiaThue = (Select GiaThue
					FROM SANBONG, LOAISAN
					WHERE (SELECT MASAN FROM deleted) = SANBONG.MASAN
					AND LOAISAN.MaLoai = SANBONG.MaLoai
					)
    SET @TongGio = (DATEDIFF(MINUTE, @THOIGIANBD, @THOIGIANKT) / 60)
	INSERT INTO HOADON (MaKH, MaSan, TongGio, DonGia, TongTien)
	VALUES (@MaKH,@MaSan, @TongGio, @GiaThue, @ThanhTien)
END
GO

-- Cập nhật tổng tiền của hóa đơn khi thay đổi giá của dịch vụ
GO
CREATE TRIGGER UpdateTotalDichVu
ON DICHVU
AFTER UPDATE
AS
BEGIN
	DECLARE @DONGIA INT
	SET @DONGIA = (SELECT DONGIA FROM inserted)

    UPDATE HOADON
    SET TONGTIEN = TONGTIEN + @DONGIA * SOLUONG
    FROM LICHDATSAN, CHITIETHD, HOADON
    WHERE (SELECT MADV FROM inserted) = CHITIETHD.MADV
	AND HOADON.MAHD = CHITIETHD.MAHD
END
GO

-- Cập nhật tổng tiền của hóa đơn khi thay đổi số lượng trong chi tiết hóa đơn
GO
CREATE TRIGGER UpdateTotalChiTietHD
ON CHITIETHD
AFTER INSERT,UPDATE
AS
BEGIN
	DECLARE @SOLUONG INT
	SET @SOLUONG = (SELECT SOLUONG FROM inserted)

    UPDATE HOADON
    SET TONGTIEN = TONGTIEN + DICHVU.DONGIA * @SOLUONG
    FROM LICHDATSAN, DICHVU, HOADON
    WHERE (SELECT MAHD FROM inserted) = HOADON.MAHD
	AND DICHVU.MADV = (SELECT MADV FROM inserted)
END
GO

INSERT INTO ACCOUNT
VALUES ('admin1', '123456', N'Đạt', 1),
('admin2', 'admin123', N'Tài', 1),
('admin3', 'admin123456', N'Tú', 1),
('nhanvien1', 'nhanvien123', N'Bảo', 0),
('nhanvien2', 'nhanvien123456', N'Trí', 0)

INSERT INTO LOAISAN
VALUES (N'Sân 5 Người', '100000'),
(N'Sân 7 Người', '300000'),
(N'Sân 9 Người', '500000'),
(N'Sân 11 Người', '1000000')

INSERT INTO SANBONG
VALUES (N'Sân 5 - 1', 1),
(N'Sân 5 - 2', 1),
(N'Sân 5 - 3', 1),
(N'Sân 7 - 1', 2),
(N'Sân 7 - 2', 2),
(N'Sân 7 - 3', 2),
(N'Sân 9 - 1', 3),
(N'Sân 9 - 2', 3),
(N'Sân 9 - 3', 3),
(N'Sân 11 - 1', 4),
(N'Sân 11 - 2', 4),
(N'Sân 11 - 3', 4)

INSERT INTO KHACHHANG
VALUES (N'Nguyễn Văn An', N'Quận 1 TP.HCM', '0399127841'),
(N'Trần Văn Khánh', N'Quận Bình Tân TP.HCM', '0392127321'),
(N'Bùi Văn Hùng', N'Quận Bình Thạnh TP.HCM', '0982127612'),
(N'Nguyễn Trường Giang', N'Quận 2 TP.HCM', '0219127513'),
(N'Đinh Văn Quế', N'Quận 3 TP.HCM', '0339127333'),
(N'Bùi Văn Bường', N'Quận 4 TP.HCM', '0333127666')

INSERT INTO LICHDATSAN (THOIGIANBD, THOIGIANKT, MAKH, MASAN)
VALUES ('11-20-2023 16:00', '11-20-2023 18:00', 1, 1)

INSERT INTO LICHDATSAN (THOIGIANBD, THOIGIANKT, MAKH, MASAN)
VALUES('11-20-2023 15:30', '11-20-2023 18:00', 2, 4)

INSERT INTO LICHDATSAN (THOIGIANBD, THOIGIANKT, MAKH, MASAN)
VALUES('11-20-2023 15:00', '11-20-2023 17:00', 3, 8)

INSERT INTO LICHDATSAN (THOIGIANBD, THOIGIANKT, MAKH, MASAN)
VALUES('11-18-2023 14:00', '11-18-2023 17:00', 4, 1)

INSERT INTO LICHDATSAN (THOIGIANBD, THOIGIANKT, MAKH, MASAN)
VALUES('11-17-2023 13:00', '11-17-2023 18:00', 5, 2)

INSERT INTO LICHDATSAN (THOIGIANBD, THOIGIANKT, MAKH, MASAN)
VALUES('11-20-2023 15:00', '11-20-2023 17:00', 6, 11)

INSERT INTO HOADON (MASAN, MAKH, TongGio, DonGia, TongTien)
VALUES (1,1,2,100000, 200000)

INSERT INTO HOADON (MASAN, MAKH, TongGio, DonGia, TongTien)
VALUES(2,2,3,100000, 300000)

INSERT INTO HOADON (MASAN, MAKH, TongGio, DonGia, TongTien)
VALUES(3,3,2,100000, 200000)

INSERT INTO DICHVU
VALUES (N'Nước uống Sting', 10000),
(N'Nước uống Olong', 10000),
(N'Mì xào', 30000),
(N'Cơm gà xối mỡ', 30000),
(N'Cơm tấm', 30000),
(N'Hủ tiếu', 30000)

INSERT INTO CHITIETHD
VALUES (1, 1, 5)

INSERT INTO CHITIETHD
VALUES(2, 2, 7)

INSERT INTO CHITIETHD
VALUES(3, 3, 11)

-- Stored Procedures Login
GO
CREATE PROC SP_Login
@username nvarchar(100), @password nvarchar(15)
AS 
BEGIN
	SELECT * FROM ACCOUNT WHERE USERNAME = @username AND PASSWORD = @password
END
GO

-- Stored Procedures Quản lý sân
GO
CREATE PROC SP_GetListSan
AS
BEGIN
	SELECT * FROM SANBONG
END
GO

GO
CREATE PROC SP_KiemTraTrungTenSan
@TenSan nvarchar(100)
AS 
BEGIN
	SELECT * FROM SANBONG WHERE TenSan = @TenSan
END
GO

GO
CREATE PROC SP_ThemSan 
@TenSan nvarchar(100), @Maloai int
AS
BEGIN
	INSERT INTO SANBONG
	VALUES (@TenSan, @Maloai)
END
GO

GO
CREATE PROC SP_XoaSan 
@MaSan int
AS
BEGIN
	DELETE FROM SANBONG WHERE MASAN = @MaSan
END
GO

GO
CREATE PROC SP_SuaSan
@MaSan int, @TenSan nvarchar(100), @MaLoai int
AS
BEGIN
	UPDATE SANBONG
	SET TenSan = @TenSan, MaLoai = @MaLoai
	WHERE SANBONG.MaSan = @MaSan
END
GO

GO
CREATE PROC SP_TimKiemSan
@TenSan nvarchar(100)
AS
BEGIN
	SELECT * FROM SANBONG WHERE TENSAN LIKE '%' + @TenSan + '%'
END
GO

-- Stored Procedures Quản lý loại sân
GO
CREATE PROC SP_GetListLoaiSan
AS
BEGIN
	SELECT * FROM LOAISAN
END
GO

GO
CREATE PROC SP_KiemTraTrungTenLoai
@TenLoai nvarchar(100)
AS 
BEGIN
	SELECT * FROM LOAISAN WHERE TenLoai = @TenLoai
END
GO

GO
CREATE PROC SP_ThemLoaiSan
@TenLoai nvarchar(100), @GiaThue float
AS
BEGIN
	INSERT INTO LOAISAN
	VALUES (@TenLoai, @GiaThue)
END
GO

GO
CREATE PROC SP_XoaLoaiSan 
@MaLoai int
AS
BEGIN
	DELETE FROM LOAISAN WHERE Maloai = @MaLoai
END
GO

GO
CREATE PROC SP_SuaLoaiSan
@MaLoai int, @TenLoai nvarchar(100), @GiaThue float
AS
BEGIN
	UPDATE LOAISAN
	SET TenLoai = @TenLoai, GiaThue = @GiaThue
	WHERE LOAISAN.MaLoai = @MaLoai
END
GO

GO
CREATE PROC SP_TimKiemLoaiSan
@TenLoai nvarchar(100)
AS
BEGIN
	SELECT * FROM LOAISAN WHERE TenLoai LIKE '%' + @TenLoai + '%'
END
GO

-- Stored Procedures Quản lý lịch đặt sân
GO
CREATE PROC SP_GetListLichDatSan
AS
BEGIN
	SELECT * FROM LICHDATSAN
END
GO

GO
CREATE PROC SP_ThemLichDatSan
@ThoiGianBD DateTime, @ThoiGianKT DateTime, @MaKH int, @MaSan int
AS
BEGIN
	INSERT INTO LICHDATSAN (THOIGIANBD, THOIGIANKT, MAKH, MASAN)
	VALUES (@ThoiGianBD, @ThoiGianKT, @MaKH, @MaSan)
END
GO

GO
CREATE PROC SP_XoaLichDatSan
@MaLich int
AS
BEGIN
	DELETE FROM LICHDATSAN WHERE MaLich = @MaLich
END
GO

GO
CREATE PROC SP_SuaLichDatSan
@MaLich int, @ThoiGianBD DateTime, @ThoiGianKT DateTime, @MaKH int, @MaSan int
AS
BEGIN
	UPDATE LICHDATSAN
	SET ThoiGianBD = @ThoiGianBD, ThoiGianKT = @ThoiGianKT, MaKH = @MaKH, MaSan = @MaSan
	WHERE MaLich = @MaLich
END
GO

-- Stored Procedures Dịch vụ
-- Stored Procedures SP_GetListLoaiSan
GO
CREATE PROC SP_GetListDichVu
AS
BEGIN
	SELECT * FROM DICHVU
END
GO
-- Stored Procedures SP_KiemTraTrungDichVu
GO
CREATE PROC SP_KiemTraTrungTenDichVu
@TenDV nvarchar(100)
AS 
BEGIN
	SELECT * FROM DICHVU WHERE TENDV = @TenDV
END
GO
-- Stored Procedures SP_ThemDichVu
GO
CREATE PROC SP_ThemDichVu
@TenDV nvarchar(100), @Gia float
AS
BEGIN
	INSERT INTO DICHVU
	VALUES (@TenDV, @Gia)
END
GO
-- Stored Procedures SP_XoaDV
GO
CREATE PROC SP_XoaDV1
@TenDV nvarchar(200)
AS
BEGIN
	DELETE FROM DICHVU WHERE TenDV = @TenDV
END
GO
select *from dichvu

-- Stored Procedures SP_GetListHoaDon
GO
CREATE PROC SP_GetListHoaDon
AS
BEGIN
	SELECT * FROM HOADON
END
GO

GO
CREATE PROC SP_XoaHoaDon 
@MaHD int
AS
BEGIN
	DELETE FROM HOADON WHERE MaHD = @MaHD
END

GO
CREATE PROC SP_SuaHoaDon
    @MaHD INT,
    @NgayTao DATETIME,
    @TongTien DECIMAL(18, 0),
    @MaKH INT,
	@MaSan INT,
	@TongGio INT
AS
BEGIN
    UPDATE HOADON
    SET NgayTao = @NgayTao,
        TongTien = @TongTien,
        MaKH = @MaKH,
		MaSan = @MaSan,
		TongGio = @TongGio
    WHERE MaHD = @MaHD;
END
GO

CREATE PROC SP_CanEditMaHD
    @MaHD INT
AS
BEGIN
    DECLARE @CanEdit BIT;

    SELECT @CanEdit = CASE
        WHEN @MaHD > 0 THEN 1
        ELSE 0
    END;

    SELECT @CanEdit AS CanEdit;
END