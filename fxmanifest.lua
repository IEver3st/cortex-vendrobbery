fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'Cortex Vending Robbery'
author 'GSDMODS/CORTEX'
description 'Break into Cortex Vending machines by hand: pick or pry the lock, strip the bill stacker, crack the cash box, empty the shelves'
version '1.0.0'

shared_scripts {
    '@cortex-lib/init.lua',
    'config.lua',
    'shared/locale.lua',
    'shared/validate.lua',
    'shared/anatomy.lua',
}

server_scripts {
    'server/vending.lua',
    'server/alert.lua',
    'server/rewards.lua',
    'server/machines.lua',
    'server/main.lua',
    'server/admin.lua',
}

client_scripts {
    '@cortex-lib/presentation-client.lua',
    'client/state.lua',
    'client/math.lua',
    'client/fx.lua',
    'client/world.lua',
    'client/camera.lua',
    'client/pointer.lua',
    'client/nui.lua',
    'client/tools.lua',
    'client/stages/pry.lua',
    'client/stages/pick.lua',
    'client/stages/open.lua',
    'client/session.lua',
    'client/main.lua',
    'client/settings.lua',
}

ui_page 'web/ui/dist/index.html'

files {
    'web/ui/dist/index.html',
    'web/ui/dist/assets/*',
    'locales/*.json',
}

dependencies { 'cortex-lib', 'cortex-vending', 'ox_inventory', '/onesync' }

escrow_ignore {
    'fxmanifest.lua',
    'config.lua',
    'locales/*.json',
    'install/*',
}
