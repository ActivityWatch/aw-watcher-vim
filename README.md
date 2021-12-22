aw-watcher-vim
==============

### Installation

This plugin depends on curl, so make sure that it's installed and available in your PATH

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

### Configuration

The following global variables are available:

| Variable Name      | Description                                    | Default Value |
|--------------------|------------------------------------------------|---------------|
| `g:aw_apiurl_host` | Sets the _host_ of the Api Url                 | `127.0.0.1`   |
| `g:aw_apiurl_port` | Sets the _port_ of the Api Url                 | `5600`        |
| `g:aw_api_timeout` | Sets the _timeout_ seconds of the Api request  | `2.0`         |
