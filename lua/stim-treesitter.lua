-- ~/.config/nvim/lua/stim-treesitter.lua
-- Tree-sitter based Stim Circuit Reader Plugin for Neovim
-- This version uses the correct Tree-sitter API

local M = {}
local ns_id = vim.api.nvim_create_namespace('stim_treesitter_highlights')

-- Parse measurements using Tree-sitter
local function parse_measurements_ts(bufnr)
    local parser = vim.treesitter.get_parser(bufnr, 'stim')
    if not parser then
        return {}
    end
    
    local tree = parser:parse()[1]
    if not tree then
        return {}
    end
    
    local root = tree:root()
    
    local measurements = {}
    local measurement_count = 0
    
    -- Query for measurement instructions
    local query_string = [[
        (measurement_instruction) @measurement
    ]]
    
    local ok, query = pcall(vim.treesitter.query.parse, 'stim', query_string)
    if not ok then
        return {}
    end
    
    for id, node in query:iter_captures(root, bufnr, 0, -1) do
        local start_row, start_col, end_row, end_col = node:range()
        local text = vim.api.nvim_buf_get_text(bufnr, start_row, start_col, end_row, end_col, {})
        text = text[1] or ""
        
        -- Count targets in this measurement
        local target_count = 0
        for child in node:iter_children() do
            if child:type() == 'target' then
                target_count = target_count + 1
            end
        end
        
        -- If no explicit targets found, assume at least one measurement
        if target_count == 0 then
            target_count = 1
        end
        
        -- Store each measurement target
        for i = 1, target_count do
            measurements[measurement_count] = {
                line = start_row + 1,  -- Convert to 1-indexed
                node = node,
                text = text,
                index = measurement_count
            }
            measurement_count = measurement_count + 1
        end
    end
    
    return measurements
end

-- Find record reference at cursor position
local function get_record_ref_at_cursor(bufnr)
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1] - 1  -- Convert to 0-indexed
    local col = cursor[2]
    
    local parser = vim.treesitter.get_parser(bufnr, 'stim')
    if not parser then
        return nil
    end
    
    local tree = parser:parse()[1]
    if not tree then
        return nil
    end
    
    local root = tree:root()
    
    -- Query for record references
    local query_string = [[
        (record_ref) @ref
    ]]
    
    local ok, query = pcall(vim.treesitter.query.parse, 'stim', query_string)
    if not ok then
        return nil
    end
    
    for id, node in query:iter_captures(root, bufnr, 0, -1) do
        local start_row, start_col, end_row, end_col = node:range()
        
        -- Check if cursor is within this node
        if row >= start_row and row <= end_row then
            if row > start_row or col >= start_col then
                if row < end_row or col < end_col then
                    -- Extract the index value
                    local text = vim.api.nvim_buf_get_text(bufnr, start_row, start_col, end_row, end_col, {})
                    text = text[1] or ""
                    local index = tonumber(text:match("rec%[([%-]?%d+)%]"))
                    
                    -- Check if it's valid (only negative indices are valid in Stim)
                    local is_valid = index and index < 0
                    
                    return {
                        node = node,
                        index = index,
                        row = start_row,
                        start_col = start_col,
                        end_col = end_col,
                        is_valid = is_valid
                    }
                end
            end
        end
    end
    
    return nil
end

-- Calculate which measurement a record reference points to
local function resolve_measurement_index(rec_index, measurements_up_to_line)
    -- In Stim, only negative indices are valid
    if not rec_index or rec_index >= 0 then
        return nil
    end
    
    -- rec[-1] is the most recent measurement
    return measurements_up_to_line + rec_index
end

-- Highlight measurement from record reference
function M.highlight_measurement()
    local bufnr = vim.api.nvim_get_current_buf()
    
    -- Clear previous highlights
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
    
    local record_ref = get_record_ref_at_cursor(bufnr)
    if not record_ref then
        return
    end
    
    if not record_ref.is_valid then
        -- Highlight invalid positive index as error
        vim.api.nvim_buf_add_highlight(bufnr, ns_id, 'Error',
            record_ref.row, record_ref.start_col, record_ref.end_col)
        return
    end
    
    -- Parse all measurements
    local measurements = parse_measurements_ts(bufnr)
    
    -- Count measurements up to the line with the record reference
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    local measurements_before = 0
    for idx, measurement in pairs(measurements) do
        if measurement.line <= cursor_line then
            measurements_before = measurements_before + 1
        end
    end
    
    -- Resolve the measurement index
    local target_index = resolve_measurement_index(record_ref.index, measurements_before)
    
    if target_index and target_index >= 0 then
        -- Find and highlight the corresponding measurement
        for idx, measurement in pairs(measurements) do
            if idx == target_index then
                local start_row, _, end_row, _ = measurement.node:range()
                vim.api.nvim_buf_add_highlight(bufnr, ns_id, 'StimMeasurementHighlight',
                    start_row, 0, -1)
                break
            end
        end
    end
    
    -- Highlight the record reference itself
    vim.api.nvim_buf_add_highlight(bufnr, ns_id, 'StimRecordHighlight',
        record_ref.row, record_ref.start_col, record_ref.end_col)
end

-- Show information about measurement at cursor
function M.show_info()
    local bufnr = vim.api.nvim_get_current_buf()
    local record_ref = get_record_ref_at_cursor(bufnr)
    
    if not record_ref then
        vim.notify("No record reference under cursor", vim.log.levels.INFO)
        return
    end
    
    if not record_ref.is_valid then
        vim.notify(string.format(
            "Invalid record reference rec[%d]: positive indices are not valid in Stim",
            record_ref.index or 0
        ), vim.log.levels.ERROR)
        return
    end
    
    local measurements = parse_measurements_ts(bufnr)
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    local measurements_before = 0
    
    for idx, measurement in pairs(measurements) do
        if measurement.line <= cursor_line then
            measurements_before = measurements_before + 1
        end
    end
    
    local target_index = resolve_measurement_index(record_ref.index, measurements_before)
    
    if target_index and target_index >= 0 then
        for idx, measurement in pairs(measurements) do
            if idx == target_index then
                vim.notify(string.format(
                    "rec[%d] → Measurement #%d at line %d: %s",
                    record_ref.index, idx, measurement.line, measurement.text
                ), vim.log.levels.INFO)
                return
            end
        end
    end
    
    vim.notify(string.format(
        "rec[%d] points to a measurement that doesn't exist (would be index %d)",
        record_ref.index, target_index or -1
    ), vim.log.levels.WARN)
end

-- Setup function
function M.setup()
    -- Define highlight groups
    vim.cmd([[
        highlight default StimMeasurementHighlight guibg=#3a5f3a ctermbg=22
        highlight default StimRecordHighlight guibg=#5f3a3a ctermbg=52
    ]])
    
    -- Setup autocmds for cursor movement
    local group = vim.api.nvim_create_augroup('StimTreesitter', { clear = true })
    
    vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
        group = group,
        pattern = '*.stim',
        callback = function()
            -- Check if buffer is valid
            local bufnr = vim.api.nvim_get_current_buf()
            if not vim.api.nvim_buf_is_valid(bufnr) then
                return
            end
            
            -- Only run if we have the stim parser
            local ok, parser = pcall(vim.treesitter.get_parser, bufnr, 'stim')
            if ok and parser then
                -- Wrap in pcall to prevent errors from breaking cursor movement
                pcall(M.highlight_measurement)
            end
        end
    })
    
    -- Create commands
    vim.api.nvim_create_user_command('StimInfoTS', M.show_info, {
        desc = 'Show information about the Stim measurement record under cursor'
    })
    
    vim.api.nvim_create_user_command('StimCheckParser', function()
        M.check_parser()
    end, {
        desc = 'Check if Stim Tree-sitter parser is installed'
    })
end

-- Function to check if Tree-sitter parser is available
function M.check_parser()
    local bufnr = vim.api.nvim_get_current_buf()
    local ok, parser = pcall(vim.treesitter.get_parser, bufnr, 'stim')
    
    if not ok then
        vim.notify([[
Tree-sitter parser for Stim not found!
Please install it first:
1. Build the grammar (see setup instructions)
2. Register it with nvim-treesitter
3. Run :TSInstall stim
        ]], vim.log.levels.WARN)
        return false
    end
    
    vim.notify("Stim Tree-sitter parser is installed and working!", vim.log.levels.INFO)
    return true
end

-- Export the get_record_ref_at_cursor function for external use
M.get_record_ref_at_cursor = get_record_ref_at_cursor

return M

