# DazzCam

App de camara con filtros para iPhone, estilo Dazz Cam. Proyecto rehecho
desde cero con una regla: **cada linea de codigo que existe ya compilo.**

## Estado

| Paso | Estado |
|---|---|
| 1. Base (app que arranca) | ✅ compila en 2m33s, `.ipa` generado |
| 2. Camara (preview en vivo) | 🟡 en compilacion |
| 3. Captura de foto | ⬜ |
| 4. Guardar en fototeca | ⬜ |
| 5. Filtro simple | ⬜ |
| 6. Filtro en vivo | ⬜ |
| 7. Galeria | ⬜ |
| 8. Video | ⬜ |
| 9. Ajustes | ⬜ |
| 10. Pulido | ⬜ |

## Como funciona

```
cambio en el codigo  ->  push a GitHub  ->  Mac en la nube compila
                                                  |
                                    ¿verde?  si -> siguiente paso
                                             no -> se arregla antes de seguir
                                                  |
                                     descarga DazzCam-unsigned.ipa
                                                  |
                          Sideloadly / 3uTools + tu Apple ID  ->  iPhone
```

No hace falta Mac. La compilacion corre gratis en GitHub Actions y el `.ipa`
se firma e instala desde Windows.

## Instalar en el iPhone

1. En GitHub: pestana **Actions** → ultimo run verde → **Artifacts** →
   descargar `DazzCam-unsigned-ipa`.
2. Descomprimir (viene en `.zip`, dentro esta `DazzCam-unsigned.ipa`).
3. Abrir **Sideloadly** (o 3uTools → Sideload) con el iPhone conectado.
4. Arrastrar el `.ipa`, poner tu Apple ID y firmar.
5. En el iPhone: **Ajustes → General → VPN y gestion de dispositivos** →
   confiar en tu Apple ID.

Con Apple ID gratis la app caduca a los **7 dias** y hay que volver a firmarla.
Con cuenta de desarrollador ($99/anio) dura un anio.

## Estructura

```
project.yml                      proyecto de Xcode (generado por XcodeGen)
DazzCam/App/                     arranque de la app
DazzCam/Resources/Assets.xcassets icono y colores
.github/workflows/ios-build.yml  compilacion en la nube
CLAUDE.md                        reglas del agente que trabaja aqui
PLAN.md                          los 10 pasos en detalle
```

## Reglas

- El `.xcodeproj` no se sube: se genera con `xcodegen generate`.
- Nada de codigo sin compilar. Si el CI esta rojo, no se avanza.
- El avance se cuenta en pasos verdes, no en porcentajes inventados.
