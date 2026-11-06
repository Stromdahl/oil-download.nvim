local h = require("helpers")

describe("pressing p in an oil buffer", function()
  after_each(function() h.reset() end)

  before_each(function()
    h.boot()
    vim.g.oil_download = { downloader = h.recorder }
    local dir = h.tmpdir()
    vim.fn.writefile({}, dir .. "existing.txt")
    h.open(dir)
  end)

  local function press(keys)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "x", false)
  end

  it("puts a URL copied without a newline on its own line", function()
    vim.fn.setreg("a", "https://example.com/a.zip", "c")

    press('"ap')

    local lines = h.lines()
    assert.are.equal(2, #lines)
    assert.matches("existing%.txt$", lines[1])
    assert.are.equal("https://example.com/a.zip", lines[2])
  end)

  it("in an empty directory, replaces oil's blank line instead of leaving it", function()
    h.open(h.tmpdir())
    vim.fn.setreg("a", "https://example.com/a.zip", "c")

    press('"ap')

    assert.are.same({ "https://example.com/a.zip" }, h.lines())
  end)

  it("puts several URLs on one line each", function()
    vim.fn.setreg("a", "https://example.com/a\nhttps://example.com/b\n", "l")

    press('"ap')

    assert.are.same({ "https://example.com/a", "https://example.com/b" }, vim.list_slice(h.lines(), 2))
  end)

  it("pastes anything else normally", function()
    vim.fn.setreg("a", "notes.txt", "l")

    press('"ap')

    assert.are.same({ "notes.txt" }, vim.list_slice(h.lines(), 2))
  end)

  it("pastes a yanked oil entry line normally", function()
    press("yy")
    local yanked = vim.fn.getreg('"')
    assert.matches("existing%.txt", yanked)

    press("p")

    local lines = h.lines()
    assert.are.equal(2, #lines)
    assert.are.equal(lines[1], lines[2])
  end)

  it("leaves p alone when default_keymaps is false", function()
    vim.g.oil_download = { default_keymaps = false }
    h.open(h.tmpdir())

    assert.are_not.equal(1, vim.fn.maparg("p", "n", false, true).buffer)
  end)

  it("yields to a p the user mapped in oil's own keymaps", function()
    require("oil").setup({ keymaps = { p = { callback = function() vim.b.user_p = true end } } })
    h.open(h.tmpdir())

    press("p")

    assert.is_true(vim.b.user_p)
    require("oil").setup({ skip_confirm_for_simple_edits = false })
  end)
end)
