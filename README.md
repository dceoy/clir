clir
====

Command line interface for R package installation

[![wercker status](https://app.wercker.com/status/da3a4252a2993c3e515da0eed15a14fd/m "wercker status")](https://app.wercker.com/project/bykey/da3a4252a2993c3e515da0eed15a14fd)

Installation
------------

##### 1.  Install R and additional packages

```sh
# Ubuntu
$ sudo apt-get -y install r-base-dev libcurl4-gnutls-dev libssl-dev git

# CentOS
$ sudo yum -y install R-devel libcurl-devel openssl-devel git

# Fedora
$ sudo dnf -y install R-devel libcurl-devel openssl-devel git
```

##### 2.  Check out clir into `~/.clir` and run `install.sh`.

```sh
$ git clone https://github.com/dceoy/clir.git ~/.clir
$ .clir/install.sh
```

`install.sh` installs [devtools](https://github.com/hadley/devtools) and [drat](https://github.com/eddelbuettel/drat).
 Some of clir commands require them.

##### 3.  Add `~/.clir/bin` to `${PATH}` and add `~/.clir/r/library` to `${R_LIBS}`.

```sh
$ echo "export PATH=${HOME}/.clir/bin:${PATH}" >> ~/.bashrc
$ echo "export R_LIBS=${HOME}/.clir/r/library" >> ~/.bashrc
$ exec ${SHELL} -l
```

Note: If you use Zsh, modify `~/.zshrc` instead of `~/.bashrc`.

Usage
-----

```
clir COMMAND [arg...]
clir [ -h | --help | -v | --version ]
```

| command           | description                                   | depends          |
|:------------------|:----------------------------------------------|:-----------------|
| bioc-install      | Install or update R packages via Bioconductor | -                |
| bitbucket-install | Install or update R packages via Bitbucket    | devtools         |
| cran-install      | Install or update R packages via CRAN         | (devtools, drat) |
| github-install    | Install or update R packages via GitHub       | devtools         |
| set-cran          | Set URLs of CRAN mirror sites                 | -                |
| set-drat          | Set Drat repositories                         | -                |
| test-load         | Test loading of installed R packages          | (devtools)       |

* Depending packages in () are not required, but they are used if installed.

Run `clir COMMAND --help` for more information on a command.

Example
-------

```sh
$ clir cran-install dplyr tidyr ggplot2   # Install or update R packages via CRAN
$ clir test-load dplyr tidyr ggplot2      # Test loading of installed R packages
```
