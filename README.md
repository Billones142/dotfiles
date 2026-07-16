# Dotfiles Billones142

Dotfiles administrados mediante Git y GNU Stow.

## Uso Básico

Para desplegar un paquete de configuración:
```bash
stow <nombre_paquete>
```

## Nota importante sobre Systemd (evitar "folding" de directorios)

Por defecto, GNU Stow utiliza *folding* (plegado). Si un directorio no existe en el destino, Stow creará un enlace simbólico al directorio completo en lugar de crear la estructura de carpetas y enlazar únicamente los archivos individuales.

**Systemd no sigue enlaces simbólicos a nivel de directorio para los drop-ins (`.service.d/`)** en `~/.config/systemd/user/`. Si dejas que Stow pliegue directorios de systemd (como `plasma-kded6.service.d`), systemd ignorará las configuraciones de override y arrojará advertencias constantes indicando que los archivos cambiaron en el disco:
```
Warning: The unit file, source configuration file or drop-ins of plasma-kded6.service changed on disk. Run 'systemctl --user daemon-reload' to reload units.
```

### Solución

Al desplegar paquetes que contengan directorios de drop-ins de systemd (como `systemd-user`), se debe utilizar la opción `--no-folding` (o `-N`):

```bash
stow --no-folding systemd-user
```

Si el paquete ya fue enlazado con *folding*, primero desvincula el paquete y luego re-vincula usando la bandera anterior:
```bash
stow -D systemd-user
stow --no-folding systemd-user
```
