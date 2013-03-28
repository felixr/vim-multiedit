" *multiedit.txt* Multi-editing for Vim   
" 
" Version: 2.0.2
" Author: Henrik Lissner <henrik at lissner.net>
" License: MIT license 
"
" Inspired by https://github.com/felixr/vim-multiedit, this plugin hopes to
" fill that multi-cursor-shaped gap in your heart that Sublime Text 2 left you
" with.

if exists('g:loaded_multiedit') || &cp
    finish
endif
let g:loaded_multiedit = 1


" Settings
if !exists('g:multiedit_no_mappings')
    let g:multiedit_no_mappings = 0
endif

if !exists('g:multiedit_auto_reset')
    let g:multiedit_auto_reset = 1
endif

if !exists('g:multiedit_mark_character')
    let g:multiedit_mark_character = '|'
endif

if !exists('g:multiedit_auto_restore')
    let g:multiedit_auto_restore = 1
endif


" Color highlights
hi default link MultieditRegions Search
hi default link MultieditFirstRegion IncSearch


" Mappings
com! -bar -range MultieditAddRegion call multiedit#addRegion()
com! -bar -nargs=1 MultieditAddMark call multiedit#addMark(<q-args>)
com! -bar -bang Multiedit call multiedit#start(<q-bang>)
com! -bar MultieditClear call multiedit#clear()
com! -bar MultieditReset call multiedit#reset()
com! -bar MultieditRestore call multiedit#again()
com! -bar -nargs=1 MultieditHop call multiedit#jump(<q-args>)

if g:multiedit_no_mappings != 1
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
endif 

" vim: set foldmarker={{,}} foldlevel=0 foldmethod=marker
