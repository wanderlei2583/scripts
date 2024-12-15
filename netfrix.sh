#!/usr/bin/env bash

#================HEADER======================================================|
# PROGRAM: NetFRIX
# VERSION: 0.4
# DESCRIPTION: Video streaming interface using ffplay with direct SSH support
#============================================================================|

set -euo pipefail

#========================== CONSTANTS
readonly PROGRAM_NAME='NetFRIX'
readonly VERSION='0.4'
readonly TEMP_DIR=$(mktemp -d)
readonly DATABASE="${TEMP_DIR}/video_database"

# SSH Server Configuration
readonly SSH_USER="wander"
readonly SSH_HOST="192.168.1.106"
readonly REMOTE_VIDEO_PATH="/mnt/videos"

# Required dependencies
readonly DEPENDENCIES=(
  'ffmpeg'
  'ssh'
  'find'
)

#========================== COLORS
readonly COLOR_CYAN='\e[36;1m'
readonly COLOR_RED='\e[31;1m'
readonly COLOR_BLUE='\e[34;1m'
readonly COLOR_RESET='\e[m'

#========================== FUNCTIONS
cleanup() {
  rm -rf "${TEMP_DIR}"
}

die() {
  echo "Error: $1" >&2
  cleanup
  exit 1
}

print_logo() {
  cat <<EOF
${COLOR_CYAN}
    _   __     __  __________  _____  __
   / | / /__  / /_/ ____/ __ \/  _/ |/ /
  /  |/ / _ \/ __/ /_  / /_/ // / |   / 
 / /|  /  __/ /_/ __/ / _, _// / /   |  
/_/ |_/\___/\__/_/   /_/ |_/___//_/|_|  
                                        
${COLOR_RESET}
EOF
}

check_dependencies() {
  local missing_deps=()

  for dep in "${DEPENDENCIES[@]}"; do
    if ! command -v "${dep}" &>/dev/null; then
      missing_deps+=("${dep}")
    fi
  done

  if ((${#missing_deps[@]} > 0)); then
    die "Missing dependencies: ${missing_deps[*]}"
  fi
}

check_ssh_connection() {
  echo "Testing SSH connection..."
  if ! ssh -q "${SSH_USER}@${SSH_HOST}" exit; then
    die "Failed to connect to SSH server. Please check your SSH configuration."
  fi
  echo -e "${COLOR_BLUE}Successfully connected to video server${COLOR_RESET}"
}

update_database() {
  echo "====> Updating video database..."

  # Use SSH to find video files and create database
  ssh "${SSH_USER}@${SSH_HOST}" "find ${REMOTE_VIDEO_PATH} -type f \( -name \"*.mp4\" -o -name \"*.mkv\" -o -name \"*.avi\" \)" >"${DATABASE}"

  echo -e "\n====> ${COLOR_BLUE}Database updated with $(wc -l <"${DATABASE}") videos.${COLOR_RESET}"
  sleep 1
}

play_video() {
  local video_path="$1"
  local video_name=$(basename "$1")

  echo -e "Now playing: ${COLOR_BLUE}${video_name}${COLOR_RESET}"
  cat <<EOF
    Controls:
     ${COLOR_CYAN}'q/ESC'${COLOR_RESET} Return
     ${COLOR_CYAN}'f'${COLOR_RESET} Full Screen
     ${COLOR_CYAN}'p'${COLOR_RESET} Pause
     ${COLOR_CYAN}'9'${COLOR_RESET} Volume Up
     ${COLOR_CYAN}'0'${COLOR_RESET} Volume Down
     ${COLOR_CYAN}'Right Arrow'${COLOR_RESET} Forward 10s
     ${COLOR_CYAN}'Left Arrow'${COLOR_RESET} Backward 10s
EOF

  # Stream video directly via SSH
  ssh "${SSH_USER}@${SSH_HOST}" "cat '${video_path}'" | ffplay -i pipe:0 -loglevel error
}

search_video() {
  local search_term="$1"
  local -a videos
  local count=1

  echo -e "${COLOR_BLUE}  ID${COLOR_RESET}\t\t${COLOR_BLUE}NAME${COLOR_RESET}\n"
  echo -e "[ ${COLOR_RED}0${COLOR_RESET} ]\t\t${COLOR_RED}Return${COLOR_RESET}"

  while IFS= read -r video_path; do
    video_name=$(basename "${video_path}")
    if [[ "${video_name,,}" =~ ${search_term,,} ]]; then
      videos[$count]="${video_path}"
      echo -e "[${COLOR_CYAN} ${count} ${COLOR_RESET}]\t\t${video_name}"
      ((count++))
    fi
  done <"${DATABASE}"

  if ((count == 1)); then
    echo -e "${COLOR_RED}No matches found.${COLOR_RESET}"
    read -p "Press Enter to continue."
    return 1
  fi

  while true; do
    read -rp $'\nEnter ID to play video: ' choice

    if [[ -z "${choice}" ]]; then
      echo "Please select an ID."
      continue
    elif [[ "${choice}" == "0" ]]; then
      return 0
    elif [[ "${choice}" =~ ^[0-9]+$ ]] && ((choice < count)); then
      play_video "${videos[$choice]}"
      break
    else
      echo "Invalid ID."
    fi
  done
}

show_help() {
  cat <<EOF
${PROGRAM_NAME} v${VERSION}

Usage: ${0##*/} [OPTIONS]

Options:
    -h, --help     Show this help message
    -v, --version  Show version information
    -u, --update   Update video database only

Controls while playing:
    q/ESC          Return to menu
    f              Toggle fullscreen
    p              Pause/Play
    9/0            Volume Up/Down
    Arrow Keys     Seek forward/backward
EOF
}

main_menu() {
  local options=(
    'Exit'
    'Help'
    'Update Database'
    'Watch a Video'
  )

  while true; do
    clear
    print_logo

    for i in "${!options[@]}"; do
      if [[ "${options[$i]}" == "Exit" ]]; then
        echo -e "[ ${COLOR_RED}${i}${COLOR_RESET} ] ${options[$i]}"
      else
        echo -e "[ ${COLOR_CYAN}${i}${COLOR_RESET} ] ${options[$i]}"
      fi
    done

    read -rp $'\nChoose an option: ' choice

    case "${choice}" in
    0) exit 0 ;;
    1)
      show_help
      read -p "Press Enter to continue."
      ;;
    2) update_database ;;
    3)
      read -rp $'\e[31;1mEnter video name: \e[m' search_term
      [[ -z "${search_term}" ]] && {
        echo -e "${COLOR_RED}Empty input.${COLOR_RESET}"
        sleep 0.5
        continue
      }
      echo -e "Searching database. Please wait...\n"
      search_video "${search_term}"
      ;;
    *)
      echo -e "${COLOR_RED}Invalid option.${COLOR_RESET}"
      sleep 0.5
      ;;
    esac
  done
}

#========================== MAIN
trap cleanup EXIT

# Process command line arguments
while (($# > 0)); do
  case "$1" in
  -h | --help)
    show_help
    exit 0
    ;;
  -v | --version)
    echo "${PROGRAM_NAME} v${VERSION}"
    exit 0
    ;;
  -u | --update)
    update_database
    exit 0
    ;;
  *) die "Unknown option: $1" ;;
  esac
  shift
done

# Initial setup
check_dependencies
check_ssh_connection
update_database

# Start program
main_menu
