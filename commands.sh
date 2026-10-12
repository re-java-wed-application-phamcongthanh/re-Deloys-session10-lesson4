#!/usr/bin/env bash
# ==============================================================================
# Script: commands.sh
# Mục tiêu: Tự động hóa thiết lập Custom Bridge Network, Named Volume,
#           chạy Database PostgreSQL & Backend Container, và kiểm chứng Data Persistence.
# Bài tập: DevOps Fundamentals - Session 10 - Exercise 4
# ==============================================================================

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== [BƯỚC 1] TẠO CUSTOM BRIDGE NETWORK (app-net) ===${NC}"
docker network create app-net || true
docker network ls | grep app-net

echo -e "\n${BLUE}=== [BƯỚC 2] TẠO NAMED VOLUME (db-data) ===${NC}"
docker volume create db-data || true
docker volume ls | grep db-data

echo -e "\n${BLUE}=== [BƯỚC 3] KHỞI CHẠY DATABASE POSTGRESQL (db-server) TRÊN app-net ===${NC}"
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=testdb \
  postgres:15-alpine

echo "Đang đợi PostgreSQL khởi tạo hoàn tất (5 giây)..."
sleep 5

echo -e "\n${BLUE}=== [BƯỚC 4] KHỞI CHẠY BACKEND CONTAINER TRÊN app-net VỚI HOSTNAME db-server ===${NC}"
docker run -d \
  --name app-container \
  --network app-net \
  -e DB_HOST=db-server \
  -e DB_PORT=5432 \
  -e DB_NAME=testdb \
  -e DB_USER=postgres \
  -e DB_PASSWORD=postgres \
  alpine sleep 3600

echo -e "\n${BLUE}=== [BƯỚC 5] KIỂM TRA DNS RESOLUTION TỪ app-container ĐẾN db-server ===${NC}"
docker exec app-container ping -c 2 db-server

echo -e "\n${BLUE}=== [BƯỚC 6] KIỂM THỬ DATA PERSISTENCE: THÊM DỮ LIỆU VÀO DB ===${NC}"
docker exec -i db-server psql -U postgres -d testdb -c \
  "CREATE TABLE IF NOT EXISTS users (id SERIAL PRIMARY KEY, username VARCHAR(50), created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP); \
   INSERT INTO users (username) VALUES ('devops_student_session10'); \
   SELECT * FROM users;"

echo -e "\n${YELLOW}=== [BƯỚC 7] XÓA CỨNG CONTAINER DB (docker rm -f db-server) ===${NC}"
docker rm -f db-server

echo -e "\n${BLUE}=== [BƯỚC 8] TÁI TẠO CONTAINER DB MỚI DÙNG CHUNG VOLUME db-data ===${NC}"
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=testdb \
  postgres:15-alpine

echo "Đang đợi container DB mới sẵn sàng (3 giây)..."
sleep 3

echo -e "\n${GREEN}=== [BƯỚC 9] XÁC MINH DỮ LIỆU VẪN NGUYÊN VẸN SAU KHI TÁI TẠO CONTAINER ===${NC}"
docker exec -i db-server psql -U postgres -d testdb -c "SELECT * FROM users;"

echo -e "\n${GREEN}=== HOÀN THÀNH TOÀN BỘ KIỂM THỬ THÀNH CÔNG! ===${NC}"
