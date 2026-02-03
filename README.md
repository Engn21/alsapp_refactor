# ALSApp Refactor (Flutter + Node/Express + PostgreSQL/Prisma)

## Hızlı Başlangıç
```bash
# 1) PostgreSQL
docker compose up -d

# 2) Backend
cd backend
cp .env.example .env
npm i
npx prisma generate
npx prisma migrate dev --name init
npm run dev

# 3) Flutter (mobil)
cd ../frontend
flutter pub get
# Android emülatör için API tabanı: http://10.0.2.2:8080/api
```