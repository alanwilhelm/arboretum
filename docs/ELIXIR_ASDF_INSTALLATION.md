# Elixir and Phoenix Installation Guide Using ASDF

This guide documents the process of installing Elixir and Phoenix using ASDF on Ubuntu 22.04.5 LTS server.

## Prerequisites

1. Update system packages:
```bash
sudo apt-get update
sudo apt-get upgrade -y
```

2. Install ASDF dependencies:
```bash
sudo apt-get install -y curl git
```

## ASDF Installation

1. Clone ASDF repository:
```bash
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0
```

2. Add ASDF to your shell:
```bash
echo -e "\n. \$HOME/.asdf/asdf.sh" >> ~/.bashrc
echo -e ". \$HOME/.asdf/completions/asdf.bash" >> ~/.bashrc
```

3. Reload your shell configuration:
```bash
source ~/.bashrc
```

4. Verify ASDF installation:
```bash
asdf --version
# Expected output: v0.14.0-ccdd47d
```

## Erlang Installation

1. Add Erlang plugin:
```bash
asdf plugin add erlang
```

2. Install Erlang build dependencies:
```bash
sudo apt-get -y install build-essential autoconf m4 libncurses5-dev \
  libwxgtk3.0-gtk3-dev libgl1-mesa-dev libglu1-mesa-dev libpng-dev \
  libssh-dev unixodbc-dev xsltproc fop
```

3. Install Erlang:
```bash
asdf install erlang 27.3.4
```

## Elixir Installation

1. Add Elixir plugin:
```bash
asdf plugin add elixir
```

2. Install Elixir:
```bash
asdf install elixir 1.18.3-otp-27
```

## Set Global Versions

1. Set Erlang as global version:
```bash
asdf global erlang 27.3.4
```

2. Set Elixir as global version:
```bash
asdf global elixir 1.18.3-otp-27
```

3. Verify installation:
```bash
elixir --version
```

Expected output:
```
Erlang/OTP 27 [erts-15.2.7] [source] [64-bit] [smp:4:4] [ds:4:4:10] [async-threads:1] [jit:ns]
Elixir 1.18.3 (compiled with Erlang/OTP 27)
```

## Phoenix Installation

Install Phoenix framework:
```bash
mix archive.install hex phx_new --force
```

## Version Management

To list available versions:
```bash
asdf list-all erlang
asdf list-all elixir
```

To install a different version:
```bash
asdf install erlang <version>
asdf install elixir <version>
```

To set a version locally for a project:
```bash
asdf local erlang <version>
asdf local elixir <version>
```

## Troubleshooting

### Command not found
If ASDF commands are not found, make sure ASDF is loaded:
```bash
. $HOME/.asdf/asdf.sh
```

### Build failures
Ensure all dependencies are installed:
```bash
sudo apt-get install build-essential autoconf m4 libncurses5-dev \
  libwxgtk3.0-gtk3-dev libgl1-mesa-dev libglu1-mesa-dev libpng-dev \
  libssh-dev unixodbc-dev xsltproc fop
```

## Notes

- ASDF allows easy switching between different Erlang/Elixir versions
- Each Phoenix project can have its own `.tool-versions` file specifying exact versions
- The installation path for ASDF is `~/.asdf`
- Global versions are stored in `~/.tool-versions`