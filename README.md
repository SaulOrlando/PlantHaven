# PlantHaven

Aplicación móvil **Flutter** del proyecto **AdopPlant**: catálogo de plantas,
solicitudes de adopción y mensajería entre usuarios.

- **Tecnología:** Flutter 3.47.4 · Dart 3.13.3 · Material 3 · `provider` ·
  `get_it` · `go_router` · `http` · `flutter_map` · `hive` · `flutter_secure_storage`
- **API:** REST de AdopPlant (`https://adopplant-api.onrender.com` en staging).
- **Arquitectura:** MVC + Inyección de dependencias (`lib/injection_container.dart`).

## Estructura

```
lib/
├── main.dart                  # Punto de entrada y tema (Material 3 + Google Fonts)
├── injection_container.dart   # Registro de dependencias (get_it)
├── core/
│   ├── config/api_config.dart # URLs y rutas de la API
│   ├── constants/             # app_colors, app_strings, app_routes
│   ├── routes/app_router.dart # GoRouter con rutas y guard de autenticación
│   └── utils/validators.dart
├── models/                    # UserModel, PlantModel, AdoptionRequestModel, ...
├── services/                  # api_service, auth_service, plant_service, ...
├── controllers/               # AuthController, PlantController, ...
├── utils/session_manager.dart # Token JWT (flutter_secure_storage)
└── views/                     # Pantallas y widgets reutilizables
```

## Requisitos

- [Flutter 3.47.4 / Dart 3.13.3](https://docs.flutter.dev/get-started/install)

## Ejecutar la app

```powershell
cd PlantHaven

flutter pub get
flutter analyze                 # análisis estático (0 problemas esperados)
flutter run                     # emulador o teléfono conectado
flutter run -d chrome           # app web para la demostración
```

## Ejecutar tests

```powershell
# Desde la carpeta PlantHaven/

# Ejecutar todas las pruebas
flutter test

# Ejecutar con reporte detallado
flutter test --reporter expanded

# Ejecutar un archivo de test específico
flutter test test/catalog_test.dart

# Ejecutar con cobertura
flutter test --coverage
```

**Total de pruebas:** 22 pruebas unitarias/widget en `test/`.

## Test E2E móvil (Jira SCRUM-93)

El ticket **SCRUM-93 — Test Extremo a Extremo 03** cubre pruebas funcionales E2E para la app móvil PlantHaven, conectadas contra la API de Adoplant.

```powershell
# Desde la carpeta PlantHaven/
# Asegúrate de que la API de Adoplant esté levantada (http://127.0.0.1:8000)

# Ejecutar todas las pruebas (incluye las de SCRUM-93)
flutter test

# Ejecutar con reporte detallado
flutter test --reporter expanded

# Ejecutar un archivo específico
flutter test test/catalog_test.dart

# Con cobertura
flutter test --coverage
```

La URL de la API se inyecta con `--dart-define`:

```powershell
# API local desde la app web
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000

# API local desde el emulador Android
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

## Ver reportes

```powershell
# Reporte detallado en consola
flutter test --reporter expanded

# Cobertura de código
flutter test --coverage
```

El reporte de cobertura se genera en `coverage/lcov.info` y `coverage/index.html` (HTML). Abre `coverage/index.html` en el navegador para ver el detalle por archivo.

La URL base de la API se inyecta sin tocar el código con `--dart-define`:

```powershell
# Staging (valor por defecto)
flutter run --dart-define=API_BASE_URL=https://adopplant-api.onrender.com

# API local (Windows) desde el emulador Android
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000

# API local desde la app web
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

- **APK release:** `flutter build apk --release` deja el archivo en
  `build\app\outputs\flutter-apk\app-release.apk`.
- **App web:** `flutter build web` y luego servir `build\web` con cualquier
  servidor estático.
- La API debe estar levantada antes de probar el login (ver `../INICIAR_PROYECTOS.md`
  y `../tests/README.md`). Las cuentas de prueba están en el README de cada API.

## Documentación del proyecto

- [`docs/development_log.md`](docs/development_log.md) — arquitectura
  (Clean Architecture + MVVM), paleta de colores e historias de usuario.
- [`INTEGRACION_SCRUM_5_7.md`](INTEGRACION_SCRUM_5_7.md) — integración con el
  backend de AdopPlant.
- [`REFACTOR_MVC.md`](REFACTOR_MVC.md) — pasos del refactor a MVC.

## Recursos de Flutter

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Documentación de Flutter](https://docs.flutter.dev/)
