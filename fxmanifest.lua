fx_version 'cerulean'
game 'gta5'

name 'fearx-multijob'
author 'fearx'
version '1.0.0'
description 'Multi-job system with NUI for ESX'

ui_page 'html/index.html'

files {
  'html/index.html',
  'html/script.js',
  'html/style.css'
}

shared_scripts {
  'config.lua'
}

client_scripts {
  'client.lua'
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server.lua'
}
