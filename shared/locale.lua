local strings = json.decode(LoadResourceFile(GetCurrentResourceName(), ('locales/%s.json'):format(Config.Locale or 'en')) or '{}') or {}
local fallback = Config.Locale ~= 'en' and (json.decode(LoadResourceFile(GetCurrentResourceName(), 'locales/en.json') or '{}') or {}) or {}

function L(key, ...)
    local s = strings[key] or fallback[key]
    if not s then return key end
    if select('#', ...) > 0 then return s:format(...) end
    return s
end

function LocaleGroup(prefix)
    local out = {}
    for key, value in pairs(fallback) do
        if key:sub(1, #prefix) == prefix then out[key] = value end
    end
    for key, value in pairs(strings) do
        if key:sub(1, #prefix) == prefix then out[key] = value end
    end
    return out
end
