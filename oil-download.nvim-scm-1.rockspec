rockspec_format = "3.0"
package = "oil-download.nvim"
version = "scm-1"

source = {
  url = "git+https://github.com/Stromdahl/oil-download.nvim",
}

description = {
  summary = "Paste URLs into an oil.nvim buffer and download them on :w",
  homepage = "https://github.com/Stromdahl/oil-download.nvim",
  license = "MIT",
  labels = { "neovim", "neovim-plugin", "oil.nvim" },
}

dependencies = {
  "oil.nvim",
}

test_dependencies = {
  "nlua",
  "oil.nvim == 2.16.0",
}

build = {
  type = "builtin",
  copy_directories = {
    "plugin",
    "ftplugin",
    "after",
    "doc",
  },
}
