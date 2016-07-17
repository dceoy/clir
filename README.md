clir
====

Command line interface for R package installation on Linux or Mac OS X

Installation
------------

1.  Install R if it is not already installed:

```sh
# Ubuntu
$ sudo apt-get -y install r-base

# CentOS
$ sudo yum -y install R-devel

# Fedora
$ sudo dnf -y install R-devel

# Homebrew on MacOSX
$ brew install homebrew/science/r
```

2.  Check out clir into `~/.clir` and run `install.sh`.

```sh
# One-liner
$ curl https://raw.githubusercontent.com/dceoy/clir/master/install.sh | bash

# Manual checkout
$ git clone https://github.com/dceoy/clir.git ~/.clir
$ ~/.clir/install.sh
```

3.  Add `~/.clir/bin` to `${PATH}` and add `~/.clir/r/library` to `${R_LIBS}`.

```sh
$ echo "export PATH=${HOME}/.clir/bin:${PATH}" >> ~/.bashrc
$ echo "export R_LIBS=${HOME}/.clir/r/library" >> ~/.bashrc
$ exec ${SHELL} -l
```

Note: If you use Zsh, modify `~/.zshrc` instead of `~/.bashrc`.

Usage
-----

```
Usage:  clir COMMAND [arg...]
        clir [ -h | --help | -v | --version ]
```

Run 'clir COMMAND --help' for more information on a command.

Example
-------

```sh
# Install or update R packages via CRAN
$ clir cran-install dplyr tidyr ggplot2

# Test loading of installed R packages
$ clir test-load dplyr tidyr ggplot2
```
