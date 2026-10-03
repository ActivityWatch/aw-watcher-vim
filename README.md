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
| `g:aw_apiurl_host` | Sets the _host_ of the Api Url                 | `'127.0.0.1'` |
| `g:aw_apiurl_port` | Sets the _port_ of the Api Url                 | `5600`        |
| `g:aw_api_timeout` | Sets the _timeout_ seconds of the Api request  | `2.0`         |
| `g:aw_hostname`    | Overides the default hostname                  | `hostname()`  |

Set configuration before the plugin loads. Quote the host in your vimrc:

```vim
let g:aw_apiurl_host = '127.0.0.1'
let g:aw_apiurl_port = 5600
let g:aw_api_timeout = 2
```

Vim interprets an unquoted `127.0.0.1` as concatenation and produces `127001`.

### Connection troubleshooting

Use `:messages` to inspect a connection failure. The message includes the
requested URL and curl's diagnostic; `000` means no HTTP response was received.
Check that ActivityWatch is running and that the URL uses the configured host
and port. After correcting the configuration, reload the plugin by restarting
the editor. If only the server was stopped, start it and run `:AWStart` to retry.

The heartbeat endpoint accepts a JSON **POST** request. Visiting its URL in a
browser or with a plain `curl URL` sends a GET; that does not test heartbeats.
