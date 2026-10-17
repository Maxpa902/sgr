# SGR

SGR es una aplicación para registrar y dar seguimiento a reclamos ciudadanos. La app móvil está hecha con Flutter y se comunica con un servidor Laravel mediante una API HTTP. El servidor guarda los datos y centraliza la lógica del sistema.

## Estructura

```text
sgr/
├── mobile/   # Aplicación Flutter
└── server/   # API Laravel y entorno local con Docker Compose
```

La app abre en la pantalla de inicio de sesión. Desde ahí se puede crear una cuenta de vecino (con DNI) o ingresar con una existente; la sesión queda guardada en el celular hasta que se cierra.

## Requisitos

- Git
- Docker Desktop (Windows/macOS) o Docker Engine con Docker Compose (Linux)
- Flutter SDK, incluyendo Dart
- Para Android: Android Studio, Android SDK y un emulador configurado, o un dispositivo Android con depuración USB
- Para iOS: macOS y Xcode; se puede usar el simulador de iOS o un iPhone configurado para desarrollo
- En Windows: el **Modo de desarrollador** activado (*Configuración → Sistema → Para programadores*). Flutter lo necesita para compilar apps con plugins, como el que guarda la sesión

Comprobá las herramientas con:

```bash
docker --version
docker compose version
flutter --version
flutter doctor -v
```

## 1. Levantar Laravel

Desde la raíz del repositorio, prepará el entorno local:

```bash
cd server
cp .env.example .env
```

En Linux/macOS se usa `cp`. En PowerShell, el equivalente es:

```powershell
Copy-Item .env.example .env
```

Iniciá los servicios en segundo plano:

```bash
docker compose up -d --build
```

La primera ejecución construye la imagen e instala dependencias. Comprobá el arranque y consultá los registros con:

```bash
docker compose ps
docker compose logs -f app
```

La primera vez, generá la clave de la aplicación y creá la base con sus datos iniciales (estados y categorías de reclamo):

```bash
docker compose exec app php artisan key:generate
docker compose exec app php artisan migrate --seed
```

Cada vez que se agreguen migraciones nuevas, volvé a ejecutar `docker compose exec app php artisan migrate`. Los tests se ejecutan con `docker compose exec app php artisan test`.

Laravel estará disponible en:

- Aplicación Laravel: <http://localhost:8081>
- Estado de la API: <http://localhost:8081/api/status>
- Vite (recursos web en desarrollo): puerto `5175`

La base de datos de desarrollo está configurada como SQLite. Para detener los servicios:

```bash
docker compose down
```

Para ver los registros de Vite, usá `docker compose logs -f node`.

## 2. Preparar y ejecutar Flutter

En otra terminal, desde la raíz del repositorio:

```bash
cd mobile
flutter pub get
flutter devices
```

`flutter devices` muestra los destinos disponibles. Elegí uno de los siguientes métodos.

Los tests de la app se ejecutan con `flutter test` desde la carpeta `mobile`. Simulan las respuestas del servidor, así que no necesitan Docker.

### Chrome

Iniciá el servidor Laravel en Docker y ejecutá:

```bash
flutter run -d chrome --dart-define=SERVER_URL=http://localhost:8081
```

### Windows o Linux de escritorio

Flutter debe tener habilitado el destino de escritorio correspondiente. Luego:

```bash
# Windows
flutter run -d windows --dart-define=SERVER_URL=http://localhost:8081

# Linux
flutter run -d linux --dart-define=SERVER_URL=http://localhost:8081
```

### Emulador Android

Iniciá un emulador desde Android Studio y verificá que aparezca en `flutter devices`. Luego ejecutá:

```bash
flutter run -d android --dart-define=SERVER_URL=http://10.0.2.2:8081
```

En Android Emulator, `10.0.2.2` permite acceder al `localhost` de la computadora anfitriona. No reemplazar por `localhost`, porque dentro del emulador esa dirección apunta al propio emulador.

### Teléfono Android físico

Conectá el teléfono y la computadora a la misma red Wi-Fi, habilitá la depuración USB y aceptá el aviso de autorización del teléfono. Averiguá la IP local de la computadora (por ejemplo `192.168.1.25`) y ejecutá:

```bash
flutter run -d <ID_DEL_DISPOSITIVO> --dart-define=SERVER_URL=http://192.168.1.25:8081
```

Reemplazá la IP por la de tu computadora. Si no conecta, revisá que Docker publique el puerto `8081` y que el firewall permita conexiones entrantes a ese puerto desde la red local.

### Simulador iOS o iPhone

En macOS, iniciá el simulador desde Xcode o conectá un iPhone preparado para desarrollo. Para el simulador:

```bash
flutter run -d ios --dart-define=SERVER_URL=http://localhost:8081
```

Para un iPhone físico, usá la IP local de la Mac en `SERVER_URL`, igual que con el teléfono Android.

## Configuración de la URL

La app acepta la URL base del servidor con `--dart-define=SERVER_URL=...`. El valor predeterminado del código es `http://10.0.2.2:8081`, apropiado para Android Emulator. Usá la dirección adecuada al destino donde se ejecuta Flutter:

| Destino Flutter | URL base local |
| --- | --- |
| Chrome o escritorio en la misma PC | `http://localhost:8081` |
| Android Emulator | `http://10.0.2.2:8081` |
| Teléfono físico en la misma red | `http://IP_LOCAL_DE_LA_PC:8081` |
| iOS Simulator en Mac | `http://localhost:8081` |

`SERVER_URL` es la URL base; la app le agrega las rutas de la API, por ejemplo `/api/login`. Se define en `mobile/lib/config.dart`. En producción se debe configurar un dominio con HTTPS y quitar los permisos de HTTP sin cifrar habilitados para el desarrollo local.
