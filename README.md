# clir

R Package Installer for Command Line Interface

[![CI/CD](https://github.com/dceoy/clir/actions/workflows/ci.yml/badge.svg)](https://github.com/dceoy/clir/actions/workflows/ci.yml)

#### Supported versions

|    R     |    clir     |
| :------: | :---------: |
| &ge; 3.5 | &ge; v1.1.0 |
| &lt; 3.5 | &lt; v1.0.8 |

## Usage

#### Installation or update of R packages

- Install packages via CRAN using `install.packages()`.

  ```sh
  $ clir install foreach doParallel tidyverse
  ```

- Install or update packages via CRAN using `devtools::install_cran()`.

  ```sh
  $ clir install --devt=cran foreach doParallel tidyverse
  ```

- Install or update packages via GitHub using `devtools::install_github()`.

  ```sh
  $ clir install --devt=github IRkernel/IRkernel
  ```

- Install or update packages via Bioconductor using `BiocManager::install()`.

  ```sh
  $ clir install --bioc GenomicRanges
  ```

- Install or update packages via Bioconductor using `devtools::install_bioc()`.

  ```sh
  $ clir install --devt=bioc GenomicRanges
  ```

- Update packages via CRAN using `update.packages()`.

  ```sh
  $ clir update
  ```

#### Validation of installed R packages

- Validate loading of installed packages.

  ```sh
  $ clir validate foreach doParallel tidyverse
  ```

#### Session information

- Load packages and print session information.

  ```sh
  $ clir session foreach doParallel tidyverse
  ```

Run `clir --help` for information.

## Docker image

The image is available at [Docker Hub](https://hub.docker.com/r/dceoy/clir/).

```sh
$ docker image pull dceoy/clir
```

## Installation

#### Installation into a local environment

1.  Install R and the additional packages.

    ```sh
    # Ubuntu
    $ sudo apt-get -y install git libcurl4-gnutls-dev libssl-dev libxml2-dev r-base

    # CentOS
    $ sudo yum -y install git libcurl-devel libxml2-devel openssl-devel R-devel

    # Fedora
    $ sudo dnf -y install git libcurl-devel libxml2-devel openssl-devel R-devel

    # macOS with Homebrew
    $ brew tap homebrew/science
    $ brew install curl git openssl r
    ```

2.  Check out clir and run `install_clir.sh`.

    ```sh
    $ git clone https://github.com/dceoy/clir.git ~/.clir
    ```

3.  Install clir and the dependencies.

    ```sh
    $ ~/.clir/install_clir.sh
    ```

    `install_clir.sh` installs the following R packages:
    - [docopt](https://cran.r-project.org/web/packages/docopt/index.html)
    - [yaml](https://cran.r-project.org/web/packages/yaml/index.html)
    - [devtools](https://cran.r-project.org/web/packages/devtools/index.html)
    - [drat](https://cran.r-project.org/web/packages/drat/index.html)
    - [BiocManager](https://cran.r-project.org/web/packages/BiocManager/index.html)

    clir depends on docopt and yaml, and uses devtools, drat, and BiocManager additionally if they are available.

    Run `~/.clir/install_clir.sh --help` for more details of the installer.

4.  Set `~/.clir/bin` into `${PATH}` and set `~/.clir/r/library` into `${R_LIBS_USER}` or `${R_LIBS}`.

    ```sh
    $ echo 'export PATH="${HOME}/.clir/bin:${PATH}"' >> ~/.bash_profile
    $ echo 'export R_LIBS_USER="${HOME}/.clir/r/library"' >> ~/.bash_profile
    $ source ~/.bash_profile
    ```

    If you use Zsh, modify `~/.zshrc` instead of `~/.bash_profile`.

#### Installation into a system

Run the installer with `--root` if you install clir into a system. (clir is going to be installed into `/usr/local` then.)

```sh
$ curl -LSO https://raw.githubusercontent.com/dceoy/clir/master/install_clir.sh
$ chmod +x install_clir.sh
yy$ sudo ./install_clir.sh --root
$ rm install_clir.sh
```

## Update

#### Update of clir in a local environment

```sh
$ ~/.clir/install_clir.sh
```

#### Update of clir installed into the system

```sh
$ sudo /usr/local/src/clir/install_clir.sh --root
```

## Configuration

- Library path

  R packages are installed into a directory in `${R_LIBS_USER}` nor `${R_LIBS}`.
  If neither of them is set, a default library path is used.
  The default path can be checked as follows:

  ```sh
  $ R --slave -e '.libPaths()[1]'
  ```

- CRAN and Drat repositories

  clir saves URLs of CRAN mirrors and Drat repositories into `~/.clir/r/clir.yml` as a YAML file.
