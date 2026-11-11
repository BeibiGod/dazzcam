# CLAUDE.md — reglas de este proyecto

Este archivo manda sobre cualquier otra costumbre. Si una instruccion del usuario
choca con estas reglas, pregunta antes de romperlas.

## La regla unica

**Nada de codigo sin compilar.**

Cada cambio termina con un CI en verde. Si el CI esta rojo, no se escribe nada
nuevo hasta arreglarlo. No existe "lo dejo pendiente y sigo".

## El ciclo obligatorio

```
1. hacer UN cambio pequeno
2. commit + push
3. esperar a que ios-build termine en verde
4. si esta rojo: leer el error real del log y arreglarlo (volver a 2)
5. solo entonces: siguiente cambio
```

Commit pequeno, un tema por commit. El historial es la lista de cosas que
de verdad funcionan.

## Prohibido

- Escribir varios archivos nuevos en un solo paso sin compilar entre ellos.
- Decir porcentajes de avance. El avance se mide asi: cuantos pasos de
  `PLAN.md` estan en verde en CI. Nada mas. No hay otra fuente de verdad.
- Agregar frameworks (Metal, MetalKit, CoreMotion, Vision, etc.) antes de que
  la base compile y tengamos camara funcionando. Primero simple, luego rapido.
- Inventar APIs. Si no estas seguro de la firma de un metodo, usa la version
  mas simple y deja que el compilador decida.
- Tocar `project.yml` para "arreglar" un error de compilacion. El error esta en
  el Swift, no en el proyecto.

## Orden de construccion (un paso = un CI verde)

1. **Base** — app vacia que arranca. (ya hecho, este commit)
2. **Camara** — preview en vivo con AVCaptureSession, sin capturar.
3. **Foto** — boton que captura un frame y lo muestra en pantalla.
4. **Guardar** — la foto capturada se guarda en la fototeca.
5. **Filtro simple** — un filtro de color con CoreImage sobre la foto capturada.
6. **Filtro en vivo** — el filtro aplicado al preview de la camara.
7. **Galeria** — cuadricula de fotos tomadas dentro de la app.
8. **Video** — grabar y guardar video.
9. **Ajustes** — preferencias persistentes.
10. **Pulido** — iconos, animaciones, detalles visuales.

Ningun paso empieza antes de que el anterior este verde en CI.

## Datos fijos

- Bundle ID: `com.diego.dazzcam`
- Deployment target: iOS 17.0
- Solo iPhone, solo vertical
- Swift 5 (modo lenguaje 5), no Swift 6
- El proyecto `.xcodeproj` NO se commitea: lo genera XcodeGen desde `project.yml`

## Como se compila (referencia)

En la nube, cada push a `main` corre `.github/workflows/ios-build.yml`:
genera el proyecto con `xcodegen`, compila para simulador y produce
`DazzCam-unsigned.ipa` como artefacto descargable.

En Windows no se compila nada. No existe Xcode ni el SDK de iOS para Windows.
Nunca propongas compilar localmente.
