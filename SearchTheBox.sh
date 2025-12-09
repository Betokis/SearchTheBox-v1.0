#!/bin/bash

# Creditos a S4vitar y su increible curso de la academia HACK4U
set -euo pipefail
IFS=$'\n\t'


declare -r C_RED=$'\e[0;31m\033[1m'
declare -r C_GREEN=$'\e[0;32m\033[1m'
declare -r C_YELLOW=$'\e[0;33m\033[1m'
declare -r C_BLUE=$'\e[0;34m\033[1m'
declare -r C_MAGENTA=$'\e[0;35m\033[1m'
declare -r C_CYAN=$'\e[0;36m\033[1m'
declare -r C_WHITE=$'\e[0;37m\033[1m'
declare -r C_GRAY=$'\e[0;90m\033[1m'
declare -r C_BRIGHT_GREEN=$'\e[0;92m\033[1m'
declare -r C_BRIGHT_CYAN=$'\e[0;96m\033[1m'
declare -r C_BRIGHT_YELLOW=$'\e[0;93m\033[1m'
declare -r C_ORANGE=$'\e[38;5;208m\033[1m'
declare -r C_PINK=$'\e[38;5;205m\033[1m'
declare -r C_END=$'\033[0m\e[0m'

declare -r SYM_SUCCESS="✓"
declare -r SYM_ERROR="✗"
declare -r SYM_WARNING="⚠"
declare -r SYM_INFO="ℹ"
declare -r SYM_ARROW="→"
declare -r SYM_BULLET="●"

declare -r SCRIPT_VERSION="1.0"
declare -r MAIN_URL="https://htbmachines.github.io/bundle.js"
declare -r BUNDLE_FILE="bundle.js"
declare -r TEMP_BUNDLE="bundle_temp.js"
declare -r CACHE_DIR="${HOME}/.cache/searchthebox"
declare -r LOG_FILE="${CACHE_DIR}/searchthebox.log"
declare -i PARAMETER_COUNTER=0

init_directories() {
    if [[ ! -d "$CACHE_DIR" ]]; then
        mkdir -p "$CACHE_DIR" 2>/dev/null || true
    fi
}

log_message() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" >> "$LOG_FILE" 2>/dev/null || true
}

check_dependencies() {
    local deps=(curl awk grep sed tr md5sum)
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "\n${C_RED}${SYM_ERROR} Dependencias faltantes:${C_END}"
        printf "  ${C_YELLOW}%s${C_END}\n" "${missing[@]}"
        echo -e "\n${C_CYAN}Instala las dependencias con tu gestor de paquetes${C_END}\n"
        return 1
    fi
    
    return 0
}

check_internet() {
    if ! ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
        return 1
    fi
    return 0
}

draw_line() {
    local char="${1:-─}"
    local width="${2:-${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}}"
    printf '%*s\n' "$width" '' | tr ' ' "$char"
}

draw_box() {
    local text="$1"
    local width="${2:-64}"
    local padding=$(( (width - ${#text} - 2) / 2 ))
    
    printf "${C_CYAN}╔%*s╗${C_END}\n" "$((width - 2))" '' | tr ' ' '═'
    printf "${C_CYAN}║${C_END}%*s${C_YELLOW}%s${C_END}%*s${C_CYAN}║${C_END}\n" \
           "$padding" '' "$text" "$((width - padding - ${#text} - 2))" ''
    printf "${C_CYAN}╚%*s╝${C_END}\n" "$((width - 2))" '' | tr ' ' '═'
}

show_banner() {
    clear
    echo -e "${C_BRIGHT_CYAN}"
    cat << "EOF"
   ███████╗███████╗ █████╗ ██████╗  ██████╗██╗  ██╗    ████████╗██╗  ██╗███████╗
   ██╔════╝██╔════╝██╔══██╗██╔══██╗██╔════╝██║  ██║    ╚══██╔══╝██║  ██║██╔════╝
   ███████╗█████╗  ███████║██████╔╝██║     ███████║       ██║   ███████║█████╗  
   ╚════██║██╔══╝  ██╔══██║██╔══██╗██║     ██╔══██║       ██║   ██╔══██║██╔══╝  
   ███████║███████╗██║  ██║██║  ██║╚██████╗██║  ██║       ██║   ██║  ██║███████╗
   ╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝       ╚═╝   ╚═╝  ╚═╝╚══════╝
                                                                                 
   ██████╗  ██████╗ ██╗  ██╗    
   ██╔══██╗██╔═══██╗╚██╗██╔╝   
   ██████╔╝██║   ██║ ╚███╔╝    
   ██╔══██╗██║   ██║ ██╔██╗     
   ██████╔╝╚██████╔╝██╔╝ ██╗                     
   ╚═════╝  ╚═════╝ ╚═╝  ╚═╝               
EOF
    echo -e "${C_END}"
    echo -e "${C_BRIGHT_GREEN}        ${SYM_BULLET} Buscador de Maquinas HTB ${C_GRAY}v${SCRIPT_VERSION}${C_END}"
    echo -e "${C_GRAY}        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_END}\n"
    log_message "INFO" "Banner displayed - Version ${SCRIPT_VERSION}"
}

cleanup() {
    tput cnorm 2>/dev/null || true
    [[ -f "$TEMP_BUNDLE" ]] && rm -f "$TEMP_BUNDLE" 2>/dev/null || true
    log_message "INFO" "Cleanup executed"
}

ctrl_c() {
    echo -e "\n\n${C_YELLOW}${SYM_WARNING} Interrupción detectada${C_END}"
    echo -e "${C_CYAN}${SYM_ARROW} Saliendo limpiamente...${C_END}\n"
    cleanup
    exit 130
}

trap cleanup EXIT
trap ctrl_c INT SIGTERM

help_panel() {
    cat << EOF

${C_CYAN}╔════════════════════════════════════════════════════════════════════╗${C_END}
${C_CYAN}║${C_END}                     ${C_BRIGHT_YELLOW}PANEL DE AYUDA${C_END}                            ${C_CYAN}║${C_END}
${C_CYAN}╚════════════════════════════════════════════════════════════════════╝${C_END}

${C_BRIGHT_GREEN}USO:${C_END}
  ${C_WHITE}$(basename "$0") [OPCIÓN] [ARGUMENTO]${C_END}

${C_BRIGHT_GREEN}OPCIONES PRINCIPALES:${C_END}
  ${C_MAGENTA}-m${C_END} ${C_CYAN}<nombre>${C_END}      Buscar máquina por nombre
  ${C_MAGENTA}-i${C_END} ${C_CYAN}<ip>${C_END}          Buscar máquina por dirección IP
  ${C_MAGENTA}-d${C_END} ${C_CYAN}<nivel>${C_END}       Buscar por dificultad (Easy/Medium/Hard/Insane)
  ${C_MAGENTA}-o${C_END} ${C_CYAN}<sistema>${C_END}     Buscar por sistema operativo (Linux/Windows)
  ${C_MAGENTA}-s${C_END} ${C_CYAN}<skill>${C_END}       Buscar por skill/técnica específica
  ${C_MAGENTA}-y${C_END} ${C_CYAN}<nombre>${C_END}      Obtener enlace de resolución de YouTube
  ${C_MAGENTA}-l${C_END}                Listar todas las máquinas (formato compacto)
  ${C_MAGENTA}-u${C_END}                Actualizar base de datos local
  ${C_MAGENTA}-c${C_END}                Limpiar caché y logs
  ${C_MAGENTA}-v${C_END}                Mostrar versión del script
  ${C_MAGENTA}-h${C_END}                Mostrar este panel de ayuda

${C_BRIGHT_GREEN}EJEMPLOS DE USO:${C_END}
  ${C_GRAY}# Buscar máquina por nombre${C_END}
  $(basename "$0") -m tentacle

  ${C_GRAY}# Buscar por IP${C_END}
  $(basename "$0") -i 10.10.10.244

  ${C_GRAY}# Buscar máquinas fáciles${C_END}
  $(basename "$0") -d Easy

  ${C_GRAY}# Buscar máquinas Linux${C_END}
  $(basename "$0") -o Linux

  ${C_GRAY}# Buscar por técnica específica${C_END}
  $(basename "$0") -s "SQL Injection"

  ${C_GRAY}# Obtener video de resolución${C_END}
  $(basename "$0") -y tentacle

${C_BRIGHT_GREEN}NOTAS:${C_END}
  ${C_YELLOW}${SYM_BULLET}${C_END} La búsqueda no distingue entre mayúsculas y minúsculas
  ${C_YELLOW}${SYM_BULLET}${C_END} Los resultados se guardan en: ${C_CYAN}${CACHE_DIR}${C_END}
  ${C_YELLOW}${SYM_BULLET}${C_END} Logs disponibles en: ${C_CYAN}${LOG_FILE}${C_END}

EOF
    log_message "INFO" "Help panel displayed"
}

update_files() {
    tput civis 2>/dev/null || true
    
    draw_box "ACTUALIZACIÓN DEL SISTEMA" 64
    echo ""
    
    log_message "INFO" "Update process started"
    
    if ! check_internet; then
        echo -e "${C_RED}${SYM_ERROR} No hay conexión a internet${C_END}\n"
        log_message "ERROR" "No internet connection"
        tput cnorm 2>/dev/null || true
        return 1
    fi
    
    if [[ ! -f "$BUNDLE_FILE" ]]; then
        echo -e "${C_BRIGHT_CYAN}${SYM_ARROW} Descargando base de datos...${C_END}"
        
        if curl -fsSL --progress-bar "$MAIN_URL" -o "$BUNDLE_FILE" 2>/dev/null; then
            if command -v js-beautify &>/dev/null && command -v sponge &>/dev/null; then
                js-beautify "$BUNDLE_FILE" 2>/dev/null | sponge "$BUNDLE_FILE" 2>/dev/null || true
            fi
            
            local size
            size=$(du -h "$BUNDLE_FILE" 2>/dev/null | cut -f1)
            echo -e "${C_GREEN}${SYM_SUCCESS} Base de datos descargada exitosamente${C_END} ${C_GRAY}(${size})${C_END}\n"
            log_message "INFO" "Database downloaded successfully"
        else
            echo -e "${C_RED}${SYM_ERROR} Error al descargar la base de datos${C_END}\n"
            log_message "ERROR" "Failed to download database"
            tput cnorm 2>/dev/null || true
            return 1
        fi
    else
        echo -e "${C_BRIGHT_CYAN}${SYM_ARROW} Verificando actualizaciones...${C_END}"
        
        if ! curl -fsSL "$MAIN_URL" -o "$TEMP_BUNDLE" 2>/dev/null; then
            echo -e "${C_RED}${SYM_ERROR} Error al conectar con el servidor${C_END}\n"
            rm -f "$TEMP_BUNDLE" 2>/dev/null || true
            log_message "ERROR" "Failed to connect to server"
            tput cnorm 2>/dev/null || true
            return 1
        fi
        
        if command -v js-beautify &>/dev/null && command -v sponge &>/dev/null; then
            js-beautify "$TEMP_BUNDLE" 2>/dev/null | sponge "$TEMP_BUNDLE" 2>/dev/null || true
        fi
        
        local md5_temp md5_main
        md5_temp=$(md5sum "$TEMP_BUNDLE" 2>/dev/null | awk '{print $1}')
        md5_main=$(md5sum "$BUNDLE_FILE" 2>/dev/null | awk '{print $1}')
        
        if [[ "$md5_temp" == "$md5_main" ]]; then
            echo -e "${C_GREEN}${SYM_SUCCESS} La base de datos está actualizada${C_END}\n"
            rm -f "$TEMP_BUNDLE" 2>/dev/null || true
            log_message "INFO" "Database is up to date"
        else
            echo -e "${C_YELLOW}${SYM_ARROW} Aplicando actualización...${C_END}"
            rm -f "$BUNDLE_FILE" 2>/dev/null || true
            mv "$TEMP_BUNDLE" "$BUNDLE_FILE"
            
            local size
            size=$(du -h "$BUNDLE_FILE" 2>/dev/null | cut -f1)
            echo -e "${C_GREEN}${SYM_SUCCESS} Base de datos actualizada exitosamente${C_END} ${C_GRAY}(${size})${C_END}\n"
            log_message "INFO" "Database updated successfully"
        fi
    fi
    
    tput cnorm 2>/dev/null || true
    return 0
}

colorize_field() {
    local field="$1"
    local value="$2"
    
    case "$field" in
        name)
            echo -e "  ${C_BRIGHT_YELLOW}[Nombre]${C_END}        ${C_WHITE}${value}${C_END}"
            ;;
        ip)
            echo -e "  ${C_BRIGHT_CYAN}[IP]${C_END}            ${C_WHITE}${value}${C_END}"
            ;;
        so)
            local icon="🐧"
            [[ "$value" =~ [Ww]indows ]] && icon="🪟"
            echo -e "  ${C_BLUE}[Sistema]${C_END}       ${icon}  ${C_WHITE}${value}${C_END}"
            ;;
        dificultad)
            local color=$C_GREEN
            case "${value,,}" in
                easy) color=$C_GREEN ;;
                medium) color=$C_YELLOW ;;
                hard) color=$C_ORANGE ;;
                insane) color=$C_RED ;;
            esac
            echo -e "  ${C_RED}[Dificultad]${C_END}    ${color}${value}${C_END}"
            ;;
        skills)
            echo -e "  ${C_MAGENTA}[Skills]${C_END}        ${C_WHITE}${value}${C_END}"
            ;;
        like)
            echo -e "  ${C_PINK}[Certificados]${C_END}  ${C_WHITE}${value}${C_END}"
            ;;
        youtube)
            echo -e "  ${C_BRIGHT_GREEN}[YouTube]${C_END}       ${C_CYAN}${value}${C_END}"
            ;;
        activeDirectory)
            local ad_icon="❌"
            [[ "$value" == "true" ]] && ad_icon="✅"
            echo -e "  ${C_CYAN}[Active Dir]${C_END}    ${ad_icon}  ${C_WHITE}${value}${C_END}"
            ;;
        *)
            echo -e "  ${C_GRAY}[${field}]${C_END} ${value}"
            ;;
    esac
}

search_machine() {
    local machine_name="$1"
    
    if [[ ! -f "$BUNDLE_FILE" ]]; then
        echo -e "\n${C_RED}${SYM_ERROR} Base de datos no encontrada${C_END}"
        echo -e "${C_YELLOW}${SYM_ARROW} Ejecuta:${C_END} ${C_CYAN}$(basename "$0") -u${C_END}\n"
        log_message "ERROR" "Bundle file not found"
        return 1
    fi
    
    log_message "INFO" "Searching machine: ${machine_name}"
    
    local machine_data
    machine_data=$(awk -v IGNORECASE=1 "/name: \"${machine_name}\"/,/resuelta:/" "$BUNDLE_FILE" | \
                   grep -vE "id:|sku:|resuelta" | \
                   tr -d '"' | tr -d ',' | sed 's/^[[:space:]]*//')
    
    if [[ -n "$machine_data" ]]; then
        echo ""
        draw_box "INFORMACIÓN DE LA MÁQUINA" 64
        echo ""
        
        while IFS=: read -r field value; do
            if [[ -n "$field" && -n "$value" ]]; then
                colorize_field "${field// /}" "$(echo "$value" | xargs)"
            fi
        done <<< "$machine_data"
        
        echo ""
        log_message "INFO" "Machine found: ${machine_name}"
    else
        echo ""
        echo -e "${C_RED}${SYM_ERROR} Máquina no encontrada:${C_END} ${C_YELLOW}${machine_name}${C_END}"
        echo -e "${C_CYAN}${SYM_ARROW} Verifica el nombre o usa:${C_END} ${C_WHITE}$(basename "$0") -l${C_END} ${C_GRAY}para listar todas${C_END}\n"
        log_message "WARNING" "Machine not found: ${machine_name}"
        return 1
    fi
}

search_by_ip() {
    local ip_address="$1"
    
    if ! [[ "$ip_address" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo -e "\n${C_RED}${SYM_ERROR} Formato de IP inválido:${C_END} ${C_YELLOW}${ip_address}${C_END}\n"
        log_message "ERROR" "Invalid IP format: ${ip_address}"
        return 1
    fi
    
    echo -e "\n${C_BRIGHT_CYAN}${SYM_ARROW} Buscando máquina con IP:${C_END} ${C_CYAN}${ip_address}${C_END}\n"
    log_message "INFO" "Searching by IP: ${ip_address}"
    
    local machine_name
    machine_name=$(grep "ip: \"${ip_address}\"" "$BUNDLE_FILE" -B 3 2>/dev/null | \
                   grep "name: " | awk 'NF{print $NF}' | tr -d '"' | tr -d ',')
    
    if [[ -n "$machine_name" ]]; then
        search_machine "$machine_name"
    else
        echo -e "${C_RED}${SYM_ERROR} No se encontró máquina con IP:${C_END} ${C_YELLOW}${ip_address}${C_END}\n"
        log_message "WARNING" "Machine not found for IP: ${ip_address}"
        return 1
    fi
}

search_by_difficulty() {
    local difficulty="$1"
    
    if [[ ! -f "$BUNDLE_FILE" ]]; then
        echo -e "\n${C_RED}${SYM_ERROR} Base de datos no encontrada${C_END}\n"
        return 1
    fi
    
    echo -e "\n${C_BRIGHT_CYAN}${SYM_ARROW} Buscando máquinas de dificultad:${C_END} ${C_YELLOW}${difficulty}${C_END}\n"
    log_message "INFO" "Searching by difficulty: ${difficulty}"
    
    local machines
    machines=$(grep -i "dificultad: \"${difficulty}\"" "$BUNDLE_FILE" -B 4 2>/dev/null | \
               grep "name: " | awk 'NF{print $NF}' | tr -d '"' | tr -d ',')
    
    if [[ -n "$machines" ]]; then
        local count=0
        while IFS= read -r machine; do
            ((count++))
            echo -e "  ${C_GREEN}${count}.${C_END} ${C_WHITE}${machine}${C_END}"
        done <<< "$machines"
        echo -e "\n${C_GRAY}Total: ${count} máquinas${C_END}\n"
    else
        echo -e "${C_RED}${SYM_ERROR} No se encontraron máquinas con esa dificultad${C_END}\n"
        return 1
    fi
}

search_by_os() {
    local os="$1"
    
    if [[ ! -f "$BUNDLE_FILE" ]]; then
        echo -e "\n${C_RED}${SYM_ERROR} Base de datos no encontrada${C_END}\n"
        return 1
    fi
    
    echo -e "\n${C_BRIGHT_CYAN}${SYM_ARROW} Buscando máquinas con sistema:${C_END} ${C_BLUE}${os}${C_END}\n"
    log_message "INFO" "Searching by OS: ${os}"
    
    local machines
    machines=$(grep -i "so: \"${os}\"" "$BUNDLE_FILE" -B 3 2>/dev/null | \
               grep "name: " | awk 'NF{print $NF}' | tr -d '"' | tr -d ',')
    
    if [[ -n "$machines" ]]; then
        local count=0
        while IFS= read -r machine; do
            ((count++))
            echo -e "  ${C_GREEN}${count}.${C_END} ${C_WHITE}${machine}${C_END}"
        done <<< "$machines"
        echo -e "\n${C_GRAY}Total: ${count} máquinas${C_END}\n"
    else
        echo -e "${C_RED}${SYM_ERROR} No se encontraron máquinas con ese sistema${C_END}\n"
        return 1
    fi
}

search_by_skill() {
    local skill="$1"
    
    if [[ ! -f "$BUNDLE_FILE" ]]; then
        echo -e "\n${C_RED}${SYM_ERROR} Base de datos no encontrada${C_END}\n"
        return 1
    fi
    
    echo -e "\n${C_BRIGHT_CYAN}${SYM_ARROW} Buscando máquinas con skill:${C_END} ${C_MAGENTA}${skill}${C_END}\n"
    log_message "INFO" "Searching by skill: ${skill}"
    
    local machines
    machines=$(grep -i "skills:.*${skill}" "$BUNDLE_FILE" -B 5 2>/dev/null | \
               grep "name: " | awk 'NF{print $NF}' | tr -d '"' | tr -d ',' | sort -u)
    
    if [[ -n "$machines" ]]; then
        local count=0
        while IFS= read -r machine; do
            ((count++))
            echo -e "  ${C_GREEN}${count}.${C_END} ${C_WHITE}${machine}${C_END}"
        done <<< "$machines"
        echo -e "\n${C_GRAY}Total: ${count} máquinas${C_END}\n"
    else
        echo -e "${C_RED}${SYM_ERROR} No se encontraron máquinas con ese skill${C_END}\n"
        return 1
    fi
}

list_all_machines() {
    if [[ ! -f "$BUNDLE_FILE" ]]; then
        echo -e "\n${C_RED}${SYM_ERROR} Base de datos no encontrada${C_END}\n"
        return 1
    fi
    
    echo ""
    draw_box "LISTADO DE MÁQUINAS" 64
    echo ""
    
    local machines
    machines=$(grep "name: " "$BUNDLE_FILE" | awk 'NF{print $NF}' | tr -d '"' | tr -d ',' | sort)
    
    local count=0
    local col=0
    while IFS= read -r machine; do
        ((count++))
        ((col++))
        printf "${C_GREEN}%-3d${C_END} ${C_WHITE}%-20s${C_END}" "$count" "$machine"
        
        if [[ $col -eq 3 ]]; then
            echo ""
            col=0
        fi
    done <<< "$machines"
    
    [[ $col -ne 0 ]] && echo ""
    echo -e "\n${C_GRAY}Total: ${count} máquinas disponibles${C_END}\n"
    log_message "INFO" "Listed all machines: ${count} total"
}

get_youtube_link() {
    local machine_name="$1"
    
    if [[ ! -f "$BUNDLE_FILE" ]]; then
        echo -e "\n${C_RED}${SYM_ERROR} Base de datos no encontrada${C_END}\n"
        return 1
    fi
    
    log_message "INFO" "Getting YouTube link for: ${machine_name}"
    
    local youtube_link
    youtube_link=$(awk -v IGNORECASE=1 "/name: \"${machine_name}\"/,/resuelta:/" "$BUNDLE_FILE" | \
                   grep "youtube:" | awk 'NF{print $NF}' | tr -d '"' | tr -d ',')
    
    if [[ -n "$youtube_link" ]]; then
        echo ""
        draw_box "ENLACE DE RESOLUCIÓN" 64
        echo ""
        echo -e "  ${C_YELLOW}[Máquina]${C_END}    ${C_WHITE}${machine_name}${C_END}"
        echo -e "  ${C_BRIGHT_GREEN}[YouTube]${C_END}    ${C_CYAN}${youtube_link}${C_END}"
        echo ""
        log_message "INFO" "YouTube link found for: ${machine_name}"
    else
        echo ""
        echo -e "${C_RED}${SYM_ERROR} No se encontró enlace de YouTube para:${C_END} ${C_YELLOW}${machine_name}${C_END}\n"
        log_message "WARNING" "No YouTube link found for: ${machine_name}"
        return 1
    fi
}

clean_cache() {
    echo ""
    draw_box "LIMPIEZA DE SISTEMA" 64
    echo ""
    
    echo -e "${C_BRIGHT_CYAN}${SYM_ARROW} Limpiando archivos temporales...${C_END}"
    
    local cleaned=0
    
    if [[ -f "$LOG_FILE" ]]; then
        rm -f "$LOG_FILE" 2>/dev/null && ((cleaned++))
        echo -e "  ${C_GREEN}${SYM_SUCCESS} Archivo de logs eliminado${C_END}"
    fi
    
    if [[ -f "$TEMP_BUNDLE" ]]; then
        rm -f "$TEMP_BUNDLE" 2>/dev/null && ((cleaned++))
        echo -e "  ${C_GREEN}${SYM_SUCCESS} Archivos temporales eliminados${C_END}"
    fi
    
    if [[ $cleaned -eq 0 ]]; then
        echo -e "  ${C_YELLOW}${SYM_INFO} No hay archivos para limpiar${C_END}"
    else
        echo -e "\n${C_GREEN}${SYM_SUCCESS} Limpieza completada${C_END} ${C_GRAY}(${cleaned} elementos)${C_END}\n"
    fi
    
    log_message "INFO" "Cache cleaned: ${cleaned} items"
}

show_version() {
    echo ""
    echo -e "${C_BRIGHT_GREEN}SearchTheBox${C_END} ${C_GRAY}v${SCRIPT_VERSION}${C_END}"
    echo -e "${C_CYAN}HackTheBox Machine Intelligence System${C_END}"
    echo -e "${C_GRAY}Enhanced Edition - Production Ready${C_END}\n"
    log_message "INFO" "Version displayed"
}


init_directories

if ! check_dependencies; then
    exit 1
fi

# Mostrar banner
show_banner

# Procesar los parametros
while getopts "m:ui:y:d:o:s:lcvh" arg 2>/dev/null; do
    case $arg in
        m) machineName="$OPTARG"; PARAMETER_COUNTER=1 ;;
        u) PARAMETER_COUNTER=2 ;;
        i) ipAddress="$OPTARG"; PARAMETER_COUNTER=3 ;;
        y) machineName="$OPTARG"; PARAMETER_COUNTER=4 ;;
        d) difficulty="$OPTARG"; PARAMETER_COUNTER=5 ;;
        o) operatingSystem="$OPTARG"; PARAMETER_COUNTER=6 ;;
        s) skillName="$OPTARG"; PARAMETER_COUNTER=7 ;;
        l) PARAMETER_COUNTER=8 ;;
        c) PARAMETER_COUNTER=9 ;;
        v) PARAMETER_COUNTER=10 ;;
        h) PARAMETER_COUNTER=0 ;;
        *) PARAMETER_COUNTER=0 ;;
    esac
done

# Ejecutar función según parámetro
case $PARAMETER_COUNTER in
    1) search_machine "$machineName" ;;
    2) update_files ;;
    3) search_by_ip "$ipAddress" ;;
    4) get_youtube_link "$machineName" ;;
    5) search_by_difficulty "$difficulty" ;;
    6) search_by_os "$operatingSystem" ;;
    7) search_by_skill "$skillName" ;;
    8) list_all_machines ;;
    9) clean_cache ;;
    10) show_version ;;
    *) help_panel ;;
esac

# Restaurar cursor y ctrl+c
tput cnorm 2>/dev/null || true
log_message "INFO" "Script execution completed"
exit 0
