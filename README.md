aw-watcher-vim
==============

Work in progress, contributing with bug reports on the GitHub issues page is appreciated :)

### Installation

This plugin depends on curl, so make sure that it's installed and available in yout PATH

It is recommended to have a vim runtime manager to make it easier to install (such as Pathogen or Vundle)

Then simply clone this repository to the bundle folder in your vim config folder (usually `~/.vim/bundle` or `~/.config/nvim/bundle` for neovim)

### Usage

Once installed in the bundle directory, it should load automatically if you have a vim runtime manager

```
:AWStart - start logging if not already logging
:AWStop - stop logging if logging
:AWStatus - verify that the watcher is running
```

If aw-watcher-vim loses connection it will give you an error message and stop logging. You then need to either run :AWStart or restart vim to start logging again
