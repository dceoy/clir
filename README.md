clir
====

R package manager for command line interface

[![wercker status](https://app.wercker.com/status/e04414d822f906b0704855f5c2d600bf/m "wercker status")](https://app.wercker.com/project/bykey/e04414d822f906b0704855f5c2d600bf)

Installation
------------

1.  Install R and the additional packages.

    ```sh
    # Ubuntu
    $ sudo apt-get -y install r-base libcurl4-gnutls-dev libssl-dev git

    # CentOS
    $ sudo yum -y install R-devel libcurl-devel openssl-devel git

    # Fedora
    $ sudo dnf -y install R-devel libcurl-devel openssl-devel git

    # macOS with Homebrew
    $ brew tap homebrew/science
    $ brew install r curl openssl git
    ```

2.  Run `install.sh`.

    ```sh
    $ curl https://raw.githubusercontent.com/dceoy/clir/master/install.sh | bash
    ```

    `install.sh` clones clir into `~/.clir/` and installs the following R packages:

    - [docopt](https://cran.r-project.org/web/packages/docopt/index.html)
    - [yaml](https://cran.r-project.org/web/packages/yaml/index.html)
    - [devtools](https://cran.r-project.org/web/packages/devtools/index.html)
    - [drat](https://cran.r-project.org/web/packages/drat/index.html)

    clir depends on docopt and yaml, and uses devtools and drat additionally if they are available.

3.  Add `~/.clir/bin` to `${PATH}` and add `~/.clir/r/library` to `${R_LIBS}` or `${R_LIBS_USER}`.

    ```sh
    $ echo 'export PATH="${HOME}/.clir/bin:${PATH}"' >> ~/.bash_profile
    $ echo 'export R_LIBS_USER="${HOME}/.clir/r/library"' >> ~/.bash_profile
    $ source ~/.bash_profile
    ```

    If you use Zsh, modify `~/.zshrc` instead of `~/.bash_profile`.

Update
------

Update clir and the dependencies

```sh
$ ~/.clir/install.sh
```

Update only clir

```sh
$ cd ~/.clir
$ git pull
```

Usage
-----

```sh
R package manager for command line interface

Usage:
    clir config [--debug] [--init]
    clir cran [--debug] [--list] [<url>...]
    clir drat [--debug] <repo>...
    clir update [--debug] [--quiet]
    clir install [--debug] [--quiet] [--no-upgrade] [--devt=<type>] <pkg>...
    clir uninstall [--debug] <pkg>...
    clir validate [--debug] [--quiet] <pkg>...
    clir session [--debug] [<pkg>...]
    clir -h|--help
    clir -v|--version

Options:
    --debug             Execute a command with debug messages
    --init              Initialize configurations for clir
    --list              List URLs of CRAN mirrors
    --devt=<type>       Install R packages using `devtools::install_<type>`
                        [choices: cran, github, bitbucket, bioc]
    --no-upgrade        Skip upgrade of old R packages
    --quiet             Suppress messages
    -h, --help          Print help and exit
    -v, --version       Print version and exit

Commands:
    config              Print configurations for clir
    cran                Set URLs of CRAN mirror sites
    drat                Set Drat repositories
    update              Update R packages installed via CRAN
    install             Install or update R packages
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

Install or update R packages via CRAN

```sh
$ clir install dplyr tidyr ggplot2
```

Validate loading of installed R packages

```sh
$ clir validate dplyr tidyr ggplot2
```
