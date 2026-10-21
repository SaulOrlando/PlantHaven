# Refactorización MVC + Service Layer — PlantHaven

## Fecha: 2026-09-29

## Descripción general

Se refactorizó completamente el proyecto Flutter de **Clean Architecture con datos mock** a una arquitectura **MVC + Service Layer** conectada a la API REST real de AdopPlant.

---

## API REST conectada

- **Base URL:** `https://adopplant-api.onrender.com` (staging). Se puede cambiar al
  compilar sin tocar el código: `flutter run --dart-define=API_BASE_URL=<url>`
  (ver `lib/core/config/api_config.dart`).

### Endpoints implementados

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| POST | `/api/auth/login` | Iniciar sesión. Body: `{identificador, contrasena}`. Retorna `{access_token, token_type}` |
| POST | `/api/auth/register` | Registrar usuario. Body: `{nombre, apellido, correo, telefono, contrasena, confirmar_contrasena}`. Retorna datos del usuario (201) |
| GET | `/api/usuarios/me` | Obtener perfil del usuario autenticado. Requiere header `Authorization: Bearer <token>` |
| PATCH | `/api/usuarios/me` | Actualizar datos personales. Body: `{nombre, apellido, correo, telefono}` |
| GET | `/api/categorias` | Obtener las categorías disponibles con sus IDs reales para el formulario de plantas |

### Corrección del formulario de publicación de plantas (2026-09-30)

Se corrigió el error `ApiException(404): Categoría no encontrada`, que se producía porque el selector de categorías utilizaba una lista fija con IDs asumidos (`2`, `3` y `4`). La implementación actual obtiene las categorías desde el backend antes de mostrar el formulario.

#### Flujo implementado

1. `PlantFormView._prepare()` llama a `PlantController.loadCategories()` al abrir el formulario.
2. `PlantController.loadCategories()` delega la consulta a `PlantService.GetCategories()` y conserva la lista en `categories`.
3. `PlantService.GetCategories()` realiza `GET /api/categorias`.
4. El selector muestra `PlantCategory.nombre` y guarda `PlantCategory.idCategoria` en `_categoryId`.
5. `PlantRequest.toJson()` envía el ID seleccionado en el campo que espera la API:

La petición de categorías utiliza `ApiService.Get()`, que obtiene los headers mediante `AuthHeaders()` y agrega `Authorization: Bearer <token>` cuando existe una sesión activa.

Si la petición falla, `PlantController.loadCategories()` ejecuta `print(e)` para mostrar el error exacto en la Consola de Depuración y carga las categorías locales de respaldo (`Interior`, `Exterior` y `Suculenta`). El mismo respaldo se usa cuando el servidor responde correctamente pero devuelve una lista vacía, garantizando que el selector siempre tenga opciones.

```json
{
  "nombre": "Monstera deliciosa",
  "tamano": "Mediano",
  "nivel_cuidado": "Luz indirecta y riego semanal",
  "estado_salud": "Excelente",
  "necesidad_luz": "Media",
  "necesidad_agua": "Medio",
  "ubicacion": "Santa Tecla",
  "id_categoria": 12,
  "descripcion": "Planta saludable"
}
```

El valor `12` del ejemplo debe ser reemplazado por el ID entregado por `GET /api/categorias`; no se debe volver a introducir un ID fijo en la interfaz.

#### Registro temporal del payload

Antes de enviar la petición se imprime el JSON completo en la consola:

```text
[PlantService] POST /api/plantas/ payload: {"...":"...","id_categoria":12}
```

Para ediciones también se registra el payload del `PATCH`. Esta salida permite comprobar el ID de categoría y el resto de los campos antes de investigar el backend. Si se publica una versión de producción y no se desea mostrar información del formulario en consola, estas trazas deben eliminarse o protegerse con una condición de modo debug.

#### Compatibilidad de respuestas

El parser de categorías acepta una respuesta como lista directa o envuelta en `items`, `categorias` o `data`. Para el ID admite `id_categoria`, `categoria_id` o `id`; para el nombre admite `nombre`, `name` o `descripcion`. Si el endpoint cambia, se debe actualizar principalmente `PlantService.GetCategories()` y `PlantCategory.fromJson()`.

#### Archivos modificados

- `lib/views/plant_form_view.dart`: elimina categorías hardcoded y usa las categorías cargadas desde la API.
- `lib/controllers/plant_controller.dart`: agrega `loadCategories()` y el estado `categories`.
- `lib/services/plant_service.dart`: agrega el `GET /api/categorias` y el registro del payload de `POST`/`PATCH`.
- `lib/models/plant_model.dart`: permite mapear los IDs y nombres de categoría devueltos por la API.

---

## Nueva estructura de carpetas

```
lib/
├── models/
│   ├── user_model.dart          # Mapeo de datos del usuario (fromJson/toJson)
│   └── auth_model.dart          # Mapeo de Login, Token y requests (LoginRequest, RegisterRequest, UpdateProfileRequest)
├── services/
│   ├── api_service.dart         # Cliente HTTP base + headers Bearer token (get/post/patch)
│   └── auth_service.dart        # Llamadas a la API (login, register, getProfile, updateProfile) + manejo de errores
├── controllers/
│   └── auth_controller.dart     # Lógica de negocio, estado de sesión, manejo de errores, ChangeNotifier
├── views/
│   ├── login_view.dart          # Pantalla de login
│   ├── register_view.dart       # Pantalla de registro
│   ├── profile_view.dart        # Pantalla de perfil (ver/editar datos, logout)
│   └── widgets/                 # Componentes visuales reutilizables
│       ├── auth_text_field.dart
│       ├── auth_button.dart
│       ├── auth_card.dart
│       └── password_strength_indicator.dart
├── utils/
│   └── session_manager.dart    # Almacenamiento seguro del access_token (flutter_secure_storage)
├── core/
│   ├── constants/
│   │   ├── app_colors.dart      # Paleta de colores
│   │   ├── app_routes.dart      # Nombres de rutas
│   │   └── app_strings.dart     # Textos centralizados
│   └── routes/
│       └── app_router.dart      # Router con GoRouter
├── injection_container.dart     # Inyección de dependencias (GetIt)
└── main.dart                    # Punto de entrada
```

---

## Responsabilidades por capa

### Models (`lib/models/`)
- `UserModel`: Mapea `id_usuario`, `nombre`, `apellido`, `correo`, `telefono`, `estado`, `fecha_registro`
- `AuthModel`: Mapea `access_token` y `token_type`
- `LoginRequest`, `RegisterRequest`, `UpdateProfileRequest`: DTOs para el body de las peticiones

### Services (`lib/services/`)
- `ApiService`: Configuración base HTTP. Construye la URL base, maneja headers JSON y agrega `Authorization: Bearer <token>` en cada petición. Métodos: `get()`, `post()`, `patch()`.
- `AuthService`: Aísla las llamadas a la API. Traduce respuestas HTTP a excepciones `ApiException` con código de estado y mensaje. Extrae errores de validación 422 del formato FastAPI.

### Controllers (`lib/controllers/`)
- `AuthController`: ChangeNotifier que gestiona el estado (`initial`, `loading`, `authenticated`, `error`).
  - `login()`: Llama a la API, guarda el token y **precarga el perfil** automáticamente (GET /api/usuarios/me).
  - `register()`: Registra al usuario y luego hace login automático.
  - `loadProfile()`: Carga el perfil del usuario autenticado.
  - `updateProfile()`: Actualiza los datos personales.
  - `logout()`: Elimina el token y limpia el estado.
  - `checkSession()`: Verifica si hay sesión activa al iniciar la app.
  - Traduce errores de la API a mensajes amigables en español.

### Views (`lib/views/`)
- `LoginView`: Formulario de login con identificador (correo o teléfono) y contraseña.
- `RegisterView`: Formulario de registro con todos los campos + indicador de fortaleza de contraseña.
- `ProfileView`: Muestra datos del usuario, permite editarlos y cerrar sesión.
- Widgets reutilizables: `AuthTextField`, `AuthButton`, `AuthCard`, `PasswordStrengthIndicator`.

### Utils (`lib/utils/`)
- `SessionManager`: Guarda el access_token de forma cifrada usando `flutter_secure_storage`.

---

## Manejo de errores

### Códigos HTTP manejados

| Código | Mensaje al usuario |
|--------|-------------------|
| 400 | "Solicitud incorrecta. Verifica los datos enviados." |
| 401 | "Credenciales inválidas. Verifica tu correo y contraseña." |
| 403 | "Acceso denegado. No tienes permisos para esta acción." |
| 404 | "Recurso no encontrado." |
| 409 | "El correo o teléfono ya está registrado." |
| 422 | "Error de validación. Verifica los campos del formulario." (extrae errores campo por campo) |
| 500 | "Error del servidor. Inténtalo más tarde." |

### Formato de errores 422 (FastAPI)

El servicio extrae errores del formato:
```json
{
  "detail": [
    {"loc": ["body", "correo"], "msg": "value is not a valid email address", "type": "value_error.email"}
  ]
}
```
Y los traduce a mensajes amigables en español.

---

## Dependencias agregadas

```yaml
http: ^1.2.2
flutter_secure_storage: ^9.2.2
```

---

## Archivos eliminados

- `lib/features/` (toda la estructura Clean Architecture anterior)
- `lib/core/errors/failures.dart`
- `lib/core/network/network_info.dart`

---

## Flujo de autenticación

1. **Login exitoso:**
   - `POST /api/auth/login` → recibe `access_token`
   - Guarda el token en `flutter_secure_storage`
   - Llama automáticamente a `GET /api/usuarios/me` para precargar el perfil
   - Navega a la vista de perfil

2. **Registro exitoso:**
   - `POST /api/auth/register` → crea el usuario
   - Hace login automático con las credenciales creadas
   - Guarda el token y navega a la vista de perfil

3. **Sesión persistente:**
   - Al iniciar la app, `checkSession()` verifica si hay un token almacenado
   - Si existe, carga el perfil automáticamente

4. **Logout:**
   - Elimina el token del almacenamiento seguro
   - Limpia el estado y navega al login

---

## Comandos útiles

```bash
# Instalar dependencias
flutter pub get

# Analizar código
flutter analyze

# Ejecutar la app
flutter run
```
