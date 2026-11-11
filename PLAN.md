# PLAN.md — los 10 pasos

Cada paso es un commit que termina en CI verde. No se empieza el siguiente
sin eso. Si un paso resulta mas grande de lo previsto, se parte en dos.

## 1. Base

- `DazzCamApp.swift` con `@main`
- `RootView` con texto en pantalla
- `project.yml` + `Assets.xcassets`
- CI compilando y produciendo `.ipa`

**Listo cuando:** el CI esta verde y el `.ipa` existe como artefacto.

## 2. Camara: preview en vivo

- `CameraSession`: `AVCaptureSession` + `AVCaptureVideoPreviewLayer`
- `CameraPreviewView`: `UIViewRepresentable` que muestra el layer
- Pedir permiso de camara y manejar "denegado"

**Listo cuando:** el CI esta verde. El preview no se puede probar sin telefono,
pero el codigo compila.

## 3. Captura de foto

- `AVCapturePhotoOutput`
- Boton de disparo
- La foto capturada se muestra como `Image` encima del preview

**Listo cuando:** compila y el flujo captura → muestra esta conectado.

## 4. Guardar en fototeca

- `PHPhotoLibrary` para escribir la foto
- Estado de "guardada" visible en pantalla

## 5. Filtro simple

- Un `CIFilter` (temperatura o saturacion) aplicado a la foto capturada
- Selector de 3-4 ajustes fijos

## 6. Filtro en vivo

- El filtro se aplica al preview usando `AVCaptureVideoDataOutput` + `CIImage`
- Aqui recien se puede pensar en `MTKView` si el rendimiento no alcanza

## 7. Galeria

- Cuadricula de fotos tomadas dentro de la app
- Guardadas en el directorio de documentos, no solo en la fototeca

## 8. Video

- `AVCaptureMovieFileOutput`
- Grabar, parar, guardar en fototeca

## 9. Ajustes

- `@AppStorage` para preferencias: calidad, espejo, rejilla

## 10. Pulido

- Icono definitivo, animaciones, transiciones, sonidos de obturador

## Fuera de alcance (por ahora)

- Metal/Render pipeline propio
- Filtros "grabados" en video en tiempo real
- Importar fotos externas
- Camaras multiples y zoom optico
