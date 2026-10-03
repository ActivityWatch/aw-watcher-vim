aw-watcher-vim
==============

### Installation

This plugin depends on `curl`, so make sure it is installed and available in your
editor's `PATH`. Choose one installation method below, then restart the editor.

#### Native Neovim packages

[Neovim's native packages](https://neovim.io/doc/user/pack/) load plugins in
`pack/*/start` automatically, without a plugin manager. On Linux/macOS:

```sh
mkdir -p "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/pack/activitywatch/start"
git clone https://github.com/ActivityWatch/aw-watcher-vim.git \
  "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/pack/activitywatch/start/aw-watcher-vim"
```

With the default data directory, this installs to
`~/.local/share/nvim/site/pack/activitywatch/start/aw-watcher-vim`.

#### Native Vim packages

For Vim with [native package support](https://vimhelp.org/repeat.txt.html#packages),
use the same layout under `~/.vim`:

```sh
mkdir -p ~/.vim/pack/activitywatch/start
git clone https://github.com/ActivityWatch/aw-watcher-vim.git \
  ~/.vim/pack/activitywatch/start/aw-watcher-vim
```

#### AstroNvim / lazy.nvim

For an AstroNvim configuration using `lua/plugins`, create
`lua/plugins/activitywatch.lua` in your Neovim configuration directory (normally
`~/.config/nvim`):

```lua
return {
  { "ActivityWatch/aw-watcher-vim", lazy = false },
}
```

Restart Neovim to install the plugin, then restart again after installation.
`lazy = false` loads it during startup so its `VimEnter` autostart runs. For other
lazy.nvim configurations, add the same plugin specification to your existing
plugin list. See [AstroNvim's plugin configuration guide](https://docs.astronvim.com/configuration/customizing_plugins/).

If you customize the globals listed below, set `vim.g.aw_apiurl_host`,
`vim.g.aw_apiurl_port`, etc. in the specification's
[`init` function](https://lazy.folke.io/spec). The plugin reads these settings when
it is sourced, so a `config` function runs too late. This is a Vimscript plugin;
it does not need a Lua `setup()` call or an `opts` table.

#### Pathogen / Vundle

The older `~/.vim/bundle/aw-watcher-vim` or
`~/.config/nvim/bundle/aw-watcher-vim` layout requires a configured plugin manager
such as Pathogen or Vundle. Cloning into `bundle` alone does not load the plugin.

### Usage

Start ActivityWatch before opening the editor. The plugin attempts to connect to
aw-server on editor startup (by default at `127.0.0.1:5600`).

- `:AWStatus` — show whether the watcher has connected to aw-server.
- `:AWStart` — connect or retry after starting ActivityWatch.
- `:AWStop` — stop logging.

An `E492: Not an editor command: AWStart` error means the plugin has not loaded
successfully. Check the installation path or plugin-manager specification, then
restart the editor. `:scriptnames` should include `plugin/activitywatch.vim`.
An existing `:AWStatus` command reporting `running: 0` means logging is stopped
or the connection has not succeeded. Start ActivityWatch, run `:AWStart`, then
check `:AWStatus` again after the request completes.

Open a file and move the cursor or edit it, then check the
`aw-watcher-vim_<hostname>` bucket in ActivityWatch for events. The watcher records
the file path, language (`filetype`) and project (editor working directory); it
does not change or depend on the terminal window title.

If the watcher loses connection, it reports an error and stops logging. Run
`:AWStart` or restart the editor to reconnect.

### Configuration

The following global variables are available:

| Variable Name      | Description                                    | Default Value |
|--------------------|------------------------------------------------|---------------|
| `g:aw_apiurl_host` | Sets the _host_ of the Api Url                 | `127.0.0.1`   |
| `g:aw_apiurl_port` | Sets the _port_ of the Api Url                 | `5600`        |
| `g:aw_api_timeout` | Sets the _timeout_ seconds of the Api request  | `2.0`         |
| `g:aw_hostname`    | Overides the default hostname                  | `hostname()`  |
