# Demo Data for Agricultural Supports

This file explains which data source we use for the demo version of the support programs screen in the ALS app. In production, the goal is to fetch data from the real API; during the demo phase, a fixed list is used.

## How It Works

- `frontend/lib/services/support_service.dart` first tries `GET /supports` and then the legacy `POST /dash` calls.
- If neither request returns supports, the service provides data to the screen using the `demoSupportPrograms` list in `frontend/lib/data/support_programs.dart`.
- The demo list returns only records with `type == 'support'`; therefore, check the field value when adding different types.

## Demo Record Format

Each record is stored as a `Map<String, dynamic>`. Key fields to keep in mind:

| Field               | Description                                                                                       | Example Value                                                                                                    |
|---------------------|---------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------|
| `id`                | Unique key. Use kebab-case to stay compatible with the API.                                       | `tr-findik-alan-bazli-2025`                                                                                      |
| `type`              | For now, always `support`.                                                                        | `support`                                                                                                        |
| `title`             | Short label shown in the list.                                                                    | `Findik Alan Bazli Gelir ve Alternatif Urun Destegi`                                                             |
| `summary` / `description` | Short description shown on the card. If `description` is empty, the UI uses `summary`.           | `CKS ve FKS kayitli ureticilere dekar bazli destek saglanir.`                                                    |
| `detail`            | Long text shown on the detail page.                                                               | `Basvuru sartlari, teslim belgeleri ve odeme sekli ...`                                                          |
| `amount`            | Optional amount or premium information.                                                          | `Resmi tarife tablosuna gore TL/da olarak odenir.`                                                                |
| `link` / `institutionUrl` | Official information page of the institution. If `institutionUrl` is empty, the code uses `link`. | `https://www.tarimorman.gov.tr/Konular/.../Findik-Alan-Bazli-Gelir-ve-Alternatif-Urun-Destegi`                   |
| `officialGazetteUrl`| Official Gazette PDF or search link. The UI shows a separate button for this field.              | `https://www.resmigazete.gov.tr/arama?kelime=F%C4%B1nd%C4%B1k%20Alan%20Bazl%C4%B1%20Gelir%20Deste%C4%9Fi`        |
| `category`          | Short category code. For dashboard cards, prefer values like `bitkisel`, `hayvansal`.             | `bitkisel`                                                                                                       |
| `provider`          | Institution that publishes the support.                                                          | `Tarim ve Orman Bakanligi`                                                                                       |
| `region`            | Region or scope where the support is valid.                                                       | `Karadeniz bolgesi ve Findik Kayit Sistemi kapsamindaki iller`                                                   |
| `updatedAt`         | Update date in `YYYY-MM-DD` format.                                                               | `2024-09-30`                                                                                                     |

## Add Records to the Demo List / Update Existing Records

1. Add a new map to the list in `frontend/lib/data/support_programs.dart` or edit existing ones.
2. It is acceptable to use Turkish characters in strings, but before changing the code, it is preferable to keep the existing style (ASCII).
3. Add the Official Gazette page or direct search result for the relevant decision to `officialGazetteUrl`.
4. Keep the `updatedAt` field current; this date can be used for in-app information.
5. Add the new source link to the `institutionUrl` and/or `link` fields. If the link is broken, fix it and update the record.

## Verification Steps

1. Run the frontend (`flutter run`) and go to the supports screen after user login.
2. The list should show static records even if the think-o API does not respond.
3. On the detail page, verify that the `summary` and `detail` fields appear as expected and there is no text overflow.
4. If needed, follow `SupportService.fetchSupportPrograms` logs in the device/emulator console to confirm the fallback is active.

## Next Steps

- When the real API is ready, the same field names can be used for an easy transition.
- If filtering by categories is planned, the UI can proceed with minimal changes based on the existing `category` and `region` fields.
