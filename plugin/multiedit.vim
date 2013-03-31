" *multiedit.txt* Multi-editing for Vim   
" 
" Version: 0.2.0
" Author : Felix Riedel <felix.riedel at gmail.com> 
" License: MIT license  {{{
"     Permission is hereby granted, free of charge, to any person obtaining
"     a copy of this software and associated documentation files (the
"     "Software"), to deal in the Software without restriction, including
"     without limitation the rights to use, copy, modify, merge, publish,
"     distribute, sublicense, and/or sell copies of the Software, and to
"     permit persons to whom the Software is furnished to do so, subject to
"     the following conditions:
"     The above copyright notice and this permission notice shall be included
"     in all copies or substantial portions of the Software.
" 
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}

hi default MultiSelections gui=reverse term=reverse cterm=reverse

map <silent> <Plug>(multiedit-add) :<C-U>call multiedit#addSelection()<CR>
map <silent> <Plug>(multiedit-edit) :<C-U>call multiedit#startEdit()<CR>
map <silent> <Plug>(multiedit-reset) :<C-U>call multiedit#reset()<CR>

if !exists('g:multiedit_nomappings') || g:multiedit_nomappings == 0
    " add currently selected region to multiedit
    map ,a <Plug>(multiedit-add) 
    " add a space and mark it as multiedit region
    map ,s I<Space><Esc>v<Plug>(multiedit-add)
    " mark word as multiedit region 
    map ,w viw<Plug>(multiedit-add)b
    " start editing multiedit regions 
    map ,i <Plug>(multiedit-edit)i
    " reset/clear multiedit regions
    map ,q <Plug>(multiedit-reset)
endif 
