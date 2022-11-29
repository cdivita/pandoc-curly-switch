PANDOC_VERSION:must_be_at_least(
    "2.17",
    "At least pandoc %s is required (current: %s), since pandoc.utils.type() is used"
)

-- The pattern for curly variables
local curly_variables = "${([%w-%.]+)}"

-- The pattern for exclamation mark variables
local exclamation_variables = "!([%w-%.]+)!"

-- The document variables
local vars = {}

---Expand Inlines to its value or to its expression (that can contains variables)
---- `context`: the table (usually the document metadata) to use for looking up variables values 
---- `inlines`: the Inlines element to expand
---- `no_expansion`: the callback function to invoke when an expression variable cannot be resolved
---
---@param context table
---@param inlines pandoc.Inlines
---@param no_expansion function
---@return any
function expand_inlines(context, inlines, no_expansion)

    local expanded = pandoc.Inlines(inlines)
    for index, inline in ipairs({table.unpack(expanded)}) do

        local expression = pandoc.utils.stringify(inline)
        for variable in string.gmatch(expression, curly_variables) do

            local node = context
            for segment in string.gmatch(variable, "([%w-]+)") do

                if node then
                    node = node[segment]
                else
                    -- The referenced node does not exist, exit from the loop
                    break
                end
            end

            if node or type(node) == "boolean" then
                expanded[index] = node
            else

                -- Invoke the callback about expansion status, if any
                if no_expansion then
                    no_expansion(expression)
                end
            end
        end
    end

    return expanded
end

---Initializes the variables from document metadata
---- `meta`: the metadata root
---- `current`: the current metadata node
---- `prefix`: the context associated to the current metadata node
---- `variables`: the variables
---
---@param meta table
---@param current table
---@param prefix table
---@param variables table
function load_variables(meta, current, prefix, variables)

    prefix = prefix or ""
    variables = variables or {}

    if not current then
        current = meta
    end

    for k, v in pairs(current) do

        local name = prefix .. k
        if type(v) == "table" then

            if pandoc.utils.type(v) == "Inlines" then

                local value = expand_inlines(
                    meta,
                    v,
                    function (expression)
                        --io.stderr:write(string.format("Variable %s cannot be resolved (expression: %s)\n", name, expression))
                    end
                )

                variables[name] = value
            else
                variables = load_variables(meta, v, name .. ".", variables)
            end
        -- A workaround for supporting other values (that are not handled as tables by Pandoc)
        elseif type(v) == "boolean" or type(v) == "string" then
            variables[name] = v
        end
    end

    return variables
end

---Loads the document variables
---@param meta pandoc.Meta
---@return table
function process_metadata(meta)

    vars = load_variables(meta)

    -- Replaces the variables within the metadata
    replace_metadata_placeholders(meta, nil)

    return meta
end

---Replaces variables placeholders within LaTeX blocks
---@param r pandoc.RawBlock
---@return pandoc.RawBlock|nil
function replace_latex_placeholders(r)

    if r.format == "tex" then

        return replace_variables(vars, r.text, function(text) return pandoc.RawBlock(r.format, text) end)
    end

    -- If nil is returned, the element is left unchanged
end

---Replaces the variables placeholders within a header, also updating the identifier accordingly
---@param el pandoc.Header
---@return pandoc.Header
function replace_header_placeholders(el)

    return replace_variables(vars, pandoc.utils.stringify(el.content), function(text)

        el.identifier = string.lower(string.gsub(string.gsub(text, "%s", "-"), "[^-%w]", ""))
        el.content = pandoc.Span(text)

        return el
    end)

    -- If nil is returned, the element is left unchanged
end

---Replaces the variables placeholders within a link target
---@param el pandoc.Link
---@return pandoc.Link
function replace_link_target_placeholders(el)

    return replace_variables(vars, pandoc.utils.stringify(url_decode(el.target)), function(text)

        -- If link target is an anchor, let be sure it's lowercase
        if string.find(text, "#", 1, true) == 1 then
            text = string.lower(text)
        end

        return pandoc.Link(el.content, text, el.title, el.attr)
    end)

    -- If nil is returned, the element is left unchanged
end

---Replaces the variables placeholders within markdown elements
---@param el pandoc.Str
---@return pandoc.Span
function replace_markdown_placeholders(el)

    return replace_variables(vars, el.text, function(text) return pandoc.Span(text) end)

    -- If nil is returned, the element is left unchanged
end

---Replaces variables placeholders within metadata
---@param node pandoc.Meta
---@param prefix table
function replace_metadata_placeholders(node, prefix)

    prefix = prefix or ""

    for k, v in pairs(node) do

        if type(v) == "table" then

            local name = prefix .. k
            if pandoc.utils.type(v) == "Inlines" then

                local text = pandoc.utils.stringify(v)
                local value = replace_variables(vars, text, function (replaced) return to_meta_value(replaced) end)

                -- If no replacement is done, let's normalize the metadata value
                -- representation (mainly writing boolean values without quotes)
                if value == nil then
                    value = to_meta_value(text)
                else
                    -- Update the variable value, since the associated metadata referenced one or more variables
                    vars[name] = value
                end

                node[k] = value
            else
                -- Go on with replacement recursion
                replace_metadata_placeholders(v, name .. ".")
            end
        end
    end
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
function replace_variables(variables, text, callback)

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

    -- Look for ${...} variables pattern
    local resolved = resolve(text, curly_variables, callback)

    -- Be aware that a variable could have been resolved to a boolean
    if not resolved and type(resolved) ~= "boolean" then

        -- Look for !...! variables pattern
        resolved = resolve(text, exclamation_variables, callback)
    end

    return resolved
end

---Create a metadata element, based on its value type
---@param value any
---@return pandoc.MetaBool|pandoc.MetaString|nil
function to_meta_value(value)

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
function url_encode(value)

    value = string.gsub (value, "([^0-9a-zA-Z !'()*._~-])", function (c) return string.format ("%%%02X", string.byte(c)) end)
    value = string.gsub (value, " ", "+")

    return value
end

---Applies URL decoding to a value
---@param url string
function url_decode(value)

    value = string.gsub (value, "+", " ")
    value = string.gsub (value, "%%(%x%x)", function(h) return string.char(tonumber(h,16)) end)

    return value
end

return {
    {
        Meta = process_metadata
    },
    {
        Header = replace_header_placeholders,
        Link = replace_link_target_placeholders,
    },
    {
        RawBlock = replace_latex_placeholders,
        Str = replace_markdown_placeholders   
    }
}
