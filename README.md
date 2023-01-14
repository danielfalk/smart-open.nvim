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
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) (required)
- [sqlite.lua](https://github.com/tami5/sqlite.lua) (required)
- [nvim-web-devicons](https://github.com/kyazdani42/nvim-web-devicons) (optional)
- [telescope-fzy-native.nvim](https://github.com/nvim-telescope/telescope-fzy-native.nvim) (optional)

Timestamps, scoring weights, and file records are stored in an [SQLite3](https://www.sqlite.org/index.html) database for persistence and speed.

## Installation

### [Packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "danielfalk/smart-open.nvim",
  config = function()
    require"telescope".load_extension("smart_open")
  end,
  requires = {"tami5/sqlite.lua"}
}

```

If no database is found when running Neovim with the plugin installed, a new one is created and entries from `shada` `v:oldfiles` are automatically imported.

## Usage

```
:Telescope smart_open
```
..or to map to a key:

```lua
vim.api.nvim_set_keymap("n", "<leader><leader>", "<Cmd>lua require('telescope').extensions.smart_open.smart_open()<CR>", {noremap = true, silent = true})
```

## Options

Options can be set when opening the picker.  For example:

```lua
require('telescope').extensions.smart_open.smart_open({cwd_only = true})
```

- `cwd_only` (default: `false`)

  Limit the results to files under the current working directory.  This is normally not needed because if you prefer this pattern of access, then the plugin will pick up on that over time regardless, to the point where files under `cwd` will be recommended above all others.

## Configuration

See [default configuration](https://github.com/nvim-telescope/telescope.nvim#telescope-defaults) for full details on configuring Telescope.

- `ignore_patterns` (default: `{"*.git/*", "*/tmp/*"}`)

  Patterns in this table control which files are indexed (and subsequently which you'll see in the finder results).

- `show_scores` (default : `false`)

  To see the scores generated by the algorithm in the results, set this to `true`.

- `max_unindexed` (default: `6500`)

  Stop scanning the current directory when `max_unindexed` files have been found.  This limit is in place to prevent performance problems when run from a directory with an excessive number of files under it.

- `devicons_disabled` (default: `false`)

  Disable devicons (if available)


### Example Configuration:

```
telescope.setup {
  extensions = {
    smart_open = {
      show_scores = false,
      max_unindexed = 1000,
      ignore_patterns = {"*.git/*", "*/tmp/*"},
      disable_devicons = false,
    },
  },
}

```

### Highlight Groups

```vim
TelescopeBufferLoaded
TelescopePathSeparator
TelescopeQueryFilter
```


