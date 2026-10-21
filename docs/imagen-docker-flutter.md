# PlantHaven — imagen Docker de Flutter/Dart y devcontainer

Este documento explica la imagen de contenedor de **PlantHaven** (Flutter 3.47.4 /
Dart 3.13.3), cómo se usa y **por qué sí conviene un devcontainer** para este
repositorio.

---

## 1. Por qué hace falta una imagen propia

Dos motivos concretos:

1. **En los equipos no hay Flutter instalado.** En esta máquina
   (`flutter --version` y `dart --version` no existen en el `PATH`) el SDK de
   Flutter no está presente. Instalar Flutter + Android Studio + SDK de
   Android + NDK + build-tools en Windows es pesado y cada versión subtly
   distinta; la imagen lo fija todo.
2. **Las imágenes de la comunidad se quedan cortas.** La más usada,
   `ghcr.io/cirruslabs/flutter:stable`, llega a **Flutter 3.44.0 / Dart 3.12.0**.
   Este proyecto declara `environment: sdk: ^3.13.3` en `pubspec.yaml` y su
   `pubspec.lock` fija `flutter: ">=3.44.0"`, así que con esa imagen
   `flutter pub get` falla con:

   ```
   The current Dart SDK version is 3.12.0.
   Because flutter_app requires SDK version ^3.13.3, version solving failed.
   ```

   El SDK correcto (3.47.4 / Dart 3.13.3) es el que grabó el propio proyecto en
   `.metadata` (`revision 9584c671…`, `channel: stable`). El `Dockerfile`
   descarga ese archivo oficial y **verifica su SHA-256** antes de usarlo.

---

## 2. Contenido de la imagen

| Componente | Versión | Motivo |
|---|---|---|
| Flutter | 3.47.4 | La del proyecto (`.metadata`). Dart 3.13.3 incluido. |
| OpenJDK | 17 | AGP 9.1 y Gradle 9.3.1 exigen Java 17 o superior. |
| Android SDK | plataforma 36 | `compileSdk`/`targetSdk` que usa Flutter 3.47. |
| Build-tools | 36.0.0 | Los que exige AGP 9. |
| Android NDK | el que fija `flutter.ndkVersion` (28.2.13676358) | `android/app/build.gradle.kts` declara `ndkVersion = flutter.ndkVersion`; sin NDK, `flutter build apk` depende de que Gradle lo descargue en cada máquina o falla. |
| Google Chrome | estable | `flutter run -d chrome` para demos y pruebas E2E web. |
| Flutter precache | android, web, linux | Los artefactos ya están en la imagen: sin red al compilar. |

Usuario `vscode` (uid 1000) sin privilegios para el devcontainer. Cachés de
pub (`/opt/pub-cache`) y de Gradle (`/opt/gradle-cache`) fuera del proyecto,
para poder montarlas como volúmenes.

Script de ayuda instalado en la imagen: **`planthaven-web`**, que levanta la
app web en el puerto 8080 apuntando a la API que indique `API_BASE_URL`
(staging por defecto).

### Destinos (`--target`) del `Dockerfile`

| Target | Qué produce | Tamaño |
|---|---|---|
| `sdk` **(por defecto)** | Imagen de Dart + Flutter para analizar, probar y compilar. | ~4,5 GB |
| `app` | La app web compilada, servida por nginx en el puerto 8080. | ~60 MB |
| `apk` | Solo el APK release (`--output type=local` lo deja en `dist/`). | ~20 MB |
| `web-builder` | Imagen intermedia con `build/web` ya generado. | intermedia |

> El NDK ocupa bastante (la imagen del SDK queda en ~4,5 GB; sin NDK serían
> ~3,1 GB). Se conserva porque es lo que permite compilar el APK sin depender
> de que Gradle lo descargue en cada máquina. La carpeta `sources` del NDK
> (~1,3 GB) se borra en la construcción: no la usa la compilación.

---

## 3. Construir

```powershell
cd "C:\Users\sault\Documents\para mientras\PlantHaven"

# Imagen de Flutter/Dart (destino por defecto)
docker build -t planthaven-flutter:local .

# App web servible
docker build -t planthaven-web:local --target app .

# APK release (deja planthaven.apk en la carpeta dist\)
docker build --target apk --output type=local,dest=dist -t planthaven-apk:local .
```

> La primera construcción descarga Flutter (~700 MB), el SDK de Android
> (~350 MB), el **NDK (~1 GB)** y Chrome, y además reescribe los permisos de
> todo el SDK (`chown -R`), que es el paso más lento. En un equipo con poca
> RAM (8 GB) la construcción completa tarda entre **35 y 45 minutos**; las
> siguientes tardan segundos gracias a la caché de Docker.
>
> **No builds la imagen y compiles el APK a la vez**: con 8 GB de RAM el
> daemon de Docker se queda sin memoria y se cae (la construcción se
> reinicia sola al relanzarla). Son operaciones secuenciales.

---

## 4. Usar la imagen

```powershell
# Análisis estático (equivale a "flutter analyze")
docker run --rm -v "${PWD}:/app" -w /app planthaven-flutter:local flutter analyze

# Pruebas unitarias y de widgets (carpeta test/)
docker run --rm -v "${PWD}:/app" -w /app planthaven-flutter:local flutter test

# Servidor web de desarrollo (http://localhost:8080)
docker run --rm -p 8080:8080 -v "${PWD}:/app" -w /app planthaven-flutter:local \
  flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0
```

> `--web-hostname 0.0.0.0` es necesario: por defecto el servidor web de
> Flutter escucha solo en `localhost` dentro del contenedor y el puerto
> publicado no alcanzaría la app.

### App web compilada

```powershell
docker build -t planthaven-web:local --target app .
docker run --rm -p 8080:8080 planthaven-web:local
# -> http://localhost:8080
```

La app web llama a la API que apunta `lib/core/config/api_config.dart`
(`https://adopplant-api.onrender.com`, el staging de Render). Esa constante se
puede cambiar **en tiempo de compilación, sin tocar el código**, con
`--dart-define`:

```powershell
# API local de AdopPlant (la del compose de la raíz)
docker run --rm -p 8080:8080 -v "${PWD}:/app" -w /app `
  -e API_BASE_URL=http://host.docker.internal:8000 `
  planthaven-flutter:local planthaven-web
```

| Desde | URL de la API |
|---|---|
| Emulador Android | `http://10.0.2.2:8000` |
| Web servida en Docker / devcontainer | `http://host.docker.internal:8000` |
| Web abierta en el navegador del host | `http://localhost:8000` |
| Staging (valor por defecto) | `https://adopplant-api.onrender.com` |

El CORS de FastAPI (`Adoplant/app/main.py`) acepta cualquier origen
`http://localhost:<puerto>` o `http://127.0.0.1:<puerto>`, así que la versión
web en Docker (origen `http://localhost:8080`) ya puede hablar con la API
local sin tocar la configuración del backend.

### APK de Android

```powershell
docker build --target apk --output type=local,dest=dist -t planthaven-apk:local .
# -> dist\planthaven.apk  (instalable en un dispositivo o emulador)
```

El APK sale firmado con las llaves de **debug** (mismo criterio que
`android/app/build.gradle.kts` del proyecto). Para distributing en producción
hay que configurar un keystore propio.

---

## 5. ¿Es necesario un devcontainer? **Sí, y aquí está el de PlantHaven**

### Por qué sí

1. **Sin instalación local:** el equipo abre el repositorio y tiene Flutter,
   Dart, JDK 17 y el SDK de Android idénticos, sin instalar nada.
2. **Coherencia con el resto del proyecto:** `Adoplant/` y
   `AdopPlant.Analytics/` ya usan `.devcontainer/`; PlantHaven completa la
   pila con el mismo patrón.
3. **Paridad con CI:** la imagen del devcontainer es la misma que construyen
   los pipelines (`--target sdk`), así que lo que pasa en el contenedor pasa
   en la integración continua.
4. **Aislamiento:** cada persona puede tener su propio estado de paquetes de
   pub y de Gradle sin tocar el repositorio.

### Cuándo **no** sustituye a Flutter nativo

- **Emulador Android y dispositivo físico:** el emulador necesita KVM
  (virtualización anidada) y los dispositivos reales necesitan `adb` con
  depuración USB. Para `flutter run` en un teléfono real es mejor tener Flutter
  instalado en Windows; el devcontainer sirve para analizar, probar, compilar
  y para la versión web.
- **Compilar iOS:** solo se puede en macOS, con Xcode. Ninguna imagen de Linux
  lo resuelve.

### Cómo se usa

1. Instalar **Docker Desktop** (con WSL2) y la extensión **Dev Containers** de
   VS Code.
2. `code "C:\Users\sault\Documents\para mientras\PlantHaven"`.
3. `Ctrl+Shift+P` → **Dev Containers: Reopen in Container**.
4. La primera vez construye la imagen (la misma del `Dockerfile`); después
   reutiliza la caché.

Al entrar, el contenedor ya tiene ejecutado `flutter pub get` y muestra en la
terminal los comandos de uso habituales.

| Archivo | Contenido |
|---|---|
| `.devcontainer/devcontainer.json` | Nombre, extensión de Dart/Flutter, puertos, comandos. |
| `.devcontainer/docker-compose.yml` | Servicio `app` construido desde el `Dockerfile` (`target: sdk`) + volúmenes de caché. |

### Comandos dentro del devcontainer

```bash
flutter analyze                    # análisis estático
flutter test                       # pruebas (22 casos)
planthaven-web                     # app web en http://localhost:8080
flutter build apk --release        # APK (el NDK ya está en la imagen)
```

### Probar contra la API local

El servicio `app` declara la variable `API_BASE_URL` (staging por defecto). Se
cambia en `.devcontainer/docker-compose.yml` o con un `.env` al lado del
`docker-compose.yml`:

```yaml
API_BASE_URL: "${API_BASE_URL:-https://adopplant-api.onrender.com}"
```

```powershell
# En .devcontainer\.env
API_BASE_URL=http://host.docker.internal:8000
```

Dentro del contenedor, `host.docker.internal` es el host de Docker Desktop
(`extra_hosts: host.docker.internal:host-gateway`), así que alcanza la API
FastAPI que corre en `http://localhost:8000` del host.

---

## 6. Mantenimiento de las versiones

Al actualizar Flutter hay que cambiar **dos** cosas en el `Dockerfile`:

1. `ARG FLUTTER_VERSION=3.47.4`
2. `ARG FLUTTER_SHA256=<nuevo sha256>`

El SHA-256 se saca del manifiesto oficial de Flutter:

```powershell
$r = Invoke-RestMethod "https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json"
$r.releases | Where-Object { $_.version -eq "3.47.4" -and $_.channel -eq "stable" }
# -> hash, dart_sdk_version, sha256
```

Y después conviene actualizar `pubspec.lock` con esa misma versión de Flutter
para que el equipo local y el contenedor usen el mismo SDK.

> El NDK **no** se fija a mano: la construcción lo deduce de
> `flutter.ndkVersion` (el valor que usa `android/app/build.gradle.kts`), así
> que al actualizar Flutter el NDK se ajusta solo.

---

## 7. Qué se ha verificado

Comprobado sobre la imagen `planthaven-flutter:local` (21-oct-2026):

| Comprobación | Resultado |
|---|---|
| `flutter --version` | 3.47.4 · Dart 3.13.3 |
| `flutter analyze` | 0 problemas |
| `flutter test` | 22 pruebas, todas en verde |
| NDK instalado | 28.2.13676358 (r28c), el que exige `flutter.ndkVersion` |
| `flutter build apk --release` | genera `build/app/outputs/flutter-apk/app-release.apk` |
| `docker compose config` (devcontainer) | válido, proyecto `planthaven-dev` |
| Contenido del SDK de Android | plataforma 36, build-tools 36.0.0, platform-tools |
| Chrome | instalado (`/usr/local/bin/chrome`) |

### Problemas encontrados y corregidos

1. **Faltaba el NDK.** `android/app/build.gradle.kts` declara
   `ndkVersion = flutter.ndkVersion`, pero la imagen solo traía el SDK de
   Android. Gradle lo descargaba solo (~1 GB) en cada máquina y en redes
   restringidas el build del APK fallaba. Corregido en el `Dockerfile`.
2. **La URL de la API estaba fija en el código.** `api_config.dart` tenía
   `https://adopplant-api.onrender.com` escrito a fuego, así que para probar
   contra la API local había que editar el fuente. Ahora es
   `String.fromEnvironment('API_BASE_URL', ...)`, con el mismo valor por
   defecto.
3. **Sin atajo para levantar la app web.** Se añadió el script
   `planthaven-web` a la imagen.
