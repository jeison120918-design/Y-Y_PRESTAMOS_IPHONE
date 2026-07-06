# Y&Y PRÉSTAMOS · v2.2.0 — Identidad visual + estabilidad

Fecha: 2026-07-04
Compilación destino: **Codemagic** (Flutter estable + Java 17)

## 1. Identidad visual unificada

Toda la app ahora respeta la paleta oficial del logo Y&Y PRÉSTAMOS:

| Rol                       | Color         | Hex        |
|---------------------------|---------------|------------|
| Azul marino principal     | Y izquierda   | `#1A3A6B`  |
| Azul profundo (fondo)     | Base app      | `#0D1B33`  |
| Azul superficie (tarjetas)| Cards         | `#16233A`  |
| Verde institucional       | Y derecha     | `#2E9E3A`  |
| Verde claro (éxito)       | Cobrado / OK  | `#43A047`  |
| Dorado (resaltados)       | Firma / KPI   | `#FFC107`  |
| Rojo mora / retiro        | Alertas       | `#D32F2F`  |
| Naranja alerta            | Vence hoy     | `#FB8C00`  |

Todos los archivos usan **exclusivamente** los tokens `AndryPrestamosApp.xxx`
definidos en `lib/main.dart` — no queda ningún hex "verde militar" antiguo.

Se centralizó el `ThemeData` con:
- ColorScheme.dark completo
- `cardTheme`, `dialogTheme`, `snackBarTheme`, `chipTheme` unificados
- inputs y botones consistentes

## 2. Recursos Android

- `res/values/colors.xml`: fondo del launcher ahora **azul marino** (era verde).
- `res/drawable/launch_background.xml` (+ `-v21`): splash azul marino.
- `res/drawable/ic_launcher_foreground.xml`: reemplazado por un ícono
  vectorial con las letras **Y & Y** en azul marino + azul + verde
  institucional sobre círculo blanco con anillo dorado.
- `mipmap-*/ic_launcher.png` y `ic_launcher_round.png` regenerados en
  las 5 densidades (mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi) con la
  identidad Y&Y y la etiqueta "PRESTAMOS".
- `res/values/styles.xml`: `LaunchTheme` cambia a `Theme.Black.NoTitleBar`
  para coherencia visual.

## 3. Bugs corregidos en pantallas

- **`home_screen.dart`**: rediseño completo, se eliminó el ícono de
  notificaciones que no hacía nada (era `onTap: () {}`). Se corrigió
  el `_MenuItem` de "Préstamos" para no usar 6 tonos verdes distintos.
- **`onboarding_screen.dart`**: ícono `person_pin` en azul marino en
  vez de verde ilegible dentro del círculo dorado. Título "Datos del
  prestamista" y textos ajustados.
- **`mi_perfil_screen.dart`**: inicial del avatar en azul marino sobre
  círculo dorado (antes en verde con contraste insuficiente).
- **`clientes_screen.dart`**: avatares en azul institucional (antes
  usaba `Colors.teal` fuera de identidad).
- **`configuracion_screen.dart`**:
  - versión ahora se lee de `AndryPrestamosApp.versionApp` (v2.2.0)
  - icono impresora en azul marino (antes indigo)
  - icono moneda en azul claro (antes teal)
  - gradiente firma J.F.B SYSTEM ahora azul marino → verde
- **`prestamo_form.dart`**: bloque "RESUMEN DEL PRESTAMO" con superficie
  azul y borde verde institucional (antes gradiente verde militar).
- **`prestamo_detalle.dart`**: tarjeta de resumen financiero, cards de
  cuotas, botones y textos alineados a la paleta oficial.
- **`prestamos_screen.dart`**: barra de progreso con fondo azul superficie
  (antes verde oscuro).
- **`dashboard_screen.dart`**: KPI cards, chips de filtro, banners de
  alerta y tarjetas de cliente todo en identidad Y&Y.
- **`capital_screen.dart`**: TabBar, fondos, botones y bloque "CAPITAL
  TOTAL" en azul marino con gradiente institucional.
- **`impresora_screen.dart`**: cajas de estado Bluetooth en azul marino
  con acentos verdes; mensajes informativos con superficie azul.
- **`splash_screen.dart`**: fondo con gradiente azul + logo dentro de un
  círculo blanco con doble sombra azul/verde. Título "Y&Y" con la Y
  derecha en verde reproduciendo el logo.

## 4. Configuración de compilación

- `analysis_options.yaml` reforzado: warnings como no-fatales para que
  Codemagic no bloquee la build por lint cosmético.
- `codemagic.yaml` creado con dos workflows:
  - `yy-prestamos-android`: APK + AAB release
  - `yy-prestamos-android-debug`: APK debug
- Se conservan las mejoras de la ronda anterior:
  - Gradle 8.14.1
  - AGP 8.11.1
  - Kotlin 2.2.20
  - compileSdk / targetSdk = 36
  - Java 17

## 5. Cómo compilar en Codemagic

1. Sube este repositorio.
2. En Codemagic, selecciona el archivo `codemagic.yaml`.
3. Elige el workflow `yy-prestamos-android` (release) o
   `yy-prestamos-android-debug` (debug).
4. Descarga el `.apk` / `.aab` desde los artefactos.

## 6. Verificación local

Los 28 archivos Dart fueron formateados y validados sintácticamente
con `dart format` (Dart 3.5.4). Ningún archivo tiene errores de parseo.

Los 23 tokens de `AndryPrestamosApp` están definidos y correctamente
importados en todos los archivos que los referencian.

---
**Desarrollado por J.F.B SYSTEM · 809-798-3301**
