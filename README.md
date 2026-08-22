# clir

R package installer for the command line.

[![CI](https://github.com/dceoy/clir/actions/workflows/ci.yml/badge.svg)](https://github.com/dceoy/clir/actions/workflows/ci.yml)

## Supported R versions

clir continuously tests the following support policy:

| Platform | R versions |
| :------: | :---------- |
| Linux | R-devel, current release, and oldrel-1 |
| macOS | current release (CLI smoke tests) |

## Usage

`clir install` and `clir update` use [`pak::pkg_install()`](https://pak.r-lib.org/reference/pkg_install.html).
Package references are passed to pak unchanged, so CRAN, Bioconductor, GitHub, Git, and package archive sources
can use the same command:

```sh
clir install dplyr
clir install bioc::GenomicRanges
clir install r-lib/cli
clir install git::https://example.com/packages/example.git
clir update
```

Only required package dependencies are installed by default. Use pak's package-reference parameters when a
different dependency policy is needed.

Other commands are available for configuration and package maintenance:

```sh
clir config --init
clir cran https://cloud.r-project.org/
clir validate dplyr
clir session dplyr
clir download dplyr
clir uninstall dplyr
```

The former `drat`, `--devt`, and `--bioc` interfaces are removed. Use generic pak package references instead.
Run `clir --help` for the complete command reference.

## Installation

Install R and Git. On Debian or Ubuntu, install the libcurl development
headers used when pak builds its dependencies from source:

```sh
sudo apt-get update
sudo apt-get install --no-install-recommends -y libcurl4-openssl-dev
```

Then check out clir and run the installer:

```sh
git clone https://github.com/dceoy/clir.git ~/.clir
~/.clir/install_clir.sh
```

The installer bootstraps only `docopt`, `yaml`, and `pak`. Use `--root` to install into `/usr/local`:

```sh
sudo ~/.clir/install_clir.sh --root
```

Add the clir `bin` directory to `PATH` after installation. `install_clir.sh --help` lists all installer options.

## Libraries and configuration

When neither `R_LIBS_USER` nor `R_LIBS` is set, the `bin/clir` launcher sets
an R-version-aware library before R starts:

```text
~/.clir/r/<R-major>.<R-minor>/library
```

For example, R 4.3 uses `~/.clir/r/4.3/library`. Explicit `R_LIBS_USER` and
`R_LIBS` values remain authoritative across invocations.
The installer option `--delete-r-lib` can reset only the current versioned library below the clir-managed `r`
directory. It rejects external paths, the managed root, and symlinked targets.

Configuration is stored in `r/clir.yml` below the clir root using named repositories:

```yaml
repos:
  CRAN: https://cloud.r-project.org/
```

Existing configurations using `cran_urls` are read and normalized when clir is upgraded.
