#!/bin/bash

#Check if the script is running as root
if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root."
  exit 1
fi

####################################################################################
# CONFIG VARIABLES
####################################################################################
username=""
github_username=""
default_packages="curl wget sudo"
tang_server="ip.ip.ip.ip:port"

if [[ $tang_server == "ip.ip.ip.ip:port" ]]; then
  echo "You need to set the tang server"
  exit 1
fi


####################################################################################
# GLOBAL VARIABLES
####################################################################################

# HEY HEY HEY.... SHOULDN'T BE MESSING WITH THIS UNLESS YOURE EDITING THE SCRIPT

function_list="install_default_packages import_github_ssh_key setup_ssh_decryption network_bound_disk_encryption"
tasks=()

####################################################################################
# MISC FUNCTIONS TO HELP SETUP
####################################################################################

# can be called inside a pre_ to make sure we have a username
get_username() {
  if [[ -z "$username" ]]; then

    echo "no username has been set... prompting for a username"
    read -rp "Enter your username: " username
    read -rp "You've entered '$username'. Is that correct? (y/n): " confirmation

    case $confirmation in
    [Yy] | [Yy][Ee][Ss] | "")
      # Continue with the script
      ;;
    *)
      # If not confirmed, ask again
      get_username
      ;;
    esac
  fi
}

# todo: refactor get_username to get local or github username... hit it with the ol ctrl+c ctrl+v for now
get_github_username() {
  if [[ -z "$github_username" ]]; then

    echo "no github_username has been set... prompting for a github_username"
    read -rp "Enter your github_username: " github_username
    read -rp "You've entered '$github_username'. Is that correct? (y/n): " confirmation

    case $confirmation in
    [Yy] | [Yy][Ee][Ss] | "")
      # Continue with the script
      ;;
    *)
      # If not confirmed, ask again
      get_github_username
      ;;
    esac
  fi
}

# helper function that can be called inside a pre_ in order to add packages to be installed
add_package() {
  default_packages+=" $1"
}

####################################################################################
# install all of the default packages and other packages required for setup
####################################################################################
install_default_packages() {
  declare -a installed_packages=()
  declare -a missing_packages=()

  clean_package_list=$(echo "$default_packages" | tr ' ' '\n' | sort | uniq)
  echo "Installing packages... $clean_package_list"

  for package in $clean_package_list; do
    if dpkg -s "$package" >/dev/null 2>&1; then
      installed_packages+=("$package")
    else
      missing_packages+=("$package")
    fi
  done

  echo "Installed packages: ${installed_packages[@]}"
  echo "Missing packages: ${missing_packages[@]}"

  apt update
  apt install "${missing_packages[@]}" -y
}

####################################################################################
# import public ssh keys from github
####################################################################################
key_index=""
pre_import_github_ssh_key() {
  add_package "curl jq findutils sudo"
  get_username
  if [[ -z "$key_index" ]]; then
    echo "You want to import public ssh key from github."
    echo "Do you want to import all of them found or just the first one found"
    read -rp "Enter 0 for all or 1 for the first (default is 0): " key_index

    # Set a default value if the user just presses Enter
    key_index=${key_index:-0}
  fi
}



import_github_ssh_key() {
  # if [ "$#" -ne 1 ]; then
  #   echo "Usage: import_github_ssh_key <username>"
  #   return 1
  # fi

  # we will set a global username in the setup script
  # local username="$1"
  local ssh_dir="/home/$username/.ssh"
  local authorized_keys="$ssh_dir/authorized_keys"



  # Check if the user's .ssh directory exists, create it if not
  if [ ! -d "$ssh_dir" ]; then
    sudo -u "$username" mkdir -p "$ssh_dir"
    sudo -u "$username" chmod 700 "$ssh_dir"
  fi

  local keys=""
  if [[ $key_index -eq 0 ]]; then
    keys=$(curl "https://api.github.com/users/$github_username/keys" | jq -r '.[].key')
  else
    keys=$(curl "https://api.github.com/users/$github_username/keys" | jq '.[0].key' | xargs)
  fi

  echo -n "$keys" | sudo -u "$username" tee -a "$authorized_keys" >/dev/null
  sudo -u "$username" chmod 600 "$authorized_keys"
  echo "SSH key imported successfully for user $username."

}

####################################################################################
# setup dropbear-initramfs to allow for decryption over ssh
# need to refactor and make more safer
####################################################################################
decryption_decryption_key_index=""
pre_setup_ssh_decryption() {
  add_package "curl sed jq dropbear-initramfs findutils"
  if [[ -z "$decryption_key_index" ]]; then
    echo "You want to setup dropbear-initramfs to allow for remote unlocking of root fs over ssh"
    echo "I haven't programed anything else so im going to import ssh key from git hub"
    echo "Do you want to import all of them or just the first?"
    read -rp "Enter 0 for all or 1 for the first (default is 0): " decryption_key_index

    # Set a default value if the user just presses Enter
    decryption_key_index=${decryption_key_index:-0}
  fi
}
setup_ssh_decryption() {
  local keys=""
  if [[ $decryption_key_index -eq 0 ]]; then
    keys=$(curl "https://api.github.com/users/$github_username/keys" | jq -r '.[].key')
  else
    keys=$(curl "https://api.github.com/users/$github_username/keys" | jq '.[0].key' | xargs)
  fi
  echo -n "$keys" >>/etc/dropbear/initramfs/authorized_keys
  # curl "https://api.github.com/users/$github_username/keys" | jq '.[0].key' | xargs >> /etc/dropbear/initramfs/authorized_keys
  sed -i 's/^#DROPBEAR_OPTIONS.*/DROPBEAR_OPTIONS="-I 10 -j -k -p 2222 -s"/g' /etc/dropbear/initramfs/dropbear.conf
  gateway=$(ip route list | awk ' /^default/ {print $3}')
  ip=$(hostname -I | cut -f1 -d' ')
  echo "IP=$ip::$gateway:255.255.255.0:$(hostname)" >>/etc/initramfs-tools/initramfs.conf
  update-initramfs -u -k 'all'
}

####################################################################################
# Network Bound Disk Encryption (NBDE) via tang and clevis
####################################################################################
root_disk=false
root_passwd=""
pre_network_bound_disk_encryption() {
  # add the packages to install
  add_package "clevis clevis-luks clevis-initramfs clevis-systemd"
  local confirm=""
  echo "Config - Network Bound Disk Encryption (NBDE):"
  echo "The default tang server is $tang_server"
  read -rp "I haven't added the ability to change the tang server if you want to change it exit (ctrl + c) now and do it manually " confirm
  # read -rp "Do you want to accept this? (y/n) Default is yes: " confirm
  # confirm=${confirm:-y}
  # case $confirm in
  # [Yy] | [Yy][Ee][Ss] | "")
  #   # Continue with the script
  #   ;;
  # *)

  #   ;;
  # esac

  # lsblk | grep -B 2 "$root_name" | head -1 | grep -Po '(?<=└─)\S*'

  # lsblk | grep -B 2 "$root_name" | head -1 | grep -Po '(?<=└─)\S*'
  # get root name. this makes getting the root partition from lsblk easier
  root_name=$(basename <<<echo "$(df -h / | awk 'NR==2 {print $1}')")

  # get the name of the disk from lsblk
  root_partition=$(lsblk | grep -B 2 "$root_name" | head -1 | grep -Po '(?<=─)\S*')

  # set the name
  disk="/dev/$root_partition"

  # if it doesn't exists try to get UUID from crpyttab
  if [ ! -e "$disk" ]; then
    echo "we did not find the root disk unable to setup clevis"
    echo "we need better detection of the root disk"
    return
  else

    # we should probably check if it is actually encrypted
    echo "i do believe we found the foot partition"
    root_disk="$disk"
    local password1 password2
    local prompt="Please enter an existing LUKS password for device $root_disk"
    while true; do
      read -s -p "$prompt: " password1
      echo
      read -s -p "$prompt (again): " password2
      echo
      [ "$password1" = "$password2" ] && break
      echo "Passwords did not match. Please try again."
    done
    root_passwd="$password1"
  fi
}
network_bound_disk_encryption() {
  if [[ ! -e $root_disk ]]; then
    echo "root disk: $root_disk doens't exist. can't setup clevis"
    return

  fi

  # -k - : Non-interactively read LUKS password from standard input
  # echo "$root_passwd" | clevis luks bind -y -d "$root_disk" tang '{"url": "http://'"$tang_server"'"}' -k -
  #  couldn't get the above to work but it works with a here file
  clevis luks bind -y -d "$root_disk" tang '{"url": "http://'"$tang_server"'"}' -k <<<"$root_passwd"

  update-initramfs -u -k 'all'
}

# setup_clevis

function pre_run() {
  local tasks_array=("$@")

  # Check tasks_array and do something if needed
  echo "pre_run function checking each task for a pre_task"

  for task in "${tasks_array[@]}"; do
    pre_task="pre_$task"
    if declare -F | grep -q "$pre_task"; then
      # Execute the function
      "$pre_task"
    else
      echo "Function '$pre_task' not found... continueing"
    fi

  done
}

function main_menu() {
  echo "Choose tasks to perform:"
  local list="$1"
  local items=($list)

  for ((i = 0; i < ${#items[@]}; i++)); do
    echo "$((i + 1)). ${items[i]}"
  done

  read -rp "Enter your choices separated by space: " choices

  for choice in $choices; do
    if ((choice >= 1 && choice <= ${#items[@]})); then
      tasks+=("${items[choice - 1]}")
    elif [ "$choice" == "0" ]; then
      return
    else
      echo "Invalid choice: $choice"
      main_menu "$1"
    fi
  done
}

function confirm_choices() {
  echo "You've selected:"
  for task in "${tasks[@]}"; do
    echo "$task"
  done

  read -rp "Is this correct? (yes/no/more default:yes): " confirmation

  case $confirmation in
  [Yy] | [Yy][Ee][Ss] | '')
    echo "Confirmed. Running selected tasks."
    ;;
  [Nn] | [Nn][Oo])
    echo "Aborted. Please run the script again to make selections."
    exit 1
    ;;
  [Mm] | [Mm][Oo][Rr][Ee])
    main_menu
    confirm_choices
    ;;
  *)
    echo "Invalid choice: $confirmation. Please enter 'yes', 'no', or 'more'."
    exit 1
    ;;
  esac
}

main_menu "$function_list"

confirm_choices

pre_run "${tasks[@]}"

# Run selected tasks
for task in "${tasks[@]}"; do
  $task
done

usermod -aG sudo scott
