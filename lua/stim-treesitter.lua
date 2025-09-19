-- Stim Tree-sitter plugin (auto-generated)
local M = {}
local ts_utils = require('nvim-treesitter.ts_utils')
local ns_id = vim.api.nvim_create_namespace('stim_treesitter_highlights')

local function parse_measurements_ts(bufnr)
    local parser = vim.treesitter.get_parser(bufnr, 'stim')
    if not parser then return {} end
    local tree = parser:parse()[1]
    local root = tree:root()
    local measurements = {}
    local measurement_count = 0
    local query = vim.treesitter.query.parse('stim', [[(measurement_instruction) @measurement]])
    for id, node in query:captures(root, bufnr) do
        local start_row, start_col, end_row, end_col = node:range()
        local text = vim.api.nvim_buf_get_text(bufnr, start_row, start_col, end_row, end_col, {})[1]
        local target_count = 0
        for child in node:iter_children() do
            if child:type() == 'target' then target_count = target_count + 1 end
        end
        for i = 1, target_count do
            measurements[measurement_count] = {
                line = start_row + 1,
                node = node,
                text = text,
                index = measurement_count
            }
            measurement_count = measurement_count + 1
        end
    end
    return measurements
end

local function get_record_ref_at_cursor(bufnr)
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1] - 1
    local col = cursor[2]
    local parser = vim.treesitter.get_parser(bufnr, 'stim')
    if not parser then return nil end
    local tree = parser:parse()[1]
    local root = tree:root()
    local query = vim.treesitter.query.parse('stim', [[(record_ref) @ref (invalid_record_ref) @invalid_ref]])
    for id, node, metadata in query:iter_captures(root, bufnr) do
        local start_row, start_col, end_row, end_col = node:range()
        if row >= start_row and row <= end_row then
            if row > start_row or col >= start_col then
                if row < end_row or col < end_col then
                    local text = vim.api.nvim_buf_get_text(bufnr, start_row, start_col, end_row, end_col, {})[1]
                    local index = tonumber(text:match("rec%[([%-]?%d+)%]"))
                    local capture_name = query.captures[id]
                    local is_valid = capture_name == "ref"
                    return {node = node, index = index, row = start_row, start_col = start_col, end_col = end_col, is_valid = is_valid}
                end
            end
        end
    end
    return nil
end

local function resolve_measurement_index(rec_index, measurements_up_to_line)
    if rec_index >= 0 then return nil end
    return measurements_up_to_line + rec_index
end

function M.highlight_measurement()
    local bufnr = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
    local record_ref = get_record_ref_at_cursor(bufnr)
    if not record_ref then return end
    if not record_ref.is_valid then
        vim.api.nvim_buf_add_highlight(bufnr, ns_id, 'Error', record_ref.row, record_ref.start_col, record_ref.end_col)
        return
    end
    local measurements = parse_measurements_ts(bufnr)
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    local measurements_before = 0
    for idx, measurement in pairs(measurements) do
        if measurement.line <= cursor_line then measurements_before = measurements_before + 1 end
    end
    local target_index = resolve_measurement_index(record_ref.index, measurements_before)
    if target_index and target_index >= 0 then
        for idx, measurement in pairs(measurements) do
            if idx == target_index then
                local start_row, _, end_row, _ = measurement.node:range()
                vim.api.nvim_buf_add_highlight(bufnr, ns_id, 'StimMeasurementHighlight', start_row, 0, -1)
                break
            end
        end
    end
    vim.api.nvim_buf_add_highlight(bufnr, ns_id, 'StimRecordHighlight', record_ref.row, record_ref.start_col, record_ref.end_col)
end

function M.show_info()
    local bufnr = vim.api.nvim_get_current_buf()
    local record_ref = get_record_ref_at_cursor(bufnr)
    if not record_ref then return end
    if not record_ref.is_valid then
        vim.notify(string.format("Invalid record reference rec[%d]: positive indices are not valid in Stim", record_ref.index), vim.log.levels.ERROR)
        return
    end
    local measurements = parse_measurements_ts(bufnr)
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    local measurements_before = 0
    for idx, measurement in pairs(measurements) do
        if measurement.line <= cursor_line then measurements_before = measurements_before + 1 end
    end
    local target_index = resolve_measurement_index(record_ref.index, measurements_before)
    if target_index and target_index >= 0 then
        for idx, measurement in pairs(measurements) do
            if idx == target_index then
                vim.notify(string.format("rec[%d] → Measurement #%d at line %d: %s", record_ref.index, idx, measurement.line, measurement.text), vim.log.levels.INFO)
                return
            end
        end
    end
    vim.notify(string.format("rec[%d] points to a measurement that doesn't exist", record_ref.index), vim.log.levels.WARN)
end

function M.setup()
    vim.cmd([[
        highlight default StimMeasurementHighlight guibg=#3a5f3a ctermbg=22
        highlight default StimRecordHighlight guibg=#5f3a3a ctermbg=52
    ]])
    vim.api.nvim_create_augroup('StimTreesitter', { clear = true })
    vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
        group = 'StimTreesitter',
        pattern = '*.stim',
        callback = function()
            local ok = pcall(vim.treesitter.get_parser, 0, 'stim')
            if ok then M.highlight_measurement() end
        end
    })
    vim.api.nvim_create_user_command('StimInfoTS', M.show_info, {})
end

return M
