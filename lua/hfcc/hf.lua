local config = require("hfcc.config")
local fn = vim.fn
local json = vim.json
local utils = require("hfcc.utils")

local M = {}

local function build_inputs(before, after)
  local fim = config.get().fim
  local filename_prefix = "<filename>"
  if fim.enabled then
    return filename_prefix .. vim.fn.expand("%") .. "\n" .. fim.prefix .. before .. fim.suffix .. after .. fim.middle
  else
    return filename_prefix .. vim.fn.expand("%") .. "\n" .. before
  end
end

local next = next
local function extract_generation(data)
  local decoded_json = json.decode(data[1])
  if not decoded_json or next(decoded_json) == nil then
    vim.notify("[HFcc] error decoding response from API " .. data[1], vim.log.levels.ERROR)
    return ""
  end
  if decoded_json.error ~= nil then
    vim.notify("[HFcc] " .. decoded_json.error, vim.log.levels.ERROR)
    return ""
  end
  local raw_generated_text = decoded_json.generated_text
  return raw_generated_text
end

local function get_url()
  local model = config.get().model
  if utils.startswith(model, "http://") or utils.startswith(model, "https://") then
    return model
  else
    return "https://api-inference.huggingface.co/models/" .. model
  end
end

local function create_payload(request)
  local params = config.get().query_params
  local request_body = {
    inputs = build_inputs(request.before, request.after),
    parameters = {
      max_new_tokens = params.max_new_tokens,
      temperature = params.temperature,
      do_sample = params.temperature > 0,
      top_p = params.top_p,
      stop = { params.stop_token },
    }
  }
  local f = assert(io.open("/tmp/inputs.json", "w"))
  f:write(json.encode(request_body))
  f:close()
end

M.fetch_suggestion = function(request, callback)
  local query =
      'curl "' .. get_url() .. '" \z
      -H "Content-type: application/json" \z
      -d@/tmp/inputs.json'
  create_payload(request)
  local row, col = utils.get_cursor_pos()
  return fn.jobstart(query, {
    on_stdout = function(jobid, data, event)
      if data[1] ~= "" then
        callback(extract_generation(data), row, col)
      end
    end,
  })
end

return M
