#!/bin/bash

set -e

if [ ! "$1" ]
then
  exit 1
fi

# Input variables.
HOSTNAME="$1"
USER="$2"
SSH_PORT="${3:-22}"

# Matching Public DNS Names for EC2 instances.
if [[ $HOSTNAME = ec2-*.compute.amazonaws.com ]]; then
  INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=dns-name,Values=$HOSTNAME" \
    --query "Reservations[].Instances[?State.Name == 'running'].InstanceId[]" \
    --output text)
fi

# Matching Private DNS Names for EC2 instances. 
if [[ $HOSTNAME = ip-*.compute.internal ]]; then
  INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=private-dns-name,Values=$HOSTNAME" \
    --query "Reservations[].Instances[?State.Name == 'running'].InstanceId[]" \
    --output text)
fi

# Matching instance names, starting by `aws-`.
if [[ $HOSTNAME = aws-* ]]; then
  INSTANCE_ID=$(aws ec2 describe-instances \
    --filter "Name=tag:Name,Values=$HOSTNAME" \
    --query "Reservations[].Instances[?State.Name == 'running'].InstanceId[]" \
    --output text)
fi

# Matching instance identifiers, starting by `i-` or `mi-`.
if [[ $HOSTNAME = i-* || $HOSTNAME = mi-* ]]; then
  INSTANCE_ID=$HOSTNAME
fi

if [[ ! $INSTANCE_ID ]]; then
  exit 1
fi

# Generate a password to encrypt the temporary SSH certificate.
PASSPHRASE=$(openssl rand -base64 16)

# Create an `askpass` binary for `ssh-add`` that simply prints the password. 
cat > /tmp/ssh-askpass <<EOF
#!/bin/sh
echo \$PASSPHRASE
EOF
chmod +x /tmp/ssh-askpass

# Generate a temporary SSH key-pair.
rm -f /tmp/key /tmp/key.pub
ssh-keygen -t rsa -f /tmp/key -q -N "$PASSPHRASE"
chmod 600 /tmp/key /tmp/key.pub

# Add the private key to the SSH agent.
PASSPHRASE="$PASSPHRASE" \
DISPLAY=1 \
SSH_ASKPASS=/tmp/ssh-askpass \
ssh-add /tmp/key < /dev/null

# Sends the public key to the EC2 instance.
aws ec2-instance-connect send-ssh-public-key \
  --instance-id "$INSTANCE_ID" \
  --instance-os-user "$USER" \
  --ssh-public-key file:///tmp/key.pub

# Creating the SSM tunnel once we've resolved the
# instance identifier.
aws ssm start-session \
  --target "$INSTANCE_ID" \
  --document-name AWS-StartSSHSession \
  --parameters "portNumber=$SSH_PORT"
