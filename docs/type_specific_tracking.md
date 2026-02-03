# Type-Specific Tracking Fields

Bu doküman, ALS uygulamasında izlenen 10 tarla ürünü ve 10 hayvancılık türü için önerilen tür‑özel alanları özetler. Alanlar; veri tipi, anlamı ve varsa önerilen planlama aralığı (scheduling) ile birlikte listelenmiştir. Backend ve frontend uygulamaları bu tanımları kullanarak türlere göre dinamik formlar ve özetler üretecektir.

> **Veri Tipleri**
>
> - `text`: Serbest metin ya da kısa açıklama
> - `number`: Sayısal değer (ondalıklı desteklenir)
> - `integer`: Tam sayı
> - `date`: ISO tarih (yyyy-MM-dd)
> - `choice`: Ön tanımlı seçenekler (değer listesi belirtilir)

## Ortak Alanlar

- `specificType` (`text`): Varyete / alt tür (ör. *Holstein*, *Sarı Buğday*).
- `notes` (`text`): Tür‑özel ek notlar.

## Hayvancılık Türleri

| Tür | Alan | Tip | Açıklama | Önerilen Aralık |
| --- | ---- | --- | -------- | ---------------- |
| `cow` | `estrusStatus` | choice (`inactive`, `in_heat`, `pregnant`) | Kızgınlık/pregnancy durumu | — |
| | `lastEstrusDate` | date | Son kızgınlık tespiti | 21 gün → `nextEstrusCheckDate` |
| | `nextEstrusCheckDate` | date | Bir sonraki kontrol tarihi | `lastEstrusDate` + 21 gün |
| | `calvingCount` | integer | Toplam doğum sayısı | — |
| | `lastCalvingDate` | date | Son doğum tarihi | 280 gün → `expectedCalvingDate` |
| | `expectedCalvingDate` | date | Tahmini doğum | `lastCalvingDate` + 280 gün |
| | `lastVetVisit` | date | Son veteriner ziyareti | 180 gün → `nextVetVisit` |
| | `nextVetVisit` | date | Planlanan veteriner kontrolü | `lastVetVisit` + 180 gün |
| `sheep` | `lambCount` | integer | Son doğum dönemindeki kuzu sayısı | — |
| | `lastShearingDate` | date | Son kırkım | 180 gün → `nextShearingDate` |
| | `nextShearingDate` | date | Planlanan kırkım | `lastShearingDate` + 180 gün |
| | `woolQuality` | choice (`A`, `B`, `C`) | Yün kalite sınıfı | — |
| | `hoofTrimDate` | date | Son tırnak kesimi | 120 gün → `nextHoofTrimDate` |
| | `nextHoofTrimDate` | date | Planlanan tırnak kesimi | `hoofTrimDate` + 120 gün |
| `goat` | `kiddingCount` | integer | Toplam oğlak sayısı | — |
| | `lastDewormingDate` | date | Son iç‑dış parazit uygulaması | 180 gün → `nextDewormingDate` |
| | `nextDewormingDate` | date | Planlanan parazit uygulaması | `lastDewormingDate` + 180 gün |
| | `milkFatBenchmark` | number | Hedef süt yağ oranı (%) | — |
| | `hoofTrimDate` | date | Son tırnak kesimi | 150 gün → `nextHoofTrimDate` |
| | `nextHoofTrimDate` | date | Planlanan tırnak bakımı | `hoofTrimDate` + 150 gün |
| `chicken` | `layingRate` | number | Günlük yumurta ortalaması (%) | — |
| | `feedType` | choice (`layer`, `mixed`, `organic`) | Kullanılan yem tipi | — |
| | `lastVaccinationDate` | date | Son aşı tarihi | 180 gün → `nextVaccinationDate` |
| | `nextVaccinationDate` | date | Planlanan aşı | `lastVaccinationDate` + 180 gün |
| | `coopTemperature` | number | Kümes ortalama sıcaklığı (°C) | — |
| `duck` | `averageEggsWeekly` | number | Haftalık yumurta ortalaması | — |
| | `waterAccessHours` | number | Günlük suya erişim süresi (saat) | — |
| | `pondCleanedAt` | date | Son gölet temizliği | 30 gün → `nextPondCleaningDate` |
| | `nextPondCleaningDate` | date | Planlanan gölet temizliği | `pondCleanedAt` + 30 gün |
| | `feedType` | choice (`pellet`, `mixed`, `forage`) | Yem türü | — |
| `turkey` | `weightGainWeekly` | number | Haftalık ağırlık artışı (kg) | — |
| | `feedConversionRatio` | number | Yem dönüşüm oranı | — |
| | `lastHealthCheckDate` | date | Son sağlık kontrolü | 90 gün → `nextHealthCheckDate` |
| | `nextHealthCheckDate` | date | Planlanan sağlık kontrolü | `lastHealthCheckDate` + 90 gün |
| | `lightingHours` | number | Günlük aydınlatma süresi | — |
| `bee` | `hiveHealthStatus` | choice (`strong`, `moderate`, `weak`) | Koloni gücü | — |
| | `queenStatus` | choice (`present`, `replaced`, `missing`) | Ana arı durumu | — |
| | `lastInspectionDate` | date | Son kovan kontrolü | 21 gün → `nextInspectionDate` |
| | `nextInspectionDate` | date | Planlanan kontrol | `lastInspectionDate` + 21 gün |
| | `honeySupersCount` | integer | Takılan kat (super) sayısı | — |
| `fish` | `waterTemperature` | number | Su sıcaklığı (°C) | — |
| | `waterPh` | number | Su pH değeri | — |
| | `lastFeedingDate` | date | Son yemleme | 1 gün → `nextFeedingDate` |
| | `nextFeedingDate` | date | Planlanan yemleme | `lastFeedingDate` + 1 gün |
| | `avgWeightPerFish` | number | Balık başına ortalama ağırlık (kg) | — |
| `buffalo` | `calvingCount` | integer | Toplam doğum sayısı | — |
| | `lastMudBathDate` | date | Son çamur banyosu | 7 gün → `nextMudBathDate` |
| | `nextMudBathDate` | date | Planlanan çamur banyosu | `lastMudBathDate` + 7 |
| | `milkFatBenchmark` | number | Hedef süt yağ oranı | — |
| | `lastVetVisit` | date | Son veteriner ziyareti | 150 gün → `nextVetVisit` |
| | `nextVetVisit` | date | Planlanan veteriner kontrolü | `lastVetVisit` + 150 |
| `camel` | `lastTrekDate` | date | Son uzun yolculuk | 30 gün → `nextHoofCareDate` |
| | `nextHoofCareDate` | date | Planlanan tırnak bakımı | `lastTrekDate` + 30 |
| | `waterIntakeDaily` | number | Günlük su tüketimi (L) | — |
| | `gestationStatus` | choice (`open`, `mated`, `pregnant`) | Gebelik durumu | — |
| | `expectedCalvingDate` | date | Beklenen doğum | Manuel / (gebelik başlangıcı + 390 gün) |

## Tarla Ürünleri

| Tür | Alan | Tip | Açıklama | Önerilen Aralık |
| --- | ---- | --- | -------- | ---------------- |
| `wheat` | `variety` | text | Çeşit/varyete | — |
| | `irrigationMethod` | choice (`rainfed`, `sprinkler`, `drip`) | Sulama yöntemi | — |
| | `lastIrrigationDate` | date | Son sulama | 7 gün → `nextIrrigationDate` |
| | `nextIrrigationDate` | date | Planlanan sulama | `lastIrrigationDate` + 7 |
| | `fertilizerType` | text | Kullanılan gübre | — |
| | `fertilizationMethod` | choice (`broadcast`, `foliar`, `banded`) | Uygulama yöntemi | — |
| | `lastFertilizationDate` | date | Son gübreleme | 30 gün → `nextFertilizationDate` |
| | `nextFertilizationDate` | date | Planlanan gübreleme | `lastFertilizationDate` + 30 |
| | `soilMoisture` | number | Toprak nemi (%) | — |
| `sugar beet` | `variety` | text | Çeşit | — |
| | `irrigationMethod` | choice (`furrow`, `sprinkler`, `drip`) | Sulama yöntemi | — |
| | `lastIrrigationDate` | date | Son sulama | 5 gün → `nextIrrigationDate` |
| | `nextIrrigationDate` | date | Planlanan sulama | `lastIrrigationDate` + 5 |
| | `lastFertilizationDate` | date | Son gübreleme | 25 gün → `nextFertilizationDate` |
| | `nextFertilizationDate` | date | Planlanan gübreleme | `lastFertilizationDate` + 25 |
| | `sugarPercentTarget` | number | Hedef şeker oranı (%) | — |
| | `rootDiameter` | number | Ortalama kök çapı (cm) | — |
| `corn` | `hybrid` | text | Tohum hibriti | — |
| | `lastIrrigationDate` | date | Son sulama | 4 gün → `nextIrrigationDate` |
| | `nextIrrigationDate` | date | Planlanan sulama | `lastIrrigationDate` + 4 |
| | `silkingDate` | date | Püskül/koçan oluşum tarihi | — |
| | `pollinationStatus` | choice (`pending`, `in_progress`, `completed`) | Tozlanma durumu | — |
| | `lastFertilizationDate` | date | Son gübreleme | 20 gün → `nextFertilizationDate` |
| | `nextFertilizationDate` | date | Planlanan gübreleme | `lastFertilizationDate` + 20 |
| `cotton` | `variety` | text | Çeşit | — |
| | `lastIrrigationDate` | date | Son sulama | 6 gün → `nextIrrigationDate` |
| | `nextIrrigationDate` | date | Planlanan sulama | `lastIrrigationDate` + 6 |
| | `bollCount` | integer | Bitki başına koza sayısı | — |
| | `growthStage` | choice (`vegetative`, `squaring`, `flowering`, `boll`) | Gelişim aşaması | — |
| | `lastFertilizationDate` | date | Son gübreleme | 18 gün → `nextFertilizationDate` |
| | `nextFertilizationDate` | date | Planlanan gübreleme | `lastFertilizationDate` + 18 |
| `sunflower` | `hybrid` | text | Tohum hibriti | — |
| | `lastIrrigationDate` | date | Son sulama | 10 gün → `nextIrrigationDate` |
| | `nextIrrigationDate` | date | Planlanan sulama | `lastIrrigationDate` + 10 |
| | `headDiameter` | number | Tabla çapı (cm) | — |
| | `oilPercentTarget` | number | Hedef yağ oranı (%) | — |
| | `lastFertilizationDate` | date | Son gübreleme | 28 gün → `nextFertilizationDate` |
| | `nextFertilizationDate` | date | Planlanan gübreleme | `lastFertilizationDate` + 28 |
| `tomato` | `variety` | text | Çeşit | — |
| | `greenhouse` | choice (`open_field`, `tunnel`, `glasshouse`) | Üretim ortamı | — |
| | `lastIrrigationDate` | date | Son sulama | 2 gün → `nextIrrigationDate` |
| | `nextIrrigationDate` | date | Planlanan sulama | `lastIrrigationDate` + 2 |
| | `lastPruningDate` | date | Son budama | 14 gün → `nextPruningDate` |
| | `nextPruningDate` | date | Planlanan budama | `lastPruningDate` + 14 |
| | `lastFertilizationDate` | date | Son gübreleme | 10 gün → `nextFertilizationDate` |
| | `nextFertilizationDate` | date | Planlanan gübreleme | `lastFertilizationDate` + 10 |
| `grape` | `variety` | text | Bağ çeşidi | — |
| | `trellisType` | choice (`bush`, `vertical`, `guyot`, `pergola`) | Terbiye sistemi | — |
| | `lastIrrigationDate` | date | Son sulama | 12 gün → `nextIrrigationDate` |
| | `nextIrrigationDate` | date | Planlanan sulama | `lastIrrigationDate` + 12 |
| | `brixLevel` | number | Güncel Brix değeri | — |
| | `lastCanopyWorkDate` | date | Son asma bakım/budama | 20 gün → `nextCanopyWorkDate` |
| | `nextCanopyWorkDate` | date | Planlanan asma bakımı | `lastCanopyWorkDate` + 20 |
| `olive` | `variety` | text | Çeşit | — |
| | `lastIrrigationDate` | date | Son sulama | 14 gün → `nextIrrigationDate` |
| | `nextIrrigationDate` | date | Planlanan sulama | `lastIrrigationDate` + 14 |
| | `lastPruningDate` | date | Son budama | 365 gün → `nextPruningDate` |
| | `nextPruningDate` | date | Planlanan budama | `lastPruningDate` + 365 |
| | `oilExtractionMethod` | choice (`cold_press`, `centrifuge`, `traditional`) | Yağ çıkarma yöntemi | — |
| | `fruitLoadIndex` | number | Ağaç başına meyve yükü | — |
| `rice` | `variety` | text | Çeşit | — |
| | `waterDepth` | number | Tarla su derinliği (cm) | — |
| | `lastFloodDate` | date | Son tava su basımı | 3 gün → `nextFloodDate` |
| | `nextFloodDate` | date | Planlanan su basımı | `lastFloodDate` + 3 |
| | `lastFertilizationDate` | date | Son gübreleme | 15 gün → `nextFertilizationDate` |
| | `nextFertilizationDate` | date | Planlanan gübreleme | `lastFertilizationDate` + 15 |
| `soybean` | `variety` | text | Çeşit | — |
| | `lastIrrigationDate` | date | Son sulama | 6 gün → `nextIrrigationDate` |
| | `nextIrrigationDate` | date | Planlanan sulama | `lastIrrigationDate` + 6 |
| | `nodulationScore` | choice (`poor`, `moderate`, `good`) | Nodülasyon durumu | — |
| | `lastInoculationDate` | date | Son bakteri aşılaması | 365 gün → `nextInoculationDate` |
| | `nextInoculationDate` | date | Planlanan aşılama | `lastInoculationDate` + 365 |
| | `lastFertilizationDate` | date | Son gübreleme | 20 gün → `nextFertilizationDate` |
| | `nextFertilizationDate` | date | Planlanan gübreleme | `lastFertilizationDate` + 20 |

## Kullanım Notları

- **Veri Saklama**: Alanlar `customMetrics` JSON alanında anahtar-değer çiftleri olarak saklanacaktır. Tarihler ISO 8601 formatında (`yyyy-MM-dd`) tutulur.
- **İlişkisel Kayıt**: Her anahtar ayrıca `CropMetric` / `LivestockMetric` tablolarında satır bazında tutulur. Böylece sorgu tarafında belirli parametreler kolayca filtrelenebilir.
- **Otomatik Tarih Hesabı**: Bir alan için `Önerilen Aralık` varsa ve kullanıcı `last...` tarihini girip `next...` değerini boş bırakırsa, backend varsayılan aralığa göre `next...` değerini hesaplayacaktır.
- **Özet Görünümü**: Tracking listesi ve dashboard, her tür için kritik alanlardan bir özet gösterecektir (ör. `next...` tarihleri, `layingRate`, `soilMoisture` gibi).
- **Detay Görünümü**: Ürün/Hayvan detay ekranında tüm alanlar, veri tipi bilinerek (örn. tarih formatlı) kullanıcıya sunulacak ve düzenlenebilecektir.
- **Dil Desteği**: Her alan için yerelleştirme anahtarları `field.<kategori>.<alan>` şeklinde tanımlanacaktır (ör. `field.livestock.cow.estrusStatus`).
