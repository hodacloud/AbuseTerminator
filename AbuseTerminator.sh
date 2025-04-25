#!/bin/bash
# AbuseTerminator - Professional IP Management
# Developed by HodaCloud (hodacloud.com)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Configuration
SINGLE_IP_FILE="/root/abuseterminator_single_ips.txt"
RANGE_IP_FILE="/root/abuseterminator_range_ips.txt"
TEMP_FILE=$(mktemp)
WIDTH=60

# Check root
check_root() {
  [[ $EUID -eq 0 ]] || { echo -e "${RED}Error: Run as root!${NC}"; exit 1; }
}

# Validation functions
validate_ip() {
  local ip=$1
  [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && 
  IFS='.' read -r a b c d <<< "$ip" &&
  ((a <= 255 && b <= 255 && c <= 255 && d <= 255))
}
# 5
show_statistics() {
  echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
#  echo -e "│ $Firewall Rules (INPUT Chain):$"
  iptables -L INPUT -v -n --line-numbers
  echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"
  read -p "Press Enter to continue..."
}
# IP conversion
ip_to_int() { IFS='.' read -r a b c d <<< "$1"; echo $((a*256**3 + b*256**2 + c*256 + d)); }
int_to_ip() { echo "$(($1>>24&0xFF)).$(($1>>16&0xFF)).$(($1>>8&0xFF)).$(($1&0xFF))"; }

generate_range() {
  local start=$(ip_to_int $1)
  local end=$(ip_to_int $2)
  for ((i=start; i<=end; i++)); do int_to_ip $i; done
}

# UI Components
draw_box() {
  local width=$1
  echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
}

show_header() {
  clear
  echo -e "${CYAN}"
  echo "┌────────────────────────────────────────────────────────────┐"
  echo "│            █████  ██████  ██    ██ ████████                │"
  echo "│           ██   ██ ██   ██ ██    ██      ██                 │"
  echo "│           ███████ ██████  ██    ██    ██                   │"
  echo "│           ██   ██ ██   ██ ██    ██  ██                     │"
  echo "│           ██   ██ ██████   ██████ ████████ AbuzeTerminator │"
  echo "├────────────────────────────────────────────────────────────┤"
  printf "│${YELLOW}%-28s ${MAGENTA}v2.2.0${CYAN}                         │\n" "   HodaCloud" 
  echo "└────────────────────────────────────────────────────────────┘"
}

main_menu() {
  echo -e "\n${CYAN}┌────────────────────────────────────────────────────────────┐"
  echo -e "│${YELLOW}                      MAIN MENU                             ${CYAN}│"
  echo -e "├────────────────────────────────────────────────────────────┤"
  printf "│${GREEN} 1. Add Single IP     ${BLUE} 2. Add IP Range                      ${CYAN}│\n"
  printf "│${GREEN} 3. List Blocked IPs  ${BLUE} 4. Activate Blocking                 ${CYAN}│\n"
  printf "│${GREEN} 5. View Statistics   ${BLUE} 6. Remove Block                      ${CYAN}│\n"
  printf "│${RED} 7. Exit               ${BLUE}                                     ${CYAN}│\n"
  echo -e "└────────────────────────────────────────────────────────────┘${NC}"
  echo -e "${MAGENTA}┌────────────────────────────────────────────────────────────┐"
  echo -e "│${YELLOW} HodaCloud Security Solutions • hodacloud.com • 24/7 Support${MAGENTA}│"
  echo -e "└────────────────────────────────────────────────────────────┘${NC}"
}

# Core functions
add_single_ip() {
  while :; do
    echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
    read -p "│ Enter IP (q to quit):" ip
    [[ $ip == "q" ]] && break
    
    if validate_ip "$ip"; then
      if ! grep -qxF "$ip" "$SINGLE_IP_FILE"; then
        echo "$ip" >> "$SINGLE_IP_FILE"
        echo -e "│ [+] $ip added successfully!"
      else
        echo -e "│ [!] $ip already exists!"
      fi
    else
      echo -e "│ [!] Invalid IP format!"
    fi
    echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"
  done
}

add_ip_range() {
  while :; do
    echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
    read -p "│ Start IP (q to quit): " start_ip
    [[ $start_ip == "q" ]] && break
    read -p "│ End IP: " end_ip

    if validate_ip "$start_ip" && validate_ip "$end_ip"; then
      if (( $(ip_to_int "$start_ip") <= $(ip_to_int "$end_ip") )); then
        generate_range "$start_ip" "$end_ip" > "$TEMP_FILE"
        added=$(comm -23 <(sort "$TEMP_FILE") <(sort "$RANGE_IP_FILE") | tee -a "$RANGE_IP_FILE" | wc -l)
        echo -e "│ [+] Added $new IPs to range!"
      else
        echo -e "│ [!] Invalid range!"
      fi
    else
      echo -e "│ [!] Invalid IP format!"
    fi
    echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"
  done
}

activate_blocking() {
  echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
  echo -e "│ Applying firewall rules..."
  while read ip; do
    if ! iptables -C INPUT -s "$ip" -j DROP &>/dev/null; then
      iptables -A INPUT -s "$ip" -j DROP
      iptables -A OUTPUT -d "$ip" -j DROP
      echo -e "│ [+] Blocked $ip"
    fi
  done < <(cat "$SINGLE_IP_FILE" "$RANGE_IP_FILE" 2>/dev/null)
  echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"
  sleep 1
}

# Main execution
check_root
trap '' SIGINT
for file in "$SINGLE_IP_FILE" "$RANGE_IP_FILE"; do touch "$file"; done

while true; do
  show_header
  main_menu
  read -p "$(echo -e "${YELLOW}│ Select option [1-7]: ${NC}")" choice
  
  case $choice in
    1) add_single_ip ;;
    2) add_ip_range ;;
    3) 
      echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
      echo -e "│ Blocked IP Addresses:"
      column -t <(cat "$SINGLE_IP_FILE" "$RANGE_IP_FILE" 2>/dev/null | sort -u) | 
        awk -v CYAN="$CYAN" -v NC="$NC" '{print CYAN "│ " NC $0}'
      echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"
      read -p "Press Enter to continue..."
      ;;
    4) activate_blocking ;;

    5) show_statistics ;;

    6) 
      echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
      read -p "│ Enter IP to unblock: " ip
      if validate_ip "$ip"; then
        iptables -D INPUT -s "$ip" -j DROP 2>/dev/null
        iptables -D OUTPUT -d "$ip" -j DROP 2>/dev/null
        sed -i "/^$ip$/d" "$SINGLE_IP_FILE" "$RANGE_IP_FILE"
        echo -e "│ [✓] $ip unblocked!"
      else
        echo -e "│ [!] Invalid IP!"
      fi
      echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"
      sleep 1
      ;;
    7)
      echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
      echo -e "│            Thank you for using AbuseTerminator             │"
      echo -e "│          Powered by HodaCloud Security Solutions           │"
      echo -e "└────────────────────────────────────────────────────────────┘${NC}"
      exit 0
      ;;
    *)
      echo -e "${RED}Invalid option!${NC}"
      sleep 1
      ;;
  esac
done
