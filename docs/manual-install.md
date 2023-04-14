# Manual Install

This step-by-step guide will walk you through how to configure your system with the `ssm-supercharged` configuration.

## Install Keychain

[Keychain](https://www.funtoo.org/Funtoo:Keychain) is an awesome tool providing a front-end to `ssh-agent` and `ssh-add`. It allows to keep an `ssh-agent` instance per system, instead of a new instance for each terminal session.

> Keychain is not a pre-requisite in itself, but rather a good practice I do use to streamline my workflow in having a single ssh-agent up and running at all times per system. Note that you must have an ssh-agent running if you choose not to use Keychain.

You can install keychain via `apt` on Debian or `brew` on MacOS. Once it is installed, you can add the following line to your shell configuration (`.bashrc`, `.zshrc`, etc.) to automatically start `ssh-agent` if it is not already running.

```bash
eval `keychain --eval --agents ssh`
```

### OpenSSH Configuration

Next, you will need to update your `~/.ssh/config` file with the content of the [OpenSSH configuration file](../src/ssh_config) provided in this repository, and copy the [`initiate-ssm-connection.sh`](../src/initiate-ssm-connection.sh) proxy command in your `~/.ssh` directory as well.

In a nutshell, this configuration tells OpenSSH that when it attempts to connect to specific hostnames, it needs to tunnel the traffic through SSM.

This script will resolve the following hostnames to EC2 instance identifiers which are expected by the Sessions Manager plugin :

- EC2 public DNS names
- EC2 private DNS names
- EC2 instance tag names
- EC2 instance identifiers

The script operates as a `ProxyCommand` and will be spawned by OpenSSH when it encounters a hostname that matches the patterns specified in your OpenSSH configuration.
