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

## Desarrollo sin instalar Flutter: Docker

La imagen de contenedor fija Flutter 3.47.4 / Dart 3.13.3, JDK 17, el SDK de
Android 36 y el NDK que exige el proyecto. En los equipos donde Flutter no
está instalado:

```powershell
cd "C:\Users\sault\Documents\para mientras\PlantHaven"

docker build -t planthaven-flutter:local .

docker run --rm -v "${PWD}:/app" -w /app planthaven-flutter:local flutter analyze
docker run --rm -v "${PWD}:/app" -w /app planthaven-flutter:local flutter test
```

- **App web servida** (la misma compilación que se puede demostrar en un
  navegador): `docker build --target app -t planthaven-web:local .` y
  `docker run --rm -p 8080:8080 planthaven-web:local`.
- **APK release:** `docker build --target apk --output type=local,dest=dist .`
  deja `dist\planthaven.apk`.
- **Apuntar a otra API sin tocar el código:** la URL base se inyecta con
  `--dart-define=API_BASE_URL=<url>` (staging por defecto). Por ejemplo, contra
  la API local: `-e API_BASE_URL=http://host.docker.internal:8000`.

Detalle completo (versiones fijadas, actualización del SDK, límites):
[`docs/imagen-docker-flutter.md`](docs/imagen-docker-flutter.md).

## Devcontainer

El repositorio trae `.devcontainer/` con la misma imagen del `Dockerfile`
(`target: sdk`), las extensiones **Dart** y **Flutter** de VS Code y las
cachés de `pub` y Gradle como volúmenes.

1. Docker Desktop (WSL2) + extensión **Dev Containers**.
2. `Ctrl+Shift+P` → **Dev Containers: Reopen in Container**.

Dentro del contenedor: `flutter analyze`, `flutter test`,
`planthaven-web` (app web en el puerto 8080, con `API_BASE_URL` configurable),
`flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0` y
`flutter build apk --release`.

> El devcontainer **no** sustituye a Flutter nativo para el emulador Android
> ni para compilar iOS (solo macOS). Para `flutter run` en un teléfono real
> conviene la instalación local de Flutter + Android Studio.

## Documentación del proyecto

- [`docs/imagen-docker-flutter.md`](docs/imagen-docker-flutter.md) — imagen
  Docker de Flutter/Dart, devcontainer y mantenimiento de versiones.
- [`docs/development_log.md`](docs/development_log.md) — arquitectura
  (Clean Architecture + MVVM), paleta de colores e historias de usuario.
- [`INTEGRACION_SCRUM_5_7.md`](INTEGRACION_SCRUM_5_7.md) — integración con el
  backend de AdopPlant.
- [`REFACTOR_MVC.md`](REFACTOR_MVC.md) — pasos del refactor a MVC.

## Recursos de Flutter

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Documentación de Flutter](https://docs.flutter.dev/)
