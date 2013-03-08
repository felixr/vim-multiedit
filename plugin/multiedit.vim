" *multiedit.txt* Multi-editing for Vim   
" 
" Version: 1.0.0
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
" }}

" Color highlights {{
if !hlexists("MultieditRegions")
    hi default MultieditRegions gui=reverse term=reverse cterm=reverse
endif
if !hlexists("MultieditFirstRegion")
    " TODO: Change these colors
    hi default MultieditFirstRegion gui=reverse term=reverse cterm=reverse
endif
" }}

" Mappings {{
com! -bar -range MultieditAddRegion call multiedit#addRegion()
com! -bar MultieditPrependMark call multiedit#addMark('i')
com! -bar MultieditAppendMark call multiedit#addMark('a')

" Start edit mode!
com! -bar Multiedit call multiedit#edit()
" Clear region/marker under the cursor
com! -bar MultieditClear call multiedit#clear()
" Clear all regions and markers
com! -bar MultieditReset call multiedit#reset()

" TODO: Implement */#, like CMD-D in sublime text 2
" Mark <cword> as region, then jump to and mark the next instance
com! -bar -range MultieditNextMatch call multiedit#addMatch("/")

" Like ^ but previous
com! -bar -range MultieditPreviousMatch call multiedit#addMatch("?")

if g:multiedit_no_mappings != 1
    " Adding markers
    nmap <leader>ma :MultieditAppendMark<CR>
    nmap <leader>mi :MultieditPrependMark<CR>

    " Adding regions
    vmap <leader>mm :MultieditAddRegion<CR>  
    nmap <leader>mm v:MultieditAddRegion<CR>
    nmap <leader>mw viw:MultieditAddRegion<CR>

    " Add matches
    nmap <leader>mn :MultieditNextMatch<CR>
    nmap <leader>mp :MultieditPreviousMatch<CR>

    nmap <leader>M :Multiedit<CR>

    " Resetting
    map <silent> <leader>md :MultieditClear<CR>
    nmap <silent> <leader>mr :MultieditReset<CR>
endif 
" }}

" vim: set foldmarker={{,}} foldlevel=0 foldmethod=marker
