#!/bin/bash

filtro=""
if [[ -n "$1" ]]; then
  filtro="${1^^}"
  [[ "$filtro" == "CARPETAS" ]] && filtro="CARPETA"
  [[ "$filtro" == "OCULTO" ]] && filtro="OCULTOS"
  [[ "$filtro" == "ARCHIVO" ]] && filtro="ARCHIVOS"
fi

declare -A grupos
declare -A conteo
declare -A bytes_grupo

NARANJA_BG=$'\033[48;5;208m'
NARANJA_OSCURO_BG=$'\033[48;5;166m'
AZUL_BG=$'\033[44m'
AZUL_OSCURO_BG=$'\033[48;5;24m'
NEGRO_FG=$'\033[30m'
BLANCO_FG=$'\033[97m'
RESET=$'\033[0m'

pad_derecha() {
  local str="$1" ancho="$2"
  local len
  len=$(echo -n "$str" | wc -m)
  local relleno=$(( ancho - len ))
  (( relleno < 0 )) && relleno=0
  printf "%s%*s" "$str" "$relleno" ""
}

total_vis_count=0
total_vis_bytes=0
total_oculto_count=0
total_oculto_bytes=0
total_carpetas=0
carp_vis_count=0
carp_vis_bytes=0
carp_oc_count=0
carp_oc_bytes=0

while IFS= read -r archivo; do
  [[ -z "$archivo" ]] && continue
  nombre=$(basename "$archivo")
  if [[ -d "$archivo" ]]; then
    ext="CARPETA"
  elif [[ "$nombre" == .* ]]; then
    ext="OCULTOS"
  else
    ext="${nombre##*.}"
    [[ "$ext" == "$nombre" ]] && ext="SIN_EXTENSION"
    ext="${ext^^}"
    [[ "$ext" == "DESKTOP" ]] && ext="LANZADOR"
  fi
  timestamp=$(stat -c "%Y" "$archivo" 2>/dev/null)
  fecha=$(stat -c "%y" "$archivo" 2>/dev/null | awk '{print $1, $2}' | cut -d'.' -f1)
  bytes=$(stat -c "%s" "$archivo" 2>/dev/null)

  es_oculto="N"
  [[ "$nombre" == .* ]] && es_oculto="Y"

  if [[ -d "$archivo" ]]; then
    bytes_carpeta=$(du -sb "$archivo" 2>/dev/null | cut -f1)
    tam=$(awk -v b="$bytes_carpeta" 'BEGIN { printf "%.2f MB", b/1024/1024 }')
    total_carpetas=$(( total_carpetas + 1 ))
    bytes_grupo["$ext"]=$(( ${bytes_grupo["$ext"]:-0} + bytes_carpeta ))
    if [[ "$es_oculto" == "Y" ]]; then
      carp_oc_count=$(( carp_oc_count + 1 ))
      carp_oc_bytes=$(( carp_oc_bytes + bytes_carpeta ))
    else
      carp_vis_count=$(( carp_vis_count + 1 ))
      carp_vis_bytes=$(( carp_vis_bytes + bytes_carpeta ))
    fi
  else
    tam=$(awk -v b="$bytes" 'BEGIN { printf "%.2f MB", b/1024/1024 }')
    bytes_grupo["$ext"]=$(( ${bytes_grupo["$ext"]:-0} + bytes ))
    if [[ "$es_oculto" == "Y" ]]; then
      total_oculto_count=$(( total_oculto_count + 1 ))
      total_oculto_bytes=$(( total_oculto_bytes + bytes ))
    else
      total_vis_count=$(( total_vis_count + 1 ))
      total_vis_bytes=$(( total_vis_bytes + bytes ))
    fi
  fi

  es_exec="N"
  if [[ ! -d "$archivo" && -x "$archivo" ]]; then
    es_exec="Y"
  fi

  grupos["$ext"]+="$timestamp|$fecha|$nombre|$tam|$es_exec|$es_oculto"$'\n'
  conteo["$ext"]=$(( ${conteo["$ext"]:-0} + 1 ))
done < <(find . -maxdepth 1 -not -name "." | sed 's|^\./||' | sort)

imprimir_linea() {
  local ext="$1" ts fecha nombre tam es_exec es_oculto color nombre_pad
  IFS='|' read -r ts fecha nombre tam es_exec es_oculto
  [[ -z "$ts" ]] && return
  color=""
  if [[ "$ext" == "CARPETA" ]]; then
    if [[ "$es_oculto" == "Y" ]]; then
      color="${NARANJA_OSCURO_BG}${NEGRO_FG}"
    else
      color="${NARANJA_BG}${NEGRO_FG}"
    fi
  else
    if [[ "$es_oculto" == "Y" ]]; then
      color="${AZUL_OSCURO_BG}${BLANCO_FG}"
    else
      color="${AZUL_BG}${BLANCO_FG}"
    fi
  fi
  if [[ -n "$color" ]]; then
    nombre_pad=$(pad_derecha "$nombre" 30)
    printf "  %s %s %10s   %s %s\n" "$color" "$nombre_pad" "$tam" "$fecha" "$RESET"
  else
    nombre_pad=$(pad_derecha "$nombre" 30)
    printf "  %s %10s   %s\n" "$nombre_pad" "$tam" "$fecha"
  fi
}



# ---- Caso especial: ARCHIVOS (solo archivos visibles, separados por extensión) ----
if [[ "$filtro" == "ARCHIVOS" ]]; then
  lista_ext_archivos=$(echo "${!grupos[@]}" | tr ' ' '\n' | grep -v '^CARPETA$' | grep -v '^OCULTOS$' | sort)
  if [[ -z "$lista_ext_archivos" ]]; then
    echo "No se encontraron archivos visibles en esta carpeta."
    exit 0
  fi
  primer_grupo=true
  for e in $lista_ext_archivos; do
    $primer_grupo || echo ""
    primer_grupo=false
    titulo="$e"
    [[ "$titulo" == "SIN_EXTENSION" ]] && titulo="SIN EXTENSION"
    echo "------------ .$titulo (${conteo[$e]}) ------------"
    echo -n "${grupos[$e]}" | sort -t'|' -k1,1rn | while IFS='|' read -r ts fecha nombre tam es_exec es_oculto; do
      echo "$ts|$fecha|$nombre|$tam|$es_exec|$es_oculto" | imprimir_linea "$e"
    done
  done
  archivos_mb=$(awk -v b="$total_vis_bytes" 'BEGIN { printf "%.2f", b/1024/1024 }')
  echo ""
  echo "------------------------------------------"
  echo "Total archivos:  $total_vis_count  ($archivos_mb MB)"
  echo "------------------------------------------"
  exit 0
fi

# ---- Caso especial: CARPETA (solo carpetas visibles) ----
if [[ "$filtro" == "CARPETA" ]]; then
  if [[ -z "${grupos[CARPETA]+x}" || "$carp_vis_count" -eq 0 ]]; then
    echo "No se encontraron carpetas visibles en esta carpeta."
    exit 0
  fi
  echo "------------ CARPETAS ($carp_vis_count) ------------"
  echo -n "${grupos[CARPETA]}" | sort -t'|' -k6,6r -k3,3f | while IFS='|' read -r ts fecha nombre tam es_exec es_oculto; do
    [[ "$es_oculto" == "Y" ]] && continue
    echo "$ts|$fecha|$nombre|$tam|$es_exec|$es_oculto" | imprimir_linea "CARPETA"
  done
  carp_mb=$(awk -v b="$carp_vis_bytes" 'BEGIN { printf "%.2f", b/1024/1024 }')
  echo ""
  echo "------------------------------------------"
  echo "Total carpetas:  $carp_vis_count  ($carp_mb MB)"
  echo "------------------------------------------"
  exit 0
fi

# ---- Caso especial: OCULTOS (carpetas y archivos ocultos, todo junto) ----
if [[ "$filtro" == "OCULTOS" ]]; then
  total_oc_count=$(( carp_oc_count + total_oculto_count ))
  total_oc_bytes=$(( carp_oc_bytes + total_oculto_bytes ))
  if [[ "$total_oc_count" -eq 0 ]]; then
    echo "No se encontraron carpetas ni archivos ocultos en esta carpeta."
    exit 0
  fi
  echo "------------ OCULTOS ($total_oc_count) ------------"
  if [[ "$carp_oc_count" -gt 0 ]]; then
    echo -n "${grupos[CARPETA]}" | sort -t'|' -k3,3f | while IFS='|' read -r ts fecha nombre tam es_exec es_oculto; do
      [[ "$es_oculto" == "N" ]] && continue
      echo "$ts|$fecha|$nombre|$tam|$es_exec|$es_oculto" | imprimir_linea "CARPETA"
    done
  fi
  if [[ -n "${grupos[OCULTOS]+x}" ]]; then
    echo -n "${grupos[OCULTOS]}" | sort -t'|' -k1,1rn | while IFS='|' read -r ts fecha nombre tam es_exec es_oculto; do
      echo "$ts|$fecha|$nombre|$tam|$es_exec|$es_oculto" | imprimir_linea "OCULTOS"
    done
  fi
  oc_mb=$(awk -v b="$total_oc_bytes" 'BEGIN { printf "%.2f", b/1024/1024 }')
  echo ""
  echo "------------------------------------------"
  echo "Total ocultos:  $total_oc_count  ($oc_mb MB)"
  echo "------------------------------------------"
  exit 0
fi

# ---- Filtro por extensión puntual (pdf, txt, etc.) ----
if [[ -n "$filtro" ]]; then
  if [[ -z "${grupos[$filtro]+x}" ]]; then
    echo "No se encontraron archivos de tipo .$filtro en esta carpeta."
    exit 0
  fi
  echo "------------ .$filtro (${conteo[$filtro]}) ------------"
  echo -n "${grupos[$filtro]}" | sort -t'|' -k6,6r -k1,1rn | while IFS='|' read -r ts fecha nombre tam es_exec es_oculto; do
    echo "$ts|$fecha|$nombre|$tam|$es_exec|$es_oculto" | imprimir_linea "$filtro"
  done
  filtro_mb=$(awk -v b="${bytes_grupo[$filtro]:-0}" 'BEGIN { printf "%.2f", b/1024/1024 }')
  echo ""
  echo "------------------------------------------"
  echo "Total .$filtro:  ${conteo[$filtro]}  ($filtro_mb MB)"
  echo "------------------------------------------"
  exit 0
fi

# ---- Sin filtro: listado completo ----
hubo_carpeta_u_oculto=false

if [[ -n "${grupos[CARPETA]+x}" ]]; then
  hubo_carpeta_u_oculto=true
  echo "------------ .CARPETA (${conteo[CARPETA]}) ------------"
  echo -n "${grupos[CARPETA]}" | sort -t'|' -k6,6r -k3,3f | while IFS='|' read -r ts fecha nombre tam es_exec es_oculto; do
    echo "$ts|$fecha|$nombre|$tam|$es_exec|$es_oculto" | imprimir_linea "CARPETA"
  done
fi

if [[ -n "${grupos[OCULTOS]+x}" ]]; then
  $hubo_carpeta_u_oculto && echo ""
  hubo_carpeta_u_oculto=true
  echo "------------ .OCULTOS (${conteo[OCULTOS]}) ------------"
  echo -n "${grupos[OCULTOS]}" | sort -t'|' -k1,1rn | while IFS='|' read -r ts fecha nombre tam es_exec es_oculto; do
    echo "$ts|$fecha|$nombre|$tam|$es_exec|$es_oculto" | imprimir_linea "OCULTOS"
  done
fi

lista_ext=$(echo "${!grupos[@]}" | tr ' ' '\n' | grep -v '^CARPETA$' | grep -v '^OCULTOS$' | sort)
if [[ -n "$lista_ext" ]]; then
  $hubo_carpeta_u_oculto && echo ""
  primer_grupo=true
  for ext in $lista_ext; do
    $primer_grupo || echo ""
    primer_grupo=false
    titulo="$ext"
    [[ "$titulo" == "SIN_EXTENSION" ]] && titulo="SIN EXTENSION"
    echo "------------ .$titulo (${conteo[$ext]}) ------------"
    echo -n "${grupos[$ext]}" | sort -t'|' -k1,1rn | while IFS='|' read -r ts fecha nombre tam es_exec es_oculto; do
      echo "$ts|$fecha|$nombre|$tam|$es_exec|$es_oculto" | imprimir_linea "$ext"
    done
  done
fi

vis_mb=$(awk -v b="$total_vis_bytes" 'BEGIN { printf "%.2f", b/1024/1024 }')
oculto_mb=$(awk -v b="$total_oculto_bytes" 'BEGIN { printf "%.2f", b/1024/1024 }')

echo ""
echo "------------------------------------------"
echo "Carpetas:           $total_carpetas"
echo "Archivos visibles:  $total_vis_count  ($vis_mb MB)"
echo "Archivos ocultos:   $total_oculto_count  ($oculto_mb MB)"
echo "------------------------------------------"
