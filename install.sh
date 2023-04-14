#!/bin/bash

default_ssh_dir() {
  if [ -n "${XDG_CONFIG_HOME-}" ]; then
    printf %s "${XDG_CONFIG_HOME}/.ssh"
  elif [ -n "${HOME-}" ]; then
    printf %s "${HOME}/.ssh"
  else
    fail "Could not detect home directory. Ensure \$HOME or \$XDG_CONFIG_HOME are set."
  fi
}

# The path to the local SSH directory.
SSH_DIR="$(default_ssh_dir)"

# The path to the OpenSSH configuration for the current user.
SSH_CONFIG_FILE="$SSH_DIR/config"

# The branch from which files are installed. 
REPO_BRANCH="master"

# The base URL for fetching raw files from the GitHub repository
REPO_URL="https://raw.githubusercontent.com/HQarroum/ssm-supercharged/$REPO_BRANCH"

print() {
  command printf %s\\n "$*" 2>/dev/null
}

info() {
  print "[+] $*"
}

warn() {
  [ -n "$1" ] && print "[!] $*"
}

fail() {
  [ -n "$1" ] && print "[!] $*"
  exit 1
}

verify_commands() {
  COMMANDS="aws openssl ssh ssh-add ssh-keygen ssh-agent grep curl"
  for CMD in $COMMANDS; do
    if ! command -v "$CMD" >/dev/null 2>&1; then
      fail "Command $CMD is required. Please install it before continuing."
    fi
  done
}

ssh_config_is_patched() {
  if [ ! -f "$SSH_CONFIG_FILE" ]; then
    printf %s "no"
  else
    grep -qxF "$1" "$SSH_CONFIG_FILE" && printf %s "yes" || printf %s "no"
  fi
}

bootstrap_ssh_directory() {
  if [ ! -d "$SSH_DIR" ]; then
    info "Bootstraping the SSH directory of '$USER' ..."
    mkdir -p "$SSH_DIR"
  fi
}

copy_proxy_command() {
  curl --silent "$REPO_URL/src/initiate-ssm-connection.sh" > "$SSH_DIR/initiate-ssm-connection.sh"
}

patch_ssh_config() {
  local ssh_config_file_content;
  local ssh_config_patched;

  ssh_config_file_content="$(curl --silent $REPO_URL/src/ssh_config)"
  ssh_config_patched=$(ssh_config_is_patched "$ssh_config_file_content")
  if [ "$ssh_config_patched" = "no" ]; then
    # If an OpenSSH configuration file does not exist, we create it.
    if [ ! -f "$SSH_CONFIG_FILE" ]; then
      info "$SSH_CONFIG_FILE does not exists, creating an empty file."
      touch "$SSH_CONFIG_FILE"
    else
      local backup_file;
      backup_file="$SSH_DIR/config.bak.$(date +%s)"
      info "Creating a backup of $SSH_CONFIG_FILE in $backup_file."
      cp "$SSH_CONFIG_FILE" "$backup_file"
    fi
    info "OpenSSH config does not appear to be patched, updating ..."
    echo -e "\n$ssh_config_file_content" >> "$SSH_CONFIG_FILE"
  else
    info "OpenSSH config appears to be patched, nothing to do."
  fi
}

verify_ssh_agent() {
  local pids;

  pids=$(ps -ax)
  
  if [ "$pids" ]; then
    ps=$(echo "$pids" | grep -v grep | grep -c ssh-agent)

    if [ "$ps" = "0" ]; then
    print "[i] ssh-agent does not seem to be running, it is required for optimal SSM tunneling."
    # shellcheck disable=SC2016
    print '[i] You can start it using "eval `ssh-agent -s`".' 
    fi
  else
    warn "Could not verify whether ssh-agent is running."
    return 1
  fi
}

# Verify whether the required commands are available.
verify_commands

# Bootstrap the SSH directory of the current user.
bootstrap_ssh_directory

# Copy the SSM proxy command in the SSH directory.
copy_proxy_command 

# Patch the existing SSH configuration if it is required.
patch_ssh_config

verify_ssh_agent 2> /dev/null || :

info "Installation done."
