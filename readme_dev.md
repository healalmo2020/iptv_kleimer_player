# readme_dev

Guía oficial de trabajo para el desarrollo de **iptv_kleimer_player**.

## 1) Propósito
Definir una ruta clara de implementación para una app Flutter IPTV (Xtream Codes) optimizada para TV, manteniendo calidad técnica, foco de producto y entregas incrementales.

## 2) Alcance funcional (producto)
La app debe cubrir:
- Live TV
- Películas (VOD)
- Series
- EPG
- Favoritos
- Buscador global
- Continuar viendo
- Historial de reproducción
- Persistencia del progreso de reproducción
- Control parental
- Auto reconexión de streams
- Caché local de datos
- Soporte para control remoto TV
- Picture in Picture
- Multiplataforma: Android TV, Android móvil, Tablet, Windows, Linux

Restricción explícita:
- **No incluir descargas de contenido.**

## 3) Fuente API (Xtream Codes)
Base:
- `http://1play.cool:8000`

Autenticación:
- Usuario ingresa manualmente `username` + `password`.

Endpoints principales:
- Login / Account: `/player_api.php?username={username}&password={password}`
- Live Categories: `/player_api.php?username={username}&password={password}&action=get_live_categories`
- Live Streams: `/player_api.php?username={username}&password={password}&action=get_live_streams`
- VOD Categories: `/player_api.php?username={username}&password={password}&action=get_vod_categories`
- VOD Streams: `/player_api.php?username={username}&password={password}&action=get_vod_streams`
- Series: `/player_api.php?username={username}&password={password}&action=get_series`
- Series Info: `/player_api.php?username={username}&password={password}&action=get_series_info&series_id={id}`

## 4) Arquitectura obligatoria
Separación por capas:
- `core`
- `data`
- `domain`
- `presentation`

Patrones y stack:
- Repository Pattern
- Service Layer
- Models / DTOs
- State management moderno: **Riverpod** (preferido)

Persistencia local:
- **Hive** (preferido para MVP) o Isar

Datos a persistir:
- progreso de video
- favoritos
- historial
- último canal visto
- continuar viendo

## 5) Estructura de carpetas objetivo
```text
lib/
   core/
      network/
      utils/
      constants/
   data/
      models/
      repositories/
      datasources/
   domain/
      entities/
      usecases/
   presentation/
      screens/
      widgets/
      controllers/
      providers/
   services/
```

## 6) Reproductor de video
Debe soportar dos opciones seleccionables en Settings:
- Opción 1: `flutter_vlc_player`
- Opción 2: `media_kit` (preferido sobre `video_player` para TV/desktop)

Requisitos del player:
- selector de reproductor
- cambio dinámico de motor
- subtítulos
- selección de audio
- calidad automática
- reconexión automática si falla stream
- fullscreen
- autoplay siguiente episodio
- guardado automático de progreso

## 7) UX/UI (TV-first)
Dirección visual:
- estilo streaming moderno, original
- navegación horizontal
- filas por categoría
- hero banner
- tarjetas grandes para TV

Compatibilidad de navegación:
- FocusNode
- teclado
- D-Pad / control remoto

Pantallas objetivo:
- Login
- Home
- Live TV
- Movies
- Series
- Player
- Search
- Favorites
- Continue Watching
- History
- Settings
- Profile

Home debe incluir:
- Hero Banner
- Continue Watching
- Live TV Categories
- Popular Movies
- Popular Series
- Recently Added
- Favorites

Series:
- flujo `Series -> Seasons -> Episodes`
- autoplay de siguiente episodio

Continue Watching:
- miniatura
- barra de progreso visual
- reanudación automática

## 8) Paquetes base aprobados
- `http`
- `flutter_riverpod`
- `hive` + `hive_flutter`
- `go_router`
- `cached_network_image`
- `flutter_vlc_player`
- `media_kit`
- `animations`

Paquete opcional aprobado:
- `shimmer` (si se implementan skeleton loaders con efecto shimmer)

## 9) Optimización y calidad
Implementar desde etapas tempranas:
- lazy loading
- paginación
- caché de imágenes
- buffering/resiliencia de stream
- manejo sólido de errores
- loading skeletons

## 10) Plan de ejecución por fases
### Fase 1 (MVP técnico)
- Estructura clean architecture
- Login Xtream + sesión local
- Home base
- Live TV listado + reproducción
- Favoritos y progreso local

Prioridad operativa en Fase 1:
1. Estabilidad de reproducción y reconexión básica.
2. Persistencia local (favoritos/progreso/último canal).
3. UX TV (foco, navegación D-Pad, rendimiento de listas).
4. EPG queda fuera del MVP y pasa a Fase 3.

### Fase 2 (contenido extendido)
- VOD completo
- Series con temporadas/episodios
- Continue Watching e Historial
- Búsqueda global

### Fase 3 (experiencia TV avanzada)
- Control parental
- PiP
- EPG
- Reconexión avanzada y tuning de buffering

## 11) Flujo de trabajo diario
1. `flutter pub get`
2. `flutter analyze`
3. `flutter test`
4. Ejecutar build objetivo (`flutter run -d <device>`)
5. Validación manual del flujo afectado

## 12) Política de commits (obligatoria)
Cuando se complete una unidad lógica de trabajo, crear commit descriptivo.

Reglas:
- Commits pequeños y atómicos.
- Un commit por cambio funcional coherente.
- Mensajes claros en presente.

Formato sugerido:
- `feat(auth): add xtream login flow`
- `feat(player): support dynamic engine selector`
- `fix(history): persist resume position correctly`
- `refactor(home): split rows into reusable widgets`
- `chore(deps): update riverpod and go_router`

Checklist antes de commit:
- [ ] `flutter analyze` sin errores nuevos
- [ ] `flutter test` exitoso (cuando aplique)
- [ ] Sin cambios fuera de alcance

## 13) Criterio operativo para este proyecto
- Esta guía es la referencia principal de implementación.
- Si aparece un conflicto, prevalece la instrucción más reciente del usuario.
- Implementar por fases, sin intentar “todo en una sola entrega”.

## 14) Guía de Estilo Visual y UI (Stitch Original)
Esta sección define una base visual inicial. Si en el futuro se formaliza un design system con tokens, prevalecen los tokens del sistema.

A. Paleta de Colores "Deep Stitch"
Cuando generes widgets o temas, usa estrictamente estos códigos:
Background: Color(0xFF0B1426) (Azul espacial profundo).
Surface/Cards: Color(0xFF162544) (Azul marino para tarjetas).
Accent/Focus: Color(0xFF40C4FF) (Cian brillante "Stitch").
Error/Live: Color(0xFFFF5252) (Rojo coral para indicadores "En Vivo").
Text Primary: Color(0xFFFFFFFF) (Blanco puro).
Text Secondary: Color(0xFFB0BEC5) (Gris azulado para descripciones).
B. Reglas de Componentes (Netflix Style)
Tarjetas (ContentCard):
Relación de aspecto: 16:9 para Live/VOD y 2:3 para Posters de Series.
BorderRadius: 12.0.
Efecto Focus: Cuando el FocusNode esté activo, aplicar transform: Matrix4.identity()..scale(1.1), un borde de 3px accentCyan y un BoxShadow neón del mismo color.
Hero Banner:
Ocupar el 70% de la altura de la pantalla en la Home.
Degradado lineal de transparente a 0xFF0B1426 (abajo hacia arriba) para que el texto sea legible.
Side Menu (Navegación TV):
Colapsable. Icono solo cuando no tiene foco, Icono + Texto cuando el foco entra al menú.
C. Animaciones
Usar el paquete animations para transiciones de "Open Container" al abrir el reproductor.
Duración estándar de animaciones de foco: 200ms con Curves.easeInOut.
D. Skeleton Loaders
Implementar Shimmer en color surfaceBlue mientras las imágenes de cached_network_image cargan (usando el paquete opcional `shimmer`).

## 15) Plantilla de tarea de diseño para Copilot
"Copilot, basándote en la sección 16 del readme_dev.md, genera el widget StitchContentCard. Debe manejar el estado de foco para Smart TV, escalar un 10% cuando esté seleccionado y mostrar un borde cian neón. Usa CachedNetworkImage para el poster."

Nota: en la plantilla anterior, donde dice "sección 16" debe entenderse como "sección 14" en esta versión del documento.
