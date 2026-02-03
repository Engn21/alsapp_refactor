# 📋 Tracking System Implementation Guide

This guide explains the changes and usage steps for the **10 Crop + 10 Livestock tracking system** added to the ALS application.

## 🎯 Summary of Changes

### ✅ Backend Changes

1. **Database Migration** - `/backend/prisma/migrations/20251013000000_add_type_specific_fields/migration.sql`
   - Type-specific fields added to the Crop table (protein%, moisture%, sugar%, oil%, healthStatus, etc.)
   - Type-specific fields added to the Livestock table (weightKg, healthStatus, dailyFeedKg, etc.)
   - New tables: `EggLog`, `HoneyLog`, `WoolLog`, `WeightLog`, `CropQualityLog`

2. **Prisma Schema Updated** - `/backend/prisma/schema.prisma`
   - Crop and Livestock models expanded
   - New log models added

3. **Type Thresholds Config** - `/backend/src/config/type-thresholds.ts`
   - Critical threshold values for 10 crop types
   - Critical threshold values for 10 livestock types
   - Ideal ranges defined for each type

4. **Controllers Updated**
   - `/backend/src/controllers/crops.controller.ts`: Type-specific serialization, new `recordCropQuality` endpoint
   - `/backend/src/controllers/livestock.controller.ts`: Type-specific serialization, updated notification system

5. **Routes Updated**
   - `/backend/src/routes/crops.ts`: Added `POST /crops/:id/quality` endpoint

### ✅ Frontend Changes

1. **API Service** - `/frontend/lib/services/api_service.dart`
   - Added `addCropQuality()` method
   - API support for type-specific quality metrics

## 🌾 10 CROP TYPES and CRITICAL ATTRIBUTES

| Type | Turkish | Minimum Yield (t/ha) | Critical Metrics |
|------|---------|-----------------------|------------------|
| wheat | Buğday | 3.0 | Protein %11-15, Moisture %12-14 |
| sugar beet | Pancar | 50.0 | Sugar %16-20, Moisture %70-80 |
| corn | Mısır | 7.5 | Protein %8-11, Moisture %13-15 |
| cotton | Pamuk | 3.0 | Moisture %7-9 |
| sunflower | Ayçiçeği | 2.2 | Oil %40-50, Moisture %8-10 |
| tomato | Domates | 60.0 | Moisture %93-95 |
| grape | Üzüm | 9.0 | Sugar %17-25, Moisture %75-85 |
| olive | Zeytin | 4.0 | Oil %15-25, Moisture %45-55 |
| rice | Pirinç | 5.5 | Protein %6-8, Moisture %12-14 |
| soybean | Soya | 2.5 | Protein %38-42, Moisture %12-14 |

## 🐄 10 LIVESTOCK TYPES and CRITICAL ATTRIBUTES

| Type | Turkish | Minimum Daily Milk (L) | Min. Fat (%) | Ideal Weight (kg) |
|------|---------|-------------------------|--------------|-------------------|
| cow | İnek | 15.0 | 3.2 | 550 |
| goat | Keçi | 2.5 | 3.4 | 55 |
| sheep | Koyun | - | - | 70 |
| chicken | Tavuk | 0.7 eggs/day | - | 2.0 |
| duck | Ördek | 0.8 eggs/day | - | 3.0 |
| turkey | Hindi | - | - | 12 |
| bee | Arı | Honey production | - | - |
| fish | Balık | - | - | 1.0 |
| buffalo | Manda | 10.0 | 6.5 | 600 |
| camel | Deve | 6.0 | 3.5 | 500 |

## 🚀 Setup Steps

### 1. Backend Setup

```bash
cd backend

# 1. Run the database migration
npx prisma migrate dev

# 2. Re-generate the Prisma client
npx prisma generate

# 3. Build TypeScript
npm run build

# 4. Start the backend
npm start
```

### 2. Testing

After the backend is running, you can test these endpoints:

```bash
# Add a crop quality log
curl -X POST http://localhost:8080/api/crops/{cropId}/quality \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{
    "proteinPercent": 13.5,
    "moisturePercent": 13.0,
    "notes": "First harvest quality test"
  }'
```

## 📱 Frontend Usage

### New Features on the Product Details Screen

1. **Crop Details**:
   - View quality metrics (protein, moisture, sugar, oil)
   - Quality log chart
   - Add a new quality measurement

2. **Livestock Details**:
   - Weight tracking
   - Milk/Egg/Honey/Wool production charts
   - Health status tracking

## 🔔 Notification System

### Crop Notifications

1. **Low Yield Alert**: When harvest yield falls below the minimum threshold
2. **Quality Alert**: When protein, moisture, sugar, or oil ratios are outside the ideal range
3. **Spraying Reminder**: When the next spraying date arrives

### Livestock Notifications

1. **Milk Production Alert**: When daily milk amount or fat ratio is below the minimum threshold
2. **Egg Production Alert**: When daily egg count is below the expected value
3. **Weight Alert**: When animal weight is outside the ideal range

## 📊 Data Flow

```
1. User adds a product (Crop/Livestock)
   ↓
2. Backend sends notification: "New product added"
   ↓
3. User adds a measurement (milk, egg, quality, etc.)
   ↓
4. Backend checks threshold values
   ↓
5. If threshold exceeded → Notification is sent
   ↓
6. Current metrics are shown on Dashboard and Product Details
```

## 🛠️ Future Enhancements

### Frontend (Remaining Work)

1. **Update Product List Form**:
   - Add a dropdown for type selection (10 crop + 10 livestock)
   - Dynamic form fields based on the selected type

2. **Expand Product Details**:
   - Type-specific metric cards
   - Charts for quality metrics
   - Weight tracking chart
   - Egg/Honey/Wool production charts

3. **Dashboard Improvements**:
   - Show all products in categorized cards
   - Summarize critical metrics for each product
   - Show alert counts

## 📝 Code Examples

### Backend: Add a New Crop Quality Log

```typescript
// User performs a quality test for wheat
await recordCropQuality(req, res);
// → Backend checks the protein ratio
// → Sends a notification if it is outside the 11-15% range
```

### Frontend: API Call

```dart
await ApiService.addCropQuality(
  id: cropId,
  proteinPercent: 13.5,
  moisturePercent: 13.0,
  notes: 'First harvest quality test',
);
```

## ❓ FAQ

**Q: I am getting a database migration error.**
A: Reset the database with `npx prisma migrate reset` and run the migration again.

**Q: The backend build fails.**
A: Make sure `type-thresholds.ts` is imported correctly.

**Q: Notifications are not showing.**
A: Check the Notification table: `SELECT * FROM "Notification" ORDER BY "createdAt" DESC;`

## 📞 Support

If you run into any issues:
1. Check backend logs
2. Check whether data exists in the database
3. Check for errors in the frontend console

---

**App Version**: 2.0.0
**Last Updated**: 2025-10-13
**Developer**: Claude Code
