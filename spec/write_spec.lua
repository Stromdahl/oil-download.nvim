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
end)
