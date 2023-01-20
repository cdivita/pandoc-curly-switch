PANDOC_VERSION:must_be_at_least(
    "2.17",
    "At least pandoc %s is required (current: %s), since pandoc.utils.type() is used"
)

-- The information about variables syntaxes
local variable_syntaxes = {

    {
        name = "curly",
        pattern = "${([%w-%.]+)}",
        format =  function(variable)
            return string.format("${%s}", variable)
        end
    },
    {
        name = "exclamation",
        pattern = "!([%w-%.]+)!",
        format =  function(variable)
            return string.format("!%s!", variable)
        end
    }
}

-- The document variables
local vars = {}

---Create a metadata element, based on its value type
---@param value any
---@return pandoc.MetaBool|pandoc.MetaString|nil
local function as_meta_value(value)

    if value == "true" then
        return pandoc.MetaBool(true)
    elseif value == "false" then
        return pandoc.MetaBool(false)
    elseif value ~= nil then
        return pandoc.MetaString(value)
    end

    return nil
end

---Applies URL encoding to a value
---@param url string
local function url_encode(value)

    value = string.gsub (value, "([^0-9a-zA-Z !'()*._~-])", function (c) return string.format ("%%%02X", string.byte(c)) end)
    value = string.gsub (value, " ", "+")

    return value
end

---Applies URL decoding to a value
---@param url string
local function url_decode(value)

    value = string.gsub (value, "+", " ")
    value = string.gsub (value, "%%(%x%x)", function(h) return string.char(tonumber(h,16)) end)

    return value
end

---Indicates if an expression contains a variable reference
---@param value string|pandoc.Inlines
---@return boolean
local function contains_variable(value)

    local expression
    if pandoc.utils.type(value) == "Inlines" then
        expression = pandoc.utils.stringify(value)
    else
        expression = value
    end

    local contains = false
    for _, syntax in ipairs(variable_syntaxes) do

        contains = contains or string.match(expression, syntax.pattern)

        -- If at least a syntax is matched, we can exit from the loop
        if (contains) then
            break
        end
    end

    return contains
end

---Replace the variables within a text with their values:
---- `variables` are the available variables for placehoders replacement
---- `text` the source text
---- `callback` is the callback function to execute if one or more variables have been replaced. The text with replaced variables is passed as function argument
---
---The callback function outcome is returned
---@param variables table
---@param text string
---@param callback function
---@return any
local function replace_variables(variables, text, callback)

    local resolve = function(text, pattern, callback)

        if (string.match(text, pattern)) then

            local replaced = string.gsub(text, pattern,
                function (v)

                    -- Maybe the variable is a boolean
                    if not variables[v] and type(variables[v]) ~= "boolean" then
                        io.stderr:write(string.format("Variable %s is not defined\n", v))
                    else
                        return pandoc.utils.stringify(variables[v])
                    end
                end
            )

            return callback(replaced)
        end
    end

    local resolved
    for _, syntax in ipairs(variable_syntaxes) do

         -- Look for the variables pattern
        resolved = resolve(text, syntax.pattern, callback)

        -- Be aware that a variable could have been resolved to a boolean
        if resolved or type(resolved) == "boolean" then
            break
        end
    end

    return resolved
end

---Expand an expression that containes variables placeholders
---@param source string
---@return string
---@return boolean
local function expand_expression(expression)

    local value = replace_variables(vars, url_decode(expression), function(text)
        return text
    end)

    if not value then
        return expression, false
    end

    return value, true
end

---Initializes the variables from document metadata
---- `meta`: the metadata root
---- `current`: the current metadata node
---- `prefix`: the context associated to the current metadata node
---- `variables`: the variables
---- `recursives`: the list of recursive variables (variables that reference other variables)
---
---@param meta table
---@param current table
---@param prefix table
---@param variables table
---@param recursives table
local function parse_variables(meta, current, prefix, variables, recursives)

    prefix = prefix or ""
    variables = variables or {}
    recursives = recursives or {}

    if not current then
        current = meta
    end

    for k, v in pairs(current) do

        local name = prefix .. k
        if type(v) == "table" then

            if pandoc.utils.type(v) == "Inlines" then

                variables[name] = v
                local expression = pandoc.utils.stringify(v)

                if contains_variable(expression) then

                    table.insert(recursives, name)
                    io.stderr:write(string.format("Variable %s may requires additional expansion (expression: %s)\n", name, expression))
                end

            else
                variables, recursives = parse_variables(meta, v, name .. ".", variables, recursives)
            end
        -- A workaround for supporting other values (that are not handled as tables by Pandoc)
        elseif type(v) == "boolean" or type(v) == "string" then
            variables[name] = v
        end
    end

    return variables, recursives
end

---Replaces variables placeholders within metadata
---- `variables`: the variables
---- `meta`: the metadata
---- `prefix`: the context associated to the current metadata node
---@param variables table
---@param node pandoc.Meta
---@param prefix string
local function refresh_metadata(variables, meta, prefix)

    prefix = prefix or ""
    variables = variables or {}

    for k, v in pairs(meta) do

        if type(v) == "table" then

            local name = prefix .. k
            if pandoc.utils.type(v) == "Inlines" then

                local text = pandoc.utils.stringify(v)
                local value = replace_variables(variables, text, function (replaced) return as_meta_value(replaced) end)

                -- If no replacement is done, let's normalize the metadata value
                -- representation (mainly writing boolean values without quotes)
                if value == nil then
                    value = as_meta_value(text)
                end

                meta[k] = value
            else
                -- Go on with replacement recursion
                refresh_metadata(variables, v, name .. ".")
            end
        end
    end
end

---Loads the document variables
---@param meta pandoc.Meta
---@return table
local function load_variables(meta)

    local variables, recursives = parse_variables(meta, nil, nil, nil, nil)

    local current_expansion = {}
    local next_expansion = recursives

    -- Let's expand variables with recursive expressions
    repeat

        current_expansion = next_expansion
        next_expansion = {}

        for _, name in ipairs(current_expansion) do

            local expression = pandoc.utils.stringify(variables[name])
            local value = replace_variables(variables, expression, function (replaced) return replaced end)
    
            -- Expansion has been made
            if value then
    
                variables[name] = value
    
                -- Iterate over the supported variable syntaxes
                for _, syntax in ipairs(variable_syntaxes) do

                    -- Looking for missing variables or variables that need further expansion
                    for unexpanded in string.gmatch(value, syntax.pattern) do
        
                        if not variables[unexpanded] then
                            io.stderr:write(string.format("Variable %s cannot be expanded (expression: %s)\n", name, expression))
                        else
                            table.insert(next_expansion, name)
                        end
                    end
                end
            end
        end
    until not next(next_expansion)

    return variables
end

---Loads the document variables
---@param meta pandoc.Meta
---@return table
local function process_metadata(meta)

    vars = load_variables(meta)

    -- Replaces the variables within the metadata
    return refresh_metadata(vars, meta, nil)
end

---Replaces variables placeholders within LaTeX blocks
---@param r pandoc.RawBlock
---@return pandoc.RawBlock|nil
local function replace_latex_placeholders(r)

    if r.format == "tex" then

        return replace_variables(vars, r.text, function(text) return pandoc.RawBlock(r.format, text) end)
    end

    -- If nil is returned, the element is left unchanged
end

---Replaces the variables placeholders within a header, also updating the identifier accordingly
---@param el pandoc.Header
---@return pandoc.Header
local function replace_header_placeholders(el)

    -- If header content contains variables, in order to preserve the
    -- formatting (if any) only the header identifier is updated.
    --
    -- The content will be updated by Str replacement
    return replace_variables(vars, pandoc.utils.stringify(el.content), function(text)

        el.identifier = string.lower(string.gsub(string.gsub(text, "%s", "-"), "[^-%w]", ""))

        return el
    end)

    -- If nil is returned, the element is left unchanged
end

---Replaces the variables placeholders within markdown elements
---@param el pandoc.Image
---@return pandoc.Image
local function replace_image_placeholders(el)

    -- Caption is not going to be expanded since it's an Inline,
    -- it will updated by Str replacement

    el.src = expand_expression(el.src)

    if el.title then
        el.title = expand_expression(el.title)
    end

    return el
end

---Replaces the variables placeholders within a link target
---@param el pandoc.Link
---@return pandoc.Link
local function replace_link_target_placeholders(el)

    local target = expand_expression(el.target)

    -- If link target is an anchor, let be sure it's lowercase
    if string.find(target, "#", 1, true) == 1 then
        target = string.lower(target)
    end

    el.target = target

    return el
end

---Replaces the variables placeholders within markdown elements
---@param el pandoc.Str
---@return pandoc.Span
local function replace_markdown_placeholders(el)

    -- If nil is returned, the element is left unchanged
    return replace_variables(vars, el.text, function(text) return pandoc.Span(text) end)
end

return {
    {
        Meta = process_metadata
    },
    {
        Header = replace_header_placeholders,
        Image = replace_image_placeholders,
        Link = replace_link_target_placeholders,
    },
    {
        RawBlock = replace_latex_placeholders,
        Str = replace_markdown_placeholders   
    }
}
