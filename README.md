# oil-download.nvim

Download files from [oil.nvim](https://github.com/stevearc/oil.nvim) the way you create them: paste a URL into an oil buffer, `:w`, and confirm it in oil's own dialog.

```
DOWNLOAD https://example.com/file.zip
CREATE notes.txt
             [Y]es    [N]o
```

## Requirements

- Neovim 0.10+
- oil.nvim
- `wget`, or any downloader you configure

## Install

[lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "Stromdahl/oil-download.nvim",
  dependencies = { "stevearc/oil.nvim" },
  opts = {}, -- optional
}
```

Don't set `cmd`, `keys` or `ft`. The plugin loads very little at startup and pulls in its modules only when they're first used.

`vim.pack` (Neovim 0.12+):

```lua
vim.pack.add({
  "https://github.com/stevearc/oil.nvim",
  { src = "https://github.com/Stromdahl/oil-download.nvim", version = vim.version.range("0.*") },
})
```

## Usage

1. Copy a URL.
2. In an oil buffer, press `p`. The URL goes on its own line, even when copied from a browser without a trailing newline.
3. `:w`. Oil's confirmation dialog shows `DOWNLOAD <url>` next to your other changes.
4. `Y` downloads in the background into the directory oil is showing. `N` keeps the URL lines in the buffer, just as oil keeps a cancelled edit.

Anything else you press `p` on, including oil entries you yanked to copy, pastes as usual.

`:OilDownload [url]` downloads straight away. With no argument it asks for a URL, prefilled from the clipboard.

## Configuration

No `setup()` call is needed. To change the defaults, set `vim.g.oil_download` or pass `opts`:

```lua
vim.g.oil_download = {
  default_keymaps = true, -- map `p` in oil buffers
  downloader = function(url, dir) -- argv that downloads `url` into `dir`
    return { "wget", "-q", "-P", dir, url }
  end,
  url_pattern = "^%s*https?://%S+%s*$",
}
```

To use curl instead:

```lua
downloader = function(url, dir)
  return { "curl", "-fsSLO", "--output-dir", dir, url }
end,
```

### Keymaps

| Mapping | Does |
|---|---|
| `<Plug>(oil-download-paste)` | `p` in oil buffers by default. URLs become lines that are downloaded on `:w` |
| `<Plug>(oil-download-prompt)` | Asks for a URL and downloads it now. Not mapped by default |

Setting `default_keymaps = false`, or mapping `p` in oil's own `keymaps`, turns the default `p` off.

## Health

`:checkhealth oil-download` checks your config, that the downloader is installed, which oil.nvim it found, and whether the dialog hook is active.

## Stability

Oil has no public API for adding lines to its confirmation dialog, so this plugin wraps two oil internals. All of that code is in [`lua/oil-download/oil_hook.lua`](lua/oil-download/oil_hook.lua).

Tests run against oil.nvim 2.16.0, plus a CI canary against oil's latest. If an oil update removes those internals, the plugin falls back to its own confirm prompt instead of breaking, and `:checkhealth` reports it. Please [open an issue](https://github.com/Stromdahl/oil-download.nvim/issues) if that happens.

## Development

```sh
uvx hererocks .hererocks -j https://github.com/LuaJIT/LuaJIT.git@v2.1 \
  -r https://github.com/luarocks/luarocks.git@v3.12.2
.hererocks/bin/luarocks install busted
.hererocks/bin/luarocks install nlua
.hererocks/bin/luarocks install oil.nvim 2.16.0-1
./scripts/test
```

Commits follow [Conventional Commits](https://www.conventionalcommits.org/). release-please uses them to cut versions.

## License

MIT
