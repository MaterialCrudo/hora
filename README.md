# hora
Script de Bash para listar y organizar archivos en la terminal de Linux,


## Instalación

1. Descargá el archivo `hora.sh`.

2. Dale permiso de ejecución:
   ```bash
   chmod +x hora.sh
   ```

3. Abrí tu archivo de configuración de la terminal:
   ```bash
   nano ~/.bashrc
   ```

4. Agregá al final la siguiente línea, reemplazando la ruta por donde tengas guardado el archivo:
   ```bash
   alias hora='/ruta/hora.sh'
   ```

5. Guardá los cambios (Ctrl+O, Enter, Ctrl+X) y recargá la configuración:
   ```bash
   source ~/.bashrc
   ```

6. Listo. Ahora podés escribir `hora` en cualquier carpeta de la terminal y va a mostrar sus archivos.

## Uso

```bash
hora           # lista todos los Archivos y Carpetas. Visibles y Ocultos.
hora carpetas  # lista solo las Carpetas Visibles.
hora archivos  # lista solo los Archivos Visibles.
hora ocultos   # lista solo los Archivos y Carpetas Ocultos.
hora pdf       # lista solo los Archivos .pdf (u otras extensiones)


```

