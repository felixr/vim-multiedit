" *multiedit.txt* Multi-editing for Vim   
" 
" Version: 1.1.3
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


" Settings {{
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
" }}

" Color highlights {{
hi default MultieditRegions gui=reverse term=reverse cterm=reverse
" hi default MultieditFirstRegion gui=reverse term=reverse cterm=reverse
hi default link MultieditFirstRegion IncSearch
" }}

" Mappings {{
com! -bar -range MultieditAddRegion call multiedit#addRegion()
com! -bar MultieditPrependMark call multiedit#addMark('i')
com! -bar MultieditAppendMark call multiedit#addMark('a')

" Start edit mode!
com! -bar -bang Multiedit call multiedit#edit(<q-bang>)
" Set a new region as the edit region
com! -bar MultieditSet call multiedit#set()

" Clear region/marker under the cursor
com! -bar -range MultieditClear call multiedit#clear()
" Clear all regions and markers
com! -bar MultieditReset call multiedit#reset()

" Load previous regions, if available
com! -bar MultieditRestore call multiedit#again()

if g:multiedit_no_mappings != 1
    " Markers
    nmap <leader>ma :MultieditAppendMark<CR>
    nmap <leader>mi :MultieditPrependMark<CR>

    " Regions
    vmap <leader>mm :MultieditAddRegion<CR>  
    nmap <leader>mm viw:MultieditAddRegion<CR>
    nmap <leader>ms :MultieditSet<CR>
    nmap <leader>mu :MultieditRestore<CR>
    
    " Matches
    nmap <leader>mn viw:MultieditAddRegion<CR>/<C-r>=expand("<cword>")<CR><CR>
    nmap <leader>mp viw:MultieditAddRegion<CR>?<C-r>=expand("<cword>")<CR><CR>

    " Edit modes
    nmap <leader>M :Multiedit<CR>
    nmap <leader>C :Multiedit!<CR>

    " Resetting
    nmap <silent> <leader>md :MultieditClear<CR>
    nmap <silent> <leader>mr :MultieditReset<CR>
endif 
" }}

" vim: set foldmarker={{,}} foldlevel=0 foldmethod=marker
