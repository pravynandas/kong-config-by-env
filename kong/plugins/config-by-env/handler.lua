local AppConfigHandler = {PRIORITY = 820}
local singletons = require "kong.singletons"
local config_by_env = require "kong.plugins.config-by-env.config"
local pl_utils = require "pl.utils"

function AppConfigHandler:access(conf)
    local config, err = config_by_env.get_config();
    if not config or err then
        return kong.response.exit("Error in fetching application config")
    end
    local service_url = config["services"][kong.router.get_service()["name"]]
    local host, port = pl_utils.splitv(service_url, ":")
    if not port then port = config["upstream_port"] end
    kong.log.debug("Upstream url::"..host..":"..port)

    kong.service.set_target(host, tonumber(port))
    kong.ctx.shared.upstream_host = host
end

function AppConfigHandler:init_worker()
    local worker_events = singletons.worker_events

    -- listen to all CRUD operations made on Consumers
    worker_events.register(function(data)
        kong.log.debug("Updated entitty:::" .. data["entity"]["name"])
        if data["entity"]["name"] == "config-by-env" then
            kong.log.notice("invalidating config-by-env-final")
            kong.core_cache:invalidate("config-by-env-final", false)
        end
    end, "crud", "plugins:update")
end

return AppConfigHandler
