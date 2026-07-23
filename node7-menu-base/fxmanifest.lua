fx_version 'cerulean'
game 'rdr3'

rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

author 'NODE7 DEVELOPMENT STUDIOS'
description 'NODE7 Menu Base - RedM nested NUI menu library for NODE7 resources'
version '1.0.0'

lua54 'yes'

ui_page 'html/ui.html'

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

files {
    'html/ui.html',
    'html/css/app.css',
    'html/js/app.js',
    'html/assets/node7-mark.svg'
}
