local h = require("helpers")

describe("saving an oil buffer with URL lines", function()
  local dir

  after_each(function() h.reset() end)

  before_each(function()
    h.boot()
    vim.g.oil_download = { downloader = h.recorder }
    dir = h.tmpdir()
    h.open(dir)
  end)

  it("lists the URLs as DOWNLOAD in oil's dialog and downloads them on Yes", function()
    vim.api.nvim_buf_set_lines(0, -1, -1, false, { "https://example.com/a.zip" })

    local dialog = h.write_and_answer("y")

    assert.are.equal("DOWNLOAD https://example.com/a.zip", dialog[1])
    assert.are.same({ "https://example.com/a.zip" }, h.wait_downloads(dir, 1))
  end)

  it("puts the URL lines back and downloads nothing on No", function()
    vim.api.nvim_buf_set_lines(0, -1, -1, false, { "https://example.com/a.zip" })

    h.write_and_answer("n")

    assert.are.same({}, h.wait_downloads(dir, 1, 500))
    assert.is_true(vim.tbl_contains(h.lines(), "https://example.com/a.zip"))
    assert.is_true(vim.bo.modified)
  end)

  it("puts the URL back without a stray blank line in an empty directory on No", function()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "https://example.com/a.zip" })

    h.write_and_answer("n")

    assert.are.same({ "https://example.com/a.zip" }, h.lines())
  end)

  it("shows oil's own actions alongside, and performs them on Yes", function()
    vim.api.nvim_buf_set_lines(0, -1, -1, false, { "https://example.com/a.zip", "newfile.txt" })

    local dialog = h.write_and_answer("y")

    assert.are.equal("DOWNLOAD https://example.com/a.zip", dialog[1])
    assert.matches("^CREATE .*newfile%.txt", dialog[2])
    assert.are.same({ "https://example.com/a.zip" }, h.wait_downloads(dir, 1))
    assert.are.same({ "newfile.txt" }, h.files(dir))
  end)

  it("downloads every URL when several are saved at once", function()
    vim.api.nvim_buf_set_lines(0, -1, -1, false, { "https://example.com/a", "http://example.com/b" })

    h.write_and_answer("y")

    local got = h.wait_downloads(dir, 2)
    table.sort(got)
    assert.are.same({ "http://example.com/b", "https://example.com/a" }, got)
  end)

  it("leaves saves without URLs to oil's normal dialog", function()
    vim.api.nvim_buf_set_lines(0, -1, -1, false, { "plain.txt" })

    local dialog = h.write_and_answer("y")

    assert.matches("^CREATE .*plain%.txt", dialog[1])
    assert.are.same({ "plain.txt" }, h.files(dir))
  end)

  it("downloads each URL into its own directory when several oil buffers are saved", function()
    vim.api.nvim_buf_set_lines(0, -1, -1, false, { "https://example.com/a" })
    local other = h.tmpdir()
    h.open(other, { keep = true })
    vim.api.nvim_buf_set_lines(0, -1, -1, false, { "https://example.com/b" })

    local dialog = h.write_and_answer("y")

    assert.is_true(vim.tbl_contains(dialog, "DOWNLOAD https://example.com/a"))
    assert.is_true(vim.tbl_contains(dialog, "DOWNLOAD https://example.com/b"))
    assert.are.same({ "https://example.com/a" }, h.wait_downloads(dir, 1))
    assert.are.same({ "https://example.com/b" }, h.wait_downloads(other, 1))
  end)

  it("puts the URL lines back when oil can't parse another line", function()
    vim.fn.writefile({}, dir .. "a.txt")
    vim.fn.writefile({}, dir .. "b.txt")
    h.open(dir)
    local entries = h.lines()
    -- renaming both entries to the same name is a parse error
    local dup = entries[1]:gsub("a%.txt$", "same.txt")
    local dup2 = entries[2]:gsub("b%.txt$", "same.txt")
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "https://example.com/a", dup, dup2 })

    vim.cmd("w")
    vim.wait(300)

    assert.are.same({ "https://example.com/a", dup, dup2 }, h.lines())
    local diags = vim.diagnostic.get(0)
    assert.are.equal(1, #diags)
    assert.is_true(vim.tbl_contains({ 1, 2 }, diags[1].lnum), "diagnostic on a renamed line, got " .. diags[1].lnum)
    assert.are.equal(diags[1].lnum + 1, vim.api.nvim_win_get_cursor(0)[1])
    assert.are.same({}, h.wait_downloads(dir, 1, 300))
  end)
end)
