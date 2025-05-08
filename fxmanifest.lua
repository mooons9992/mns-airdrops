fx_version 'cerulean'
game 'gta5'

name 'mns-airdrops'
author 'Mooons'
version '1.0.1' -- Specify version in semantic format

description 'Simple airdrop script for QBCore/QBox'
repository 'https://github.com/mooons9992/mns-airdrops'

lua54 'yes'

shared_scripts {
  '@ox_lib/init.lua',
  'utils/*.lua',
  'config/*.lua'
}

client_scripts {
  'client/cl_*.lua',
}

server_scripts {
  'server/sv_version.lua', -- Add version checker first
  'server/sv_*.lua'
}

dependencies {
  'ox_lib',
  'qb-core'
}
