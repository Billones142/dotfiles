# Configuración de InputPlumber (DualShock 4)

Este directorio contiene los perfiles corregidos y las configuraciones de dispositivos para gestionar un mando DualShock 4 conectado por Bluetooth/USB de manera automática y persistente en Arch Linux.

## Estructura de Archivos

*   **`profiles/ds4_mode.yaml`**: Perfil Passthrough corregido que emula un mando virtual estándar de Linux (`gamepad`). Es el perfil por defecto y proporciona máxima compatibilidad nativa.
*   **`profiles/ds5_mode.yaml`**: Perfil Passthrough corregido que emula un mando virtual DualSense de PS5 (`ds5`), ideal para juegos que soportan de forma nativa características del mando de PS5 en Linux.
*   **`profiles/xbox_mode.yaml`**: Perfil corregido para emular un mando de Xbox 360 (`xb360`) con los nombres de botones, triggers analógicos y joysticks adaptados al esquema actual de InputPlumber.
*   **`devices.d/60-ps4_gamepad.yaml`**: Configuración de dispositivo compuesto personalizada que añade la directiva `auto_manage: true` y asocia el giroscopio y el panel táctil de forma aislada para evitar el drift.
*   **`capability_maps/ds4_touchpad.yaml`**: Mapa de capacidades personalizado para el touchpad del DualShock 4 que permite capturar el clic físico (`BTN_TOUCH`) mientras aísla y descarta las coordenadas de movimiento absoluto (`ABS_X`/`ABS_Y`) para evitar interferencias con el stick analógico izquierdo.
*   **`hooks/inputplumber-profile.hook`**: Un hook de Pacman que vuelve a copiar de forma automática `ds4_mode.yaml` como el perfil `default.yaml` del sistema cada vez que se instala o actualiza el paquete `inputplumber`, logrando que la configuración por defecto persista a actualizaciones del sistema.
*   **`udev/99-hide-physical-ds4.rules`**: Regla de udev que oculta el mando físico DualShock 4 de las aplicaciones de usuario normales cambiando sus permisos a `0600` y quitándole el tag `uaccess`. Esto elimina el problema de la doble entrada en Steam y navegadores de forma definitiva.
*   **`install.sh`**: Script para instalar todas las configuraciones en sus rutas del sistema correspondientes de forma automatizada.



## Instalación

Para aplicar o reinstalar las configuraciones en el sistema actual, simplemente ejecuta el script de instalación desde este directorio:

```bash
./install.sh
```

El script se encargará de:
1. Copiar los perfiles a `/etc/inputplumber/profiles/`.
2. Establecer el perfil `DS4Passthrough` como el predeterminado del sistema en `/usr/share/inputplumber/profiles/default.yaml`.
3. Crear el directorio `/etc/inputplumber/devices.d/` e instalar la regla del dispositivo con `auto_manage: true`.
4. Instalar el mapa de capacidades personalizado en `/etc/inputplumber/capability_maps/`.
5. Instalar la regla de udev en `/etc/udev/rules.d/99-hide-physical-ds4.rules` y recargar/disparar las reglas de udev.
6. Instalar el hook de pacman en `/etc/pacman.d/hooks/`.
7. Reiniciar el servicio `inputplumber.service`.



## Comprobación del Estado

*   **Verificar que el mando está gestionado:**
    ```bash
    inputplumber devices list
    ```
*   **Obtener información del dispositivo y el perfil cargado:**
    ```bash
    inputplumber device 0 info
    ```
*   **Cambiar de perfil manualmente en tiempo de ejecución:**
    *   Para Xbox 360:
        ```bash
        inputplumber device 0 profile load /etc/inputplumber/profiles/xbox_mode.yaml
        ```
    *   Para volver a PlayStation 4 (Mando Estándar / Por Defecto):
        ```bash
        inputplumber device 0 profile load /etc/inputplumber/profiles/ds4_mode.yaml
        ```
    *   Para emular un DualSense de PlayStation 5:
        ```bash
        inputplumber device 0 profile load /etc/inputplumber/profiles/ds5_mode.yaml
        ```

