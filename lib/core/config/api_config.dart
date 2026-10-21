/// Configuracion central de la API REST.
class ApiConfig {
  ApiConfig._();

  /// URL base de la API REST.
  ///
  /// Se puede cambiar al compilar, sin tocar el codigo, con
  /// `--dart-define=API_BASE_URL=<url>`:
  ///
  /// ```powershell
  /// # API local de AdopPlant (desde el contenedor o el emulador)
  /// flutter run --dart-define=API_BASE_URL=http://host.docker.internal:8000
  /// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
  /// ```
  ///
  /// Valores habituales:
  ///   - `https://adopplant-api.onrender.com` -> staging (valor por defecto)
  ///   - `http://localhost:8000`               -> API local desde el navegador
  ///   - `http://10.0.2.2:8000`                -> API local desde el emulador
  ///   - `http://host.docker.internal:8000`    -> API local desde un contenedor
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://adopplant-api.onrender.com',
  );
  static const Duration requestTimeout = Duration(seconds: 60);

  static const String loginPath = '/api/auth/login';
  static const String registerPath = '/api/auth/registro';
  static const String forgotPasswordPath = '/api/auth/recuperacion';
  static const String resetPasswordPath = '/api/auth/restablecer-contrasena';
  static const String profilePath = '/api/usuarios/me';
  static const String plantsPath = '/api/plantas';
  static const String myPlantsPath = '/api/plantas/mias';
  static const String requestsPath = '/api/solicitudes';
  static const String receivedRequestsPath = '/api/solicitudes?tipo=recibidas&limite=100';
  static const String myRequestsPath = '/api/solicitudes?tipo=enviadas&limite=100';
}
