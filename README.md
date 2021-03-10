clir
====

R Package Installer for Command Line Interface

[![Test](https://github.com/dceoy/clir/actions/workflows/test.yml/badge.svg)](https://github.com/dceoy/clir/actions/workflows/test.yml)

#### Supported versions

|     R    |     clir    |
|:--------:|:-----------:|
| &ge; 3.5 | &ge; v1.1.0 |
| &lt; 3.5 | &lt; v1.0.8 |

Docker image
------------

The image is available at [Docker Hub](https://hub.docker.com/r/dceoy/clir/).

```sh
$ docker pull dceoy/clir
```

Setup
-----

#### Installation

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

#### Update

Update clir and the dependencies.

```sh
$ ~/.clir/install_clir.sh
```

Update only clir.

```sh
$ cd ~/.clir
$ git pull
```

#### Configuration

- Library path

  R packages are installed into a directory in `${R_LIBS_USER}` nor `${R_LIBS}`.
  If neither of them is set, a default library path is used.
  The default path can be checked as follows:

  ```sh
  $ R --slave -e '.libPaths()[1]'
  ```

- CRAN and Drat repositories

  clir saves URLs of CRAN mirrors and Drat repositories into `~/.clir/r/clir.yml` as a YAML file.

#### Installation into a system

Run the installer with `--root` if you install clir into a system. (clir is going to be installed into `/usr/local` then.)

```sh
$ curl -LSO https://raw.githubusercontent.com/dceoy/clir/master/install_clir.sh
$ chmod +x install_clir.sh
$ sudo ./install_clir.sh --root
$ rm install_clir.sh
```

Update clir installed into the system.

```sh
$ sudo /usr/local/src/clir/install_clir.sh --root
```

Usage
-----

```sh
$ clir --help
R Package Installer for Command Line Interface

Usage:
    clir config [-v] [--init]
    clir cran [-v] [--list] [<url>...]
    clir drat [-v] <repo>...
    clir update [-v] [--quiet] [--bioc]
    clir install [-v] [--quiet] [--devt=<type>|--bioc] [--no-upgrade] <pkg>...
    clir download [-v] [--quiet] [--dest-dir=<path>] <pkg>...
    clir uninstall [-v] [--quiet] <pkg>...
    clir validate [-v] [--quiet] <pkg>...
    clir session [-v] [<pkg>...]
    clir -h|--help
    clir --version

Options:
    --init              Initialize configurations for clir
    --list              List URLs of CRAN mirrors
    --devt=<type>       Use `devtools::install_<type>`
                        [choices: cran, github, bitbucket, bioc]
    --bioc              Use BiocManager::install
    --no-upgrade        Skip upgrade of old R packages
    --dest-dir=<path>   Set a destination directory [default: .]
    --quiet             Suppress messages
    -v                  Execute a command with verbose messages
    -h, --help          Print help and exit
    --version           Print version and exit

Commands:
    config              Print configurations for clir
    cran                Set URLs of CRAN mirror sites
    drat                Set Drat repositories
    update              Update installed R packages via CRAN or Bioconductor
    install             Install or update R packages
    download            Download R packages from CRAN
    uninstall           Uninstall R packages
    validate            Load R packages to validate their installation
    session             Print session infomation

Arguments:
    <url>...            URLs of CRAN mirrors
    <repo>...           Drat repository names
    <pkg>...            R package names
```

Example
-------

Install or update R packages via CRAN.

```sh
# Using install.packages()
$ clir install dplyr tidyr ggplot2

# Using devtools::install_cran()
$ clir install --devt=cran dplyr tidyr ggplot2
```

Validate loading of installed R packages.

```sh
$ clir validate dplyr tidyr ggplot2
```
