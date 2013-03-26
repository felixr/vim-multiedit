# vim-multiedit - Multi-selection and editing in vim

## About

Do you envy Sublime Text 2's multiple selection and editing feature? This plugin
tries to fill that multi-caret shaped gap in your heart by letting you
specify "regions" of text and edit them all from one place.

*(This plugin is based on https://github.com/felixr/vim-multiedit by Felix
Riedel <felix.riedel at gmail.com>)*

## Usage

    " Insert a disposable marker after the cursor
    nmap <leader>ma :MultieditAddMark a<CR>

    " Insert a disposable marker before the cursor
    nmap <leader>mi :MultieditAddMark i<CR>

    " Make a new line and insert a marker
    nmap <leader>mo o<Esc>:MultieditAddMark i<CR>
    nmap <leader>mO O<Esc>:MultieditAddMark i<CR>

    " Insert a marker at the end/start of a line
    nmap <leader>mA $:MultieditAddMark a<CR>
    nmap <leader>mI ^:MultieditAddMark i<CR>

    " Make the current selection/word an edit region
    vmap <leader>m :MultieditAddRegion<CR>  
    nmap <leader>mm viw:MultieditAddRegion<CR>

    " Restore the regions from a previous edit session
    nmap <leader>mu :MultieditRestore<CR>

    " Move cursor between regions n times
    map ]m :MultieditHop 1<CR>
    map [m :MultieditHop -1<CR>

    " Start editing!
    nmap <leader>M :Multiedit<CR>

    " Clear the word and start editing
    nmap <leader>C :Multiedit!<CR>

    " Unset the region under the cursor
    nmap <silent> <leader>md :MultieditClear<CR>

    " Unset all regions
    nmap <silent> <leader>mr :MultieditReset<CR>
