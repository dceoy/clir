clir
====

Command line interface for R package installation

[![wercker status](https://app.wercker.com/status/e04414d822f906b0704855f5c2d600bf/m "wercker status")](https://app.wercker.com/project/bykey/e04414d822f906b0704855f5c2d600bf)

Installation
------------

1.  Install R and the additional packages.

    ```sh
    # Ubuntu
    $ sudo apt-get -y install r-base-dev libcurl4-gnutls-dev libssl-dev git

    # CentOS
    $ sudo yum -y install R-devel libcurl-devel openssl-devel git

    # Fedora
    $ sudo dnf -y install R-devel libcurl-devel openssl-devel git
    ```

2.  Check out clir into `~/.clir` and run `install.sh`.

    ```sh
    $ git clone https://github.com/dceoy/clir.git ~/.clir
    $ .clir/install.sh
    ```

    `install.sh` installs [devtools](https://github.com/hadley/devtools) and [drat](https://github.com/eddelbuettel/drat).
    Some of clir commands require them.

3.  Add `~/.clir/bin` to `${PATH}` and add `~/.clir/r/library` to `${R_LIBS}`.

    ```sh
    $ echo "export PATH=${HOME}/.clir/bin:${PATH}" >> ~/.bash_profile
    $ echo "export R_LIBS=${HOME}/.clir/r/library" >> ~/.bash_profile
    $ source ~/.bash_profile
    ```

    If you use Zsh, modify `~/.zshrc` instead of `~/.bash_profile`.

Usage
-----

```
clir COMMAND [arg...]
clir [ -h | --help | -v | --version ]
```

| command           | description                                                        | depends          |
|:------------------|:-------------------------------------------------------------------|:-----------------|
| bioc-install      | Install or update R packages via Bioconductor                      | -                |
| bitbucket-install | Install or update R packages via Bitbucket                         | devtools         |
| cran-install      | Install or update R packages via CRAN                              | (devtools, drat) |
| github-install    | Install or update R packages via GitHub                            | devtools         |
| install           | Install or update R packages via CRAN (shortcut of `cran-install`) | (devtools, drat) |
| print-libpath     | Print the path where R packages are installed                      | -                |
| set-cran          | Set URLs of CRAN mirror sites                                      | -                |
| set-drat          | Set Drat repositories                                              | -                |
| test-load         | Test loading of installed R packages                               | (devtools)       |

\* Packages in () are not required, but they are used if installed.

Run `clir COMMAND --help` for more information on a command.

Example
-------

```sh
$ clir cran-install dplyr tidyr ggplot2   # Install or update R packages via CRAN
$ clir test-load dplyr tidyr ggplot2      # Test loading of installed R packages
```
