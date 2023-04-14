<p align="center">
  <img width="500" src="assets/icon.png">
  <h2 align="center">⚡ SSM Supercharged</h2>
  <p align="center">AWS SSM integration with OpenSSH + EC2 Instance Connect + sshuttle<p>
  <p align="center"><em>This repository is linked to the research conducted in this <a href="https://halim.qarroum.com/ssm-sessions-manager-on-steroids-83e01d5f11f4">Medium article</a>.</em></p>
  <p align="center">
    <a href="https://deepsource.io/gh/HQarroum/ssm-supercharged/?ref=repository-badge}" target="_blank"><img alt="DeepSource" title="DeepSource" src="https://deepsource.io/gh/HQarroum/ssm-supercharged.svg/?label=active+issues&show_trend=true&token=u6fp0Ak9RQrsjdsi-Bda3azf"/></a>
    <a href="https://www.codefactor.io/repository/github/hqarroum/ssm-supercharged"><img src="https://www.codefactor.io/repository/github/hqarroum/ssm-supercharged/badge" alt="CodeFactor" /></a>
  </p>
</p>
<br>

Current version: **1.1.0**

Lead Maintainer: [Halim Qarroum](mailto:hqm.post@gmail.com)

## 📋 Table of content

- [Description](#-description)
- [Pre-Requisites](#-pre-requisites)
- [Installation](#-installation)
- [Usage](#-usage)
- [See also](#-see-also)

## 🔰 Description

This repository features a simple [OpenSSH configuration file](./src/ssh_config) and a [Bash based proxy command](./src/initiate-ssm-connection.sh) used to integrate OpenSSH with [AWS SSM Sessions Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html) for a streamlined and secure experience. The aim of this project is to provide a way to achieve one or multiple of the following :

- Keep your EC2 instances in a private subnet with no inbound security group rules.
- Stop managing SSH key-pairs, and keep your instances keyless.
- Systematically run SSH through an SSM tunnel when targeting EC2 instances.
- Address EC2 instances using their instance identifiers, friendly names, public DNS names or private DNS names.
- Generate just-in-time temporary SSH certificates for connecting to certificate-less instances using [EC2 Instance Connect](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/Connect-using-EC2-Instance-Connect.html).
- Integrate [sshuttle](https://github.com/sshuttle/sshuttle) with SSM to establish a lightweight and free VPN to a remote VPC.

## 🎒 Pre-Requisites

Below is a list of tools you need to have available on your development machine.

- OpenSSH client tools (`ssh`, `ssh-keygen`, etc.).
- A running `ssh-agent`.
- The [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) configured with valid AWS credentials.
- The [Sessions Manager Plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html) must be installed.
- [sshuttle](https://github.com/sshuttle/sshuttle).

## 🚀 Installation

> The installer has been tested on Debian and MacOS and does not require root priviledges.

This repository provides a way to install and upgrade the required OpenSSH configuration on your machine through an installer that will perform the configuration automatically.

```bash
curl -o- https://raw.githubusercontent.com/HQarroum/ssm-supercharged/master/install.sh | bash
```

The installer will patch your OpenSSH configuration by appending the required configuration in your `~/.ssh/config`, or create it if it does not exist. It will also copy the required OpenSSH `ProxyCommand` required to establish SSM tunnels and provision instances using EC2 Instance Connect.

### Manual Installation

If you prefer to manually copy the required configuration files, or if the automated script does not work for you, please read [how to manually install the `ssm-supercharged` configuration](./docs/manual-install.md).

## 🚌 Usage

> Ensure you have valid AWS credentials on your development machine before continuing. It is recommend you test the following with a small EC2 instance (e.g t2.micro) launched in a private VPC without any SSH key-pair attached for testing.

### OpenSSH

First ensure that an SSH connection can be successfullly tunneled to your instance. To do so, simply enter the following command with the identifier of the EC2 instance you would like to connect to.

```bash
ssh user@i-example
```

You can also reference your EC2 instance through other attributes.

```bash
# Connecting using private DNS name.
ssh user@ip-172-31-1-2.us-east-1.compute.internal

# Connecting using friendly-name.
ssh user@aws-awesome-instance
```

> Tools running over the SSH protocol such as `scp`, `rsync`, `ansible` should work out of the box.

### sshuttle

> [sshuttle](https://github.com/sshuttle/sshuttle) is a Transparent proxy server that is advertised to work as a poor man's VPN. It works by establishing an SSH connection to a remote host and routes the traffic from a local machine targeting a specific IP CIDR to a remote network such as, in our case, an AWS VPC.

To establish a sshuttle connection, you can simply reference your instance like in the previous example, as sshuttle is going to make use of your OpenSSH configuration automatically.

For example, the below example will establish a VPN-like connection between your development machine and your remote VPC - in this example, I use a VPC CIDR of `172.31.0.0/16` for the remote VPC.

```bash
sshuttle --dns -r user@i-example 172.31.0.0/16
```

This will cause sshuttle to tunnel all traffic targeting `172.31.0.0/16` through an SSH-over-SSM tunnel using your EC2 instance as a jump host.

<br />
<p align="center">
  <img width="650" src="assets/sshuttle-diagram.png">
</p>
<br />

### Disabling EC2 Instance Connect

By default, the proxy command script provided by `ssm-supercharged` assumes no SSH key-pair are associated with an instance and instead generates ephemeral RSA key-pairs for each connection which are pushed to the instance using the EC2 Instance Connect service.

EC2 Instance Connect is currently only available on Ubuntu and Amazon Linux AMIs. If you are using another operating system such as RedHat, you can explicitely provide `ssh` with a private key you own when connecting to the instance.

```bash
ssh -i /path/to/key.pem user@i-example
```

If you want the `ssm-supercharged` proxy command script to stop using EC2 Instance Connect for all instances and rely on your provided SSH key-pairs, you can update the `~/.ssh/config` file by appending a `-e no` option to the proxy command.

```ssh
ProxyCommand ~/.ssh/initiate-ssm-connection.sh -h %h -u %r -p %p -e no
```

## 👀 See Also

- How to install the [SSM Sessions Manager Plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html). 
- The [EC2 Instance Connect](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/Connect-using-EC2-Instance-Connect.html) documentation.
- The [sshuttle documentation](https://github.com/sshuttle/sshuttle).
