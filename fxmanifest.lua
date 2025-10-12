fx_version 'cerulean'
game 'gta5'
lua54 'yes'

shared_scripts {
  '@ox_lib/init.lua',
  'config.lua'
}

ui_page 'nui/index.html'

files {
  'nui/index.html',
  'nui/style.css',
  'nui/script.js',
  'nui/cac.png'
}


client_scripts {
  'client.lua',
  'client_transport.lua',
  'client_air_transport.lua',
  'aa.lua'
}

server_scripts {
  'server.lua',
  'server_transport.lua',
  'server_air_transport.lua'
}

escrow_ignore {
    'nui/*',
    'config.lua',
    'aa.lua'
}
