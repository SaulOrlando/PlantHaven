# syntax=docker/dockerfile:1
#
# ===========================================================================
# Imagen de Flutter/Dart para PlantHaven
# ===========================================================================
#
# ¿Por qué una imagen propia? Porque el SDK de Flutter NO viene en una imagen
# oficial de Docker y esta máquina (Windows) no lo tiene instalado. La imagen
# fija una toolchain reproducible para todo el equipo: mismo Flutter, mismo
# Dart, mismo JDK, mismo SDK de Android y mismo resultado de compilación.
#
# Versiones fijadas (no flotantes, para que la imagen sea reproducible):
#
#   Flutter  3.47.4  -> Dart 3.13.3
#       Es EXACTAMENTE la versión con la que se creó el proyecto: la lleva
#       grabada en .metadata (revision 9584c671..., channel stable) y en
#       pubspec.yaml (environment: sdk: ^3.13.3).
#       Importante: la imagen de la comunidad `ghcr.io/cirruslabs/flutter`
#       llega a 3.44.0 / Dart 3.12.0 y NO sirve, porque `flutter pub get`
#       falla con "requires SDK version ^3.13.3". Por eso el SDK se descarga
#       aquí desde el archivo oficial, con su SHA-256 verificado.
#
#   JDK 17  -> AGP 9.1 y Gradle 9.3.1 exigen Java 17 o superior.
#   Android SDK 36 + build-tools 36.0.0 -> compileSdk/targetSdk que usa
#       Flutter 3.47 (36) y el que exige AGP 9.
#   Android NDK (el que fija flutter.ndkVersion) -> android/app/build.gradle.kts
#       declara `ndkVersion = flutter.ndkVersion`; sin NDK, "flutter build apk"
#       depende de que Gradle lo descargue en cada máquina o falla.
#
# ---------------------------------------------------------------------------
# Destinos de build
# ---------------------------------------------------------------------------
#   docker build -t planthaven-flutter .                       -> SDK (por defecto)
#   docker build -t planthaven-flutter --target sdk .          -> SDK (idem)
#   docker build -t planthaven-web --target app .              -> app web con nginx
#   docker build --target apk --output type=local,dest=dist .  -> dist\planthaven.apk
#
# Uso de la imagen del SDK:
#   docker run --rm -it -v "${PWD}:/app" -w /app planthaven-flutter flutter test
#   docker run --rm -it -v "${PWD}:/app" -w /app planthaven-flutter flutter analyze
#   docker run --rm -it -p 8080:8080 -v "${PWD}:/app" -w /app planthaven-flutter \
#       flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0
#
# Uso de la imagen web (la app Flutter compilada):
#   docker run --rm -p 8080:8080 planthaven-web   ->  http://localhost:8080
#
# La imagen web consume la API en https://adopplant-api.onrender.com (valor
# por defecto en lib/core/config/api_config.dart). Para apuntar a otra API sin
# tocar el código se usa --dart-define=API_BASE_URL=<url>:
#   - emulador Android .......... http://10.0.2.2:8000
#   - web en Docker ............. http://host.docker.internal:8000
#   - navegador del host ........ http://localhost:8000

# ---------------------------------------------------------------------------
# Versiones fijadas
# ---------------------------------------------------------------------------
ARG FLUTTER_VERSION=3.47.4
# SHA-256 oficial del archivo stable/linux/flutter_linux_3.47.4-stable.tar.xz
ARG FLUTTER_SHA256=5b45f0ceda99b9bebdc873e7e69f6450aeb4c30f454b505e2e62fc9255a907d3
ARG ANDROID_CMDLINE_TOOLS=13114758
ARG ANDROID_PLATFORM=36
ARG ANDROID_BUILD_TOOLS=36.0.0

# ===========================================================================
# Etapa 1: toolchain de Flutter + Dart
# ===========================================================================
FROM ubuntu:24.04 AS toolchain

ARG FLUTTER_VERSION
ARG FLUTTER_SHA256
ARG ANDROID_CMDLINE_TOOLS
ARG ANDROID_PLATFORM
ARG ANDROID_BUILD_TOOLS

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    TZ=UTC \
    FLUTTER_ROOT=/opt/flutter \
    FLUTTER_SUPPRESS_ANALYTICS=true \
    FLUTTER_CLI_TELEMETRY_ENABLED=false \
    JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 \
    ANDROID_HOME=/opt/android-sdk \
    ANDROID_SDK_ROOT=/opt/android-sdk \
    PUB_CACHE=/opt/pub-cache \
    GRADLE_USER_HOME=/opt/gradle-cache \
    CHROME_EXECUTABLE=/usr/local/bin/chrome \
    PATH=/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:/opt/android-sdk/cmdline-tools/latest/bin:/opt/android-sdk/platform-tools:${PATH}

# Dependencias del sistema:
#   - openjdk-17-jdk-headless : JDK que exigen AGP 9 / Gradle 9
#   - clang, cmake, ninja, pkg-config, libgtk-3-dev : para `flutter build linux`
#   - xz-utils, unzip, zip      : para descomprimir el SDK de Flutter
#   - git                       : Flutter es un checkout de git y lo consulta
#   - fonts-liberation / fonts-noto-color-emoji : tipografías del sistema
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl git unzip xz-utils zip \
      clang cmake ninja-build pkg-config \
      libgtk-3-dev libglu1-mesa libstdc++-13-dev \
      openjdk-17-jdk-headless \
      fonts-liberation fonts-noto-color-emoji \
 && rm -rf /var/lib/apt/lists/*

# El SDK de Flutter se descarga del archivo oficial y se verifica el SHA-256:
# así nadie puede colar un binario modificado en la imagen.
RUN curl -fsSL -o /tmp/flutter.tar.xz \
      "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
 && echo "${FLUTTER_SHA256}  /tmp/flutter.tar.xz" | sha256sum -c - \
 && tar -xf /tmp/flutter.tar.xz -C /opt \
 && rm /tmp/flutter.tar.xz \
 && git config --system --add safe.directory /opt/flutter

# SDK de Android: cmdline-tools + platform-tools + plataforma 36 + build-tools
# + NDK.
# `sdkmanager --licenses` acepta las licencias para que `flutter build apk`
# no se quede pidiendo permiso.
#
# EL NDK NO VA EN LA LISTA DE FORMA FIJA A PROPÓSITO: el proyecto declara
# `ndkVersion = flutter.ndkVersion` en android/app/build.gradle.kts, y ese
# valor lo fija el SDK de Flutter instalado arriba (28.2.13676358 en Flutter
# 3.47.4). Se lee del propio SDK para que, al actualizar Flutter, el NDK se
# ajuste solo. Sin NDK, `flutter build apk` depende de que Gradle lo descargue
# solo (red + ~1 GB en cada máquina) o directamente falla.
#
# La carpeta `sources` del NDK (el código fuente del NDK, ~1,3 GB) se borra
# porque no la usa la compilación: AGP solo necesita el toolchain.
RUN set -eux; \
    mkdir -p "${ANDROID_HOME}/cmdline-tools"; \
    curl -fsSL -o /tmp/cmdline-tools.zip \
      "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS}_latest.zip"; \
    unzip -q /tmp/cmdline-tools.zip -d "${ANDROID_HOME}/cmdline-tools"; \
    mv "${ANDROID_HOME}/cmdline-tools/cmdline-tools" "${ANDROID_HOME}/cmdline-tools/latest"; \
    rm /tmp/cmdline-tools.zip; \
    yes | sdkmanager --licenses > /dev/null; \
    NDK_VERSION="$(sed -n 's/.*val ndkVersion: String = "\([^"]*\)".*/\1/p' \
      /opt/flutter/packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt | head -1)"; \
    test -n "${NDK_VERSION}"; \
    echo "NDK que exige flutter.ndkVersion: ${NDK_VERSION}"; \
    sdkmanager --install \
      "platform-tools" \
      "platforms;android-${ANDROID_PLATFORM}" \
      "build-tools;${ANDROID_BUILD_TOOLS}" \
      "ndk;${NDK_VERSION}"; \
    rm -rf "${ANDROID_HOME}/ndk/${NDK_VERSION}/sources"; \
    test -f "${ANDROID_HOME}/ndk/${NDK_VERSION}/source.properties"

# Google Chrome: permite `flutter run -d chrome` (demostraciones y pruebas E2E
# de la versión web) sin instalar nada en el equipo del desarrollador.
RUN curl -fsSL -o /tmp/chrome.deb \
      "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" \
 && apt-get update \
 && apt-get install -y --no-install-recommends /tmp/chrome.deb \
 && rm /tmp/chrome.deb \
 && rm -rf /var/lib/apt/lists/* \
 && printf '#!/bin/sh\n# Chrome dentro de un contenedor corre como root: necesita --no-sandbox\nexec /usr/bin/google-chrome-stable --no-sandbox --disable-dev-shm-usage --disable-gpu "$@"\n' > /usr/local/bin/chrome \
 && chmod +x /usr/local/bin/chrome

# Warming de cachés: se descargan aquí los artefactos de motor (Android, web y
# Linux) para que ni `flutter test` ni `flutter build` necesiten red más tarde.
# Nota: desde Flutter 3.47 el comando `flutter config` ya NO admite los flags
# --enable-web / --enable-linux-desktop (web y escritorio Linux están activos
# por defecto), por eso aquí solo se desactiva la telemetría.
RUN flutter config --no-analytics \
 && flutter precache --no-android_maven --android --web --linux \
 && flutter --version

# Usuario no root para el devcontainer (VS Code conecta como "vscode").
# Las cachés de pub y de Gradle viven fuera del proyecto para poder montarlas
# como volúmenes y no volver a descargarlas en cada reconstrucción.
#
# OJO: la imagen base ubuntu:24.04 YA trae una cuenta "ubuntu" con UID 1000,
# así que `useradd --uid 1000` falla con "UID 1000 is not unique". La
# solución es renombrar esa cuenta (y su grupo) a "vscode", con lo que además
# se conservan los grupos de sistema (sudo, adm, ...). Si una versión futura
# de la base ya no trae esa cuenta, se crea limpia.
RUN set -eux; \
    if getent passwd ubuntu >/dev/null; then \
        groupmod -n vscode ubuntu; \
        usermod -l vscode ubuntu; \
        usermod -d /home/vscode -m vscode; \
        usermod -c "" vscode; \
    else \
        useradd --create-home --shell /bin/bash --uid 1000 vscode; \
    fi; \
    mkdir -p /opt/gradle-cache; \
    chown -R vscode:vscode /opt/flutter /opt/pub-cache /opt/gradle-cache "${ANDROID_HOME}"; \
    git config --system --add safe.directory '*'

WORKDIR /app

# Atajo para levantar la app web desde el contenedor (devcontainer o
# `docker run`). La URL de la API se inyecta con --dart-define, de modo que se
# puede apuntar a staging o a la API local sin recompilar ni tocar el código:
#   API_BASE_URL=http://host.docker.internal:8000 planthaven-web
RUN printf '%s\n' \
  '#!/bin/sh' \
  '# Levanta la app web de PlantHaven dentro del contenedor.' \
  '#   planthaven-web                                                    -> staging' \
  '#   API_BASE_URL=http://host.docker.internal:8000 planthaven-web      -> API local' \
  'set -e' \
  'cd "${WORKSPACE:-/workspaces/planthaven}"' \
  'exec flutter run -d web-server --web-port "${WEB_PORT:-8080}" --web-hostname 0.0.0.0 --dart-define="API_BASE_URL=${API_BASE_URL:-https://adopplant-api.onrender.com}"' \
  > /usr/local/bin/planthaven-web \
 && chmod +x /usr/local/bin/planthaven-web

# Memoria del daemon de Gradle.
#
# android/gradle.properties pide -Xmx8G y 4 GB de metaspace. En un equipo de
# 8 GB de RAM eso hace que la VM de WSL2 se quede sin memoria a mitad del
# "flutter build apk" y el daemon de Docker se caiga (error "unexpected EOF"
# y el build se queda colgado).
#
# Este archivo vive en GRADLE_USER_HOME y, por el orden de precedencia de
# Gradle, tiene PRIORIDAD sobre el del proyecto: primero se lee el
# gradle.properties del usuario y después el del proyecto. Aquí se limita el
# heap a 2 GB, que de sobra para esta app.
#
# Para darle más memoria: docker build --build-arg GRADLE_HEAP=4g .
ARG GRADLE_HEAP=2g
RUN printf 'org.gradle.jvmargs=-Xmx%s -XX:MaxMetaspaceSize=1g -XX:ReservedCodeCacheSize=256m\n' "${GRADLE_HEAP}" \
  > /opt/gradle-cache/gradle.properties \
 && chown vscode:vscode /opt/gradle-cache/gradle.properties \
 && cat /opt/gradle-cache/gradle.properties

# ===========================================================================
# Etapa 2: compilación de la versión web
# ===========================================================================
FROM toolchain AS web-builder

# Primero solo los manifiestos: la restauración de paquetes se reutiliza
# mientras no cambien pubspec.yaml / pubspec.lock.
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

# `flutter build web` genera build/web con el bundle de la app.
RUN flutter build web --release

# ===========================================================================
# Etapa 3: compilación del APK de Android
# ===========================================================================
FROM web-builder AS apk-builder

# Mismo límite de memoria que en la etapa `sdk` (ver el comentario allí):
# sin esto el build del APK pide -Xmx8G y tumba el daemon de Docker en
# equipos de 8 GB de RAM.
ARG GRADLE_HEAP=2g
RUN printf 'org.gradle.jvmargs=-Xmx%s -XX:MaxMetaspaceSize=1g -XX:ReservedCodeCacheSize=256m\n' "${GRADLE_HEAP}" \
  > /opt/gradle-cache/gradle.properties \
 && chown vscode:vscode /opt/gradle-cache/gradle.properties

# El APK release sale firmado con las llaves de debug (mismo criterio que el
# android/app/build.gradle.kts del proyecto); para producción hay que
# configurar un keystore propio.
RUN flutter build apk --release

# ===========================================================================
# Etapa 4: artefacto APK suelto (para extraerlo con --output)
# ===========================================================================
FROM scratch AS apk

COPY --from=apk-builder /app/build/app/outputs/flutter-apk/app-release.apk /planthaven.apk

# ===========================================================================
# Etapa 5: imagen servible de la app web
# ===========================================================================
FROM nginx:1.29-alpine AS app

COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=web-builder /app/build/web /usr/share/nginx/html

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://127.0.0.1:8080/ || exit 1

# ===========================================================================
# Destino por defecto: la imagen de Flutter/Dart pedida
# ===========================================================================
FROM toolchain AS sdk
