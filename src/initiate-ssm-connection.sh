#!/bin/bash

set -e
set -o pipefail

# The help usage text.
USAGE="A proxy command for OpenSSH that establishes a tunnel to an SSM enabled instance.
Options :
    -h  (Required) - the hostname of the instance to connect to.
    -u  (Optional) - the username to connect with, required if EC2 Instance Connect is enabled.
    -p  (Optional) - the SSH port to use, required if EC2 Instance Connect is enabled.
    -e  (Optional) - specifies whether to use EC2 Instance Connect."

# Default values.
SSH_PORT="22"
EC2_INSTANCE_CONNECT="yes"
KEY_PREFIX="eic_key"
TMP_DIR="/tmp"

# Verify whether the required commands are available in the PATH.
COMMANDS="aws openssl ssh-add ssh-keygen"
for CMD in $COMMANDS; do
  if ! command -v "$CMD" >/dev/null 2>&1; then
    >&2 echo "Command $CMD is required to establish the SSM tunnel."
    exit 1
  fi
done

#- add ssm-supercharged to awesome-ssm and others
#- support ecs connections
#- run shellcheck

# Retrieving arguments from the command-line.
while getopts ":h:u:p:e:" o; do
  case "${o}" in
    h) SSH_HOST=${OPTARG} ;;
    u) SSH_USER=${OPTARG} ;;
    p) SSH_PORT=${OPTARG} ;;
    e) EC2_INSTANCE_CONNECT=${OPTARG} ;;
   \?) echo "Invalid option: -$OPTARG - $USAGE" >&2
       exit 1 ;;
    :) echo "Option -$OPTARG requires an argument." >&2
       exit 1 ;;
  esac
done

# The SSH host name is required.
if [[ -z "$SSH_HOST" ]]; then
  >&2 echo "A hostname is required to initiate the SSM tunnel."
  exit 1
fi

# When EC2 Instance Connect is used, the SSH user is required.
if [[ "$EC2_INSTANCE_CONNECT" != "no" && -z "$SSH_USER" ]]; then
  >&2 echo "An SSH user is required to initiate the SSM tunnel."
  exit 1
fi

# Matching Public DNS Names for EC2 instances. 
if [[ "$SSH_HOST" = ec2-*.compute.amazonaws.com ]]; then
  INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=dns-name,Values=$SSH_HOST" \
    --query "Reservations[].Instances[?State.Name == 'running'].InstanceId[]" \
    --output text)
fi

# Matching Private DNS Names for EC2 instances. 
if [[ "$SSH_HOST" = ip-*.compute.internal ]]; then
  INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=private-dns-name,Values=$SSH_HOST" \
    --query "Reservations[].Instances[?State.Name == 'running'].InstanceId[]" \
    --output text)
fi

# Matching instance names, starting by `aws-`.
if [[ "$SSH_HOST" = aws-* ]]; then
  INSTANCE_ID=$(aws ec2 describe-instances \
    --filter "Name=tag:Name,Values=$SSH_HOST" \
    --query "Reservations[].Instances[?State.Name == 'running'].InstanceId[]" \
    --output text)
fi

# Matching instance identifiers, starting by `i-` or `mi-`.
if [[ "$SSH_HOST" = i-* || "$SSH_HOST" = mi-* ]]; then
  INSTANCE_ID=$SSH_HOST
fi

# Verify if an instance identifier could be resolved.
if [[ -z $INSTANCE_ID ]]; then
  >&2 echo "Could not resolve an instance identifier from $SSH_HOST."
  exit 1
fi

# We use EC2 Instance Connect by default to generate a new
# temporary certificate file to connect to the instance.
if [[ "$EC2_INSTANCE_CONNECT" != "no" ]]; then
  PASSPHRASE=$(openssl rand -hex 12)
  KEY_SUFFIX=$(openssl rand -hex 8)
  KEY_NAME="$KEY_PREFIX"_"$KEY_SUFFIX"

  cat > "$TMP_DIR/ssh-askpass" <<EOF
#!/bin/sh
echo \$PASSPHRASE
EOF
  chmod +x "$TMP_DIR/ssh-askpass"

  # Remove any existing temporary key from SSH agent.
  # In addition to cleanup purposes, this will prevent running
  # in a situation where we hit the `MaxAuthTries` on the sshd
  # of the remote EC2 instance due to SSH trying different keys. 
  for key in "$TMP_DIR/$KEY_PREFIX"*; do
    ssh-add -d "$key" 2> /dev/null || :
    rm -f "$key" 2> /dev/null || :
  done

  # Generating a new temporary SSH key-pair.
  ssh-keygen -t rsa -f "$TMP_DIR/$KEY_NAME" -q -N "$PASSPHRASE"
  chmod 600 "$TMP_DIR/$KEY_NAME"*

  PASSPHRASE="$PASSPHRASE" \
  DISPLAY=1 \
  SSH_ASKPASS="$TMP_DIR/ssh-askpass" \
  ssh-add "$TMP_DIR/$KEY_NAME" < /dev/null

  aws ec2-instance-connect send-ssh-public-key \
    --instance-id "$INSTANCE_ID" \
    --instance-os-user "$SSH_USER" \
    --ssh-public-key "file://$TMP_DIR/$KEY_NAME.pub"
fi

# Creating the SSM tunnel once we've resolved the
# instance identifier.
aws ssm start-session \
  --target "$INSTANCE_ID" \
  --document-name AWS-StartSSHSession \
  --parameters "portNumber=$SSH_PORT"
