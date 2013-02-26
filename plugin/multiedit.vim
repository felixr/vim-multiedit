" *multiedit.txt* Multi-editing for Vim   
" 
" Version: 0.1.0
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

map <Plug>(multiedit-add) :<C-U>call multiedit#addSelection()<CR>
map <Plug>(multiedit-edit) :<C-U>call multiedit#startEdit()<CR>
map <Plug>(multiedit-reset) :<C-U>call multiedit#reset()<CR>

if !exists('g:multiedit_nomappings') || g:multiedit_nomappings == 0
    map ,a <Plug>(multiedit-add)
    map ,a viw<Plug>(multiedit-add)b
    map ,i <Plug>(multiedit-edit)i
    map ,q <Plug>(multiedit-reset)
endif 
