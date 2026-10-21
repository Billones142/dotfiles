# Hook de pacman: paquetes del AUR que usan la API privada de Qt

Avisa, después de cada actualización de `qt5-base` o `qt6-base`, qué paquetes foráneos (AUR o eliminados de los repos) hay que recompilar porque enlazan contra la **API privada de Qt**.

## Por qué hace falta

`rebuild-detector` (`checkrebuild`) solo detecta:

1. Librerías que ya no existen (`ldd` → `not found`).
2. Paquetes de Python/Perl/Haskell instalados en directorios de una versión anterior.

Los plugins de Qt como `qt6ct-kde` o `qt5ct-kde` usan la API privada de Qt (símbolos `Qt_6_PRIVATE_API`), que **no es compatible entre versiones menores** (6.11 → 6.12). Pero el soname no cambia (`libQt6Gui.so.6`) y la etiqueta de símbolos es la misma en todas las versiones, así que `ldd` no ve nada roto. El plugin falla en tiempo de ejecución sin avisar.

Caso real (Qt 6.11 → 6.12, octubre 2026): `qt6ct-kde` dejó de funcionar, las apps Qt/KDE en Hyprland volvieron a la paleta clara por defecto y el esquema Breeze Dark / Naranja dejó de aplicarse. `checkrebuild` no dijo nada.

## Estructura de archivos

*   **`hooks/qt-private-api.hook`**: Hook de pacman que se dispara al actualizar `qt5-base` o `qt6-base` y ejecuta `qt-private-check`.
*   **`bin/qt-private-check`**: Recorre los paquetes foráneos (`pacman -Qqm`) y marca los que cumplen las tres condiciones:
    1. Algún `.so` o binario de `/usr/bin` usa `Qt_5_PRIVATE_API` o `Qt_6_PRIVATE_API`.
    2. Carga el Qt del sistema (`/usr/lib/libQt*Core`), no una copia propia (así se descartan apps como `webex-bin`).
    3. El paquete se compiló antes que el `qtN-base` instalado (compara la `Build Date` de ambos).
*   **`install.sh`**: Instala el script y el hook en sus rutas del sistema.

## Instalación

Necesita root porque escribe fuera del home (`/usr/local/bin` y `/etc/pacman.d/hooks`):

```bash
./install.sh
```

El script ejecuta:

```bash
sudo install -Dm755 bin/qt-private-check /usr/local/bin/qt-private-check
sudo install -Dm644 hooks/qt-private-api.hook /etc/pacman.d/hooks/qt-private-api.hook
```

Requiere `binutils` (para `objdump`).

## Uso

Tras actualizar Qt, pacman mostrará algo como:

```
:: Running post-transaction hooks...
(3/9) Checking foreign packages that use the Qt private API...
  -> rebuild needed: qt6ct-kde
  Rebuild them with e.g.: paru -S --rebuild <package>
```

Recompilar y cerrar/reabrir sesión:

```bash
paru -S --rebuild qt6ct-kde
```

También se puede ejecutar a mano en cualquier momento (no necesita root):

```bash
qt-private-check
```

## Limitaciones

*   **Paquetes `-bin` precompilados** (p. ej. `nsight-graphics`) que usan la API privada del Qt del sistema aparecerán marcados, pero recompilarlos no sirve: hay que esperar a que el empaquetador publique una versión compilada contra el nuevo Qt.
*   Si se compila un paquete del AUR **entre** la fecha de compilación de Qt en los repos y su instalación local (ventana normalmente de horas), se compiló contra el Qt viejo pero no se marcará.
*   Tarda unos segundos (~10 s) porque inspecciona con `objdump` todos los paquetes foráneos.
