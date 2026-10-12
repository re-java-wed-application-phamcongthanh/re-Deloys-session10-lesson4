# Bài 4: Thiết Lập Custom Network & Named Volume Bằng Docker CLI

## 🎯 1. Mục Tiêu
- Khởi tạo **Custom Bridge Network** (`app-net`) để kích hoạt cơ chế tự động phân giải tên miền nội bộ (**Automatic DNS Resolution**) giữa các Container thông qua tên service.
- Khởi tạo **Named Volume** (`db-data`) để lưu trữ dữ liệu bền vững (Persistence Storage) độc lập với vòng đời của container cơ sở dữ liệu.
- Viết kịch bản tự động hóa [commands.sh](file:///c:/hoccode/Devops%20Fundamentals/BaiTap/session10/bai4/commands.sh) thực hiện toàn bộ quy trình và kiểm chứng tính toàn vẹn dữ liệu khi xóa cứng container DB.

---

## 📁 2. Cấu Trúc Thư Mục
```text
bai4/
├── commands.sh       # Script tự động hóa toàn bộ thao tác CLI
└── README.md         # Báo cáo kỹ thuật và kiểm chứng kết quả
```

---

## 🛠️ 3. Quy Trình Thực Hiện & Giải Thích Kỹ Thuật

### 3.1. Phân biệt Custom Bridge Network vs Default Bridge Network
- **Default Bridge Network (`bridge`)**: Không hỗ trợ phân giải DNS tự động theo tên container (chỉ có thể kết nối bằng địa chỉ IP động hoặc dùng cờ `--link` đã lỗi thời).
- **Custom Bridge Network (`app-net`)**: Tự động kích hoạt Docker Embedded DNS Server (IP `127.0.0.11`), cho phép mọi container cùng tham gia mạng gọi nhau trực tiếp bằng tên định danh (ví dụ: `ping db-server`).

### 3.2. Quy trình 9 bước trong `commands.sh`:

#### Bước 1: Khởi tạo Custom Bridge Network
```bash
docker network create app-net
```

#### Bước 2: Khởi tạo Named Volume
```bash
docker volume create db-data
```

#### Bước 3: Khởi chạy Database Container PostgreSQL
```bash
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=testdb \
  postgres:15-alpine
```

#### Bước 4: Khởi chạy Backend Container tham gia `app-net`
```bash
docker run -d \
  --name app-container \
  --network app-net \
  -e DB_HOST=db-server \
  -e DB_PORT=5432 \
  -e DB_NAME=testdb \
  alpine sleep 3600
```

#### Bước 5: Kiểm tra DNS Resolution
```bash
docker exec app-container ping -c 2 db-server
```

**Kết quả thực tế:**
```text
PING db-server (172.21.0.2): 56 data bytes
64 bytes from 172.21.0.2: seq=0 ttl=64 time=0.541 ms
64 bytes from 172.21.0.2: seq=1 ttl=64 time=0.142 ms

--- db-server ping statistics ---
2 packets transmitted, 2 packets received, 0% packet loss
```
> ✅ **Xác nhận**: `app-container` đã phân giải thành công tên miền `db-server` thành địa chỉ IP nội bộ `172.21.0.2`.

---

#### Bước 6: Kiểm thử Data Persistence - Thêm dữ liệu
```bash
docker exec -i db-server psql -U postgres -d testdb -c \
  "CREATE TABLE users (id SERIAL PRIMARY KEY, username VARCHAR(50), created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP); \
   INSERT INTO users (username) VALUES ('devops_student_session10'); \
   SELECT * FROM users;"
```

**Kết quả bảng dữ liệu ban đầu:**
```text
CREATE TABLE
INSERT 0 1
 id |         username         |         created_at         
----+--------------------------+----------------------------
  1 | devops_student_session10 | 2026-10-12 06:08:54.112763
(1 row)
```

---

#### Bước 7: Xóa cứng Container Database (`docker rm -f`)
```bash
docker rm -f db-server
```
Container `db-server` bị hủy hoàn toàn, tiến trình và writable layer biến mất.

---

#### Bước 8: Tái tạo Container Database mới gắn cùng Volume `db-data`
```bash
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=testdb \
  postgres:15-alpine
```

---

#### Bước 9: Xác minh dữ liệu không bị mất (Persistence Verification)
```bash
docker exec -i db-server psql -U postgres -d testdb -c "SELECT * FROM users;"
```

**Kết quả truy vấn trên Container mới:**
```text
 id |         username         |         created_at         
----+--------------------------+----------------------------
  1 | devops_student_session10 | 2026-10-12 06:08:54.112763
(1 row)
```
> ✅ **Xác nhận**: Bản ghi `id=1` cùng thời gian khởi tạo được bảo toàn 100% nguyên vẹn bên trong Named Volume `db-data`.

---

## 🔍 4. Lệnh Kiểm Tra Hệ Thống

```bash
# 1. Kiểm tra Network
docker network ls | grep app-net
# Trả về: 4dbd0150c06b   app-net   bridge   local

# 2. Kiểm tra Volume
docker volume ls | grep db-data
# Trả về: local   db-data

# 3. Kiểm tra chi tiết cấu hình mạng và các container trực thuộc
docker network inspect app-net
```

---

## 🧹 5. Hướng Dẫn Dọn Dẹp
Khi kết thúc quá trình làm việc, dọn dẹp các tài nguyên đã tạo:
```bash
docker rm -f db-server app-container
docker network rm app-net
docker volume rm db-data
```
