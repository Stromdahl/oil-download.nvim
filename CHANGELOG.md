# Changelog

## 0.1.0 (2026-11-07)


### Features

* :checkhealth oil-download ([af24784](https://github.com/Stromdahl/oil-download.nvim/commit/af24784728bfc9a81e578c17a675dca16c238985))
* checkhealth reports whether DOWNLOAD highlighting is loaded ([8cb5585](https://github.com/Stromdahl/oil-download.nvim/commit/8cb558578fd29a6cafc432049004cedc041896e9))
* download URL lines from oil's :w confirmation dialog ([0183675](https://github.com/Stromdahl/oil-download.nvim/commit/018367549f9c674eedfe58577cb392bdc9361a03))
* p in oil buffers pastes URLs as lines to download on :w ([8e6fcea](https://github.com/Stromdahl/oil-download.nvim/commit/8e6fceac56ebfc23f7b38f40202f3528be240da8))


### Bug Fixes

* fallback No keeps URL lines in hidden oil buffers ([a5598af](https://github.com/Stromdahl/oil-download.nvim/commit/a5598afef75e6321c9ed5ddd7478bf62a72b12fa))
* fallback prompt names each URL's own target directory ([2c640a5](https://github.com/Stromdahl/oil-download.nvim/commit/2c640a5dc9cdd079d31207b4f177397feefe0dfd))
* keep oil's diagnostic on its line after fallback No ([68b3f43](https://github.com/Stromdahl/oil-download.nvim/commit/68b3f435ae28e1121cd88b9f1ba4dfd3bd60221a))
* keep oil's parse-error diagnostic on its line after restoring URLs ([7f214a5](https://github.com/Stromdahl/oil-download.nvim/commit/7f214a5d1953bb45f5151d5ee797a51849289910))
* paste into an empty oil directory without a blank line ([57c18b7](https://github.com/Stromdahl/oil-download.nvim/commit/57c18b706770c3c761b7fc7091e2e792ea79d4e0))
* put URL lines back on No in the fallback prompt ([f522f39](https://github.com/Stromdahl/oil-download.nvim/commit/f522f394fd03e44c895da6a2e044e20a5e4061fe))
* read oil diagnostics before restoring; bound fallback put-back wait ([8f1bf99](https://github.com/Stromdahl/oil-download.nvim/commit/8f1bf9995d768a7bc7a290654e8c3ae45cea4db3))
* report invalid config once and keep that option's default ([d5480d2](https://github.com/Stromdahl/oil-download.nvim/commit/d5480d2a8358b02b41005bf0ab7861ccf14acf7e))
* restore URLs into an empty oil directory without a blank line ([009645a](https://github.com/Stromdahl/oil-download.nvim/commit/009645ad2ac13b0d28b5915ce220c9de36809d62))
* setup() keeps a function-valued vim.g.oil_download live ([cfe6736](https://github.com/Stromdahl/oil-download.nvim/commit/cfe6736691debaa127ae5bf5fad2af43f84d6b62))
* setup() tolerates a config function returning a non-table ([8768342](https://github.com/Stromdahl/oil-download.nvim/commit/8768342680b82a8eb0d96acc5c4978ff78799358))
* survive plugin reloads and foreign wrappers of oil's dialog ([2bcb76a](https://github.com/Stromdahl/oil-download.nvim/commit/2bcb76abb5600aa7fcf4d67afa0b2d7b7bd8c050))
