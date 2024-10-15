# smart-open.nvim

A [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) extension designed to provide the best possible suggestions for quickly opening files in Neovim.  smart-open will improve its suggestions over time, adapting to your usage.

**Warning** ⚠️  smart-open is **beta** at this time. Contributions welcome.

![Preview](https://i.imgur.com/GShkgXm.gif)

## Isn't this yet another fuzzy file finding plugin?

In a way, but most other solutions require multiple mappings to search:

* git files
* open buffers
* recent files

The goal of smart-open is to give you highly relevant results with as few keystrokes as possible--so much so that only a single mapping is needed for searching everything while still managing to be quick about it.

## How it works

The source of suggestions is a combination of files under the current working directory, and your history.  Ranking takes the following factors into account:

- How well the file path matches the search text
- How well the file *name* matches the search text (see notes for file name details)
- Recency of last open
- Whether the file is the last-edited (that is, alternate buffer)
- The file is currently open
- How close the file's parent directory is to the currently-open file's
- "Frecency" - how frequently the file has been opened, with a bias toward recent opens. (See notes on frecency)
- Whether the file is anywhere under the current working directory.  This is especially useful if using an extension that cd's to your project's top-level directory.

This ranking algorithm is self-tuning.  Over time, the weights of the factors above will be adjusted based upon your interaction with it.  The tuning process is especially sensitive to selecting a suggestion that is not at the top.  Weights will be adjusted relative to the higher-ranked suggestions that were not selected.

Calculating and tuning all these factors might sound slow, but this is not the case.  Results return quickly and the impact of these calculations are optimized to be negligible.

# Notes

- In certain cases, both the parent directory as well as the filename are treated as the "file name".  This is because for some file structures, the filename itself isn't informative.  For example, if your JavaScript project uses the convention of `directoryName/index.js` throughout, then searching for "index" isn't going to be very useful.  As a result, we treat `index.js` and `init.lua` as special cases, and treat `parentDirectory/filename` as though it were the filename.
- Search text matching uses the fzy algorithm.  If telescope-fzy-native is installed, it will be used.
- Determining how close two files' directories are is just a function of how many directories the two files have in common.  This means that for any pair of files in the same directory, the score is more significant the deeper that directory is.
- Frecency controls how long a given file is preserved in history.  While it can be replenished by opening that file, this value otherwise dwindles over time. When the value is fully depleted, the file can be cleared from the history, improving performance and disk usage. Frecency uses an implementation of Mozilla's [Frecency algorithm](https://developer.mozilla.org/en-US/docs/Mozilla/Tech/Places/Frecency_algorithm) (used in [Firefox's address bar](https://support.mozilla.org/en-US/kb/address-bar-autocomplete-firefox)).

# Acknowledgements

- Thanks to telescope-frecency.nvim for inspiration.  This code is also adapted from that code base.


Using an implementation of Mozilla's [Frecency algorithm](https://developer.mozilla.org/en-US/docs/Mozilla/Tech/Places/Frecency_algorithm) (used in [Firefox's address bar](https://support.mozilla.org/en-US/kb/address-bar-autocomplete-firefox)), files edited _frecently_ are given higher precedence in the list index.

As the extension learns your editing habits over time, the sorting of the list is dynamically altered to prioritize the files you're likely to need.

## Requirements

- neovim 0.6+ (required)
- ripgrep (required)
- sqlite3 (required)
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) (required)
- [sqlite.lua](https://github.com/kkharji/sqlite.lua) (required)
- [nvim-web-devicons](https://github.com/kyazdani42/nvim-web-devicons) (optional)
- [telescope-fzy-native.nvim](https://github.com/nvim-telescope/telescope-fzy-native.nvim) (optional)
- [telescope-fzf-native.nvim](https://github.com/nvim-telescope/telescope-fzf-native.nvim) (optional)

Timestamps, scoring weights, and file records are stored in an [SQLite3](https://www.sqlite.org/index.html) database for persistence and speed.

## Installation

### [Lazy.nvim](https://github.com/folke/lazy.nvim)

Put the following in your `lazy.setup(...)`:

```lua
{
  "danielfalk/smart-open.nvim",
  branch = "0.2.x",
  config = function()
    require("telescope").load_extension("smart_open")
  end,
  dependencies = {
    "kkharji/sqlite.lua",
    -- Only required if using match_algorithm fzf
    { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    -- Optional.  If installed, native fzy will be used when match_algorithm is fzy
    { "nvim-telescope/telescope-fzy-native.nvim" },
  },
}
```

### [Packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "danielfalk/smart-open.nvim",
  branch = "0.2.x",
  config = function()
    require"telescope".load_extension("smart_open")
  end,
  requires = {
    {"kkharji/sqlite.lua"},
    -- Only required if using match_algorithm fzf
    { "nvim-telescope/telescope-fzf-native.nvim", run = "make" },
    -- Optional.  If installed, native fzy will be used when match_algorithm is fzy
    { "nvim-telescope/telescope-fzy-native.nvim" },
  }
}
```

### sqlite3 (required)

sqlite3 must be installed locally. (if you are on mac it might be installed already)

#### Windows

[Download precompiled](https://www.sqlite.org/download.html) and set `let g:sqlite_clib_path = path/to/sqlite3.dll` (note: `/`)

#### Linux

##### Arch
```bash
sudo pacman -S sqlite # Arch
sudo apt-get install sqlite3 libsqlite3-dev # Ubuntu
```
##### Fedora
```
sudo dnf install sqlite sqlite-devel sqlite-tcl
```

#### Nix (home-manager)
```nix
programs.neovim.plugins = [
    {
      plugin = pkgs.vimPlugins.sqlite-lua;
      config = "let g:sqlite_clib_path = '${pkgs.sqlite.out}/lib/libsqlite3.so'";
    }
];
```

#### Nix (without home-manager)

```nix
environment.variables = {
    LIBSQLITE = "${pkgs.sqlite.out}/lib/libsqlite3.so";
};
```

If no database is found when running Neovim with the plugin installed, a new one is created and entries from `shada` `v:oldfiles` are automatically imported.

## Usage

```
:Telescope smart_open
```
..or to map to a key:

```lua
vim.keymap.set("n", "<leader><leader>", function ()
  require("telescope").extensions.smart_open.smart_open()
end, { noremap = true, silent = true })
```

## Options

Options can be set when opening the picker.  For example:

```lua
require('telescope').extensions.smart_open.smart_open {
  cwd_only = true,
  filename_first = false,
}
```

- `cwd_only` (default: `false`)

  Limit the results to files under the current working directory.  This is normally not needed because if you prefer this pattern of access, then the plugin will pick up on that over time regardless, to the point where files under `cwd` will be recommended above all others.

- `filename_first` (default: `true`)

  Format filename as "filename path/to/parent/directory" if `true` and "path/to/parent/directory/filename" if `false`.


## Configuration

See [default configuration](https://github.com/nvim-telescope/telescope.nvim#telescope-defaults) for full details on configuring Telescope.

- `show_scores` (default : `false`)

  To see the scores generated by the algorithm in the results, set this to `true`.

- `ignore_patterns`

  Patterns in this table control which files are indexed (and subsequently which you'll see in the finder results).

  Defaults can be found in the [source code](https://github.com/danielfalk/smart-open.nvim/blob/main/lua/telescope/_extensions/smart_open/default_config.lua#L5)

- `match_algorithm` (default: `fzy`)

  The algorithm to use for determining how well each file path matches the typed-in search text.  Options are `fzf` and `fzy`.  Entered text is not the only factor considered in ranking but is typically the most significant.

- `disable_devicons` (default: `false`)

  Disable devicons (if available)

- `open_buffer_indicators` (default: `{previous = "•", others = "∘"}`)

- `result_limit` (default: `40`)

  Limit the number of results returned.  Note that this is kept intentionally low by default for performance.  The main goal of this plugin is to be able to jump to the file you want with very few keystrokes.  Smart open should put relevant results at your fingertips without having to waste time typing too much or scanning through a long list of results.  If you need to scan regardless, go ahead and increase this limit.  However, if better search results would make that unnecessary and there's a chance that smart open could provide them, please [file a bug](https://github.com/danielfalk/smart-open.nvim/issues/new) to help make it better.

### Example Configuration:

```
telescope.setup {
  extensions = {
    smart_open = {
      match_algorithm = "fzf",
      disable_devicons = false,
    },
  },
}

```

### Known Limitations

For files not already in your history, smart-open uses ripgrep for scanning the current directory.  (The command is roughly: `rg --files --glob-case-insensitive --hidden --ignore-file=<cwd>/.ff-ignore -g <ignore_patterns...>`).

As a result, files added to git, _but also ignored by git_, will not be included.  While not common, this is something that git allows. If this becomes a problem you can work around it by either changing your git ignore patterns, editing the file in neovim in some other way, (thereby adding it to the history), or by using ripgrep's `.ignore` file for overriding git.

### Highlight Groups

`SmartOpenDirectory` (links to `Directory`)
