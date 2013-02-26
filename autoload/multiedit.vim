
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

function! multiedit#highlight(line, start, end)
    execute "syn match MultiSelections '\\%".a:line."l\\%".a:start."c\\_.*\\%".a:line."l\\%".a:end."c' containedin=ALL"
endfunction

function! multiedit#addSelection()

    " restore selection
    normal! gv

    " get selection parameters
    let lnum = line('.')
    let startcol = col('v')
    let endcol  = col('.')+1
    let line_end = col('$')

    " add selection to list
    let sel = { 'line': lnum, 'col': startcol, 'end': endcol, 'len': endcol - startcol, 'suffix_length': line_end - endcol }

    if !exists('b:selections')
        let b:selections = {}
        let b:first_selection = sel
    endif

    if has_key(b:selections, lnum)
        let b:selections[lnum] = b:selections[lnum] + [sel]
    else
        let b:selections[lnum] = [sel]
    endif

    call multiedit#highlight(lnum, startcol, endcol)

    "exit visual mode
    normal! v 
endfunction


function! multiedit#reset()

    if exists('b:selections')
        unlet b:selections
    endif
    if exists('b:first_selection')
        unlet b:first_selection
    endif
    syn clear MultiSelections
    au! multiedit 
endfunction


function! multiedit#startEdit()
    if !exists('b:selections')
        return
    endif
    call cursor(b:first_selection.line, (b:first_selection.col + b:first_selection.len))
    augroup multiedit 
        au!
        au CursorMovedI * call multiedit#updateSelections()
        " au InsertEnter * call multiedit#updateSelections(1)
        au InsertLeave * autocmd! multiedit
    augroup END
endfunction


function! multiedit#EntrySort(a,b)
    return a:a.col == a:b.col ? 0 : a:a.col > a:b.col ? 1 : -1
endfunction

function! multiedit#updateSelections()

    " Save cursor position
    let b:save_cursor = getpos('.')
    " let b:save_col = col(".")
    " let b:save_line = line(".")

    if !exists('b:selections')
        return
    endif

    syn clear MultiSelections

    let editline = getline(b:first_selection.line)
    let line_length = len(editline)
    let newtext = editline[ (b:first_selection.col-1): (line_length-b:first_selection.suffix_length-1)]


    for line in sort(keys(b:selections))
        let entries = b:selections[line]
        let entries = sort(entries, "multiedit#EntrySort")
        let s:offset = 0

        for entry in entries
            " skip the entry of the first selection
            if entry.line != b:first_selection.line || entry.col != b:first_selection.col 
                " selection is moved by offset if this is not
                " the first selection in the line
                let entry.col = entry.col + s:offset
                let oldline = getline(entry.line)
                let prefix = ''
                if entry.col > 1
                    let prefix = oldline[0:entry.col-2]
                endif
                let suffix = oldline[(entry.col+entry.len-1):]
        
                " update the line
                call setline(entry.line, prefix.newtext.suffix) 
            endif
            
            " update the offset for the next selection in this line
            let s:offset = s:offset + len(newtext) - entry.len 

            " update the length of the selection to fit the new content
            let entry.len = len(newtext)

            call multiedit#highlight(entry.line, entry.col, entry.col+entry.len)
        endfor
    endfor

    let b:first_selection.suffix_length = col([b:first_selection.line, '$']) - b:first_selection.col - b:first_selection.len

    " restore cursor position
    " call cursor(multiedit#save_line, multiedit#save_col) 
    call setpos('.', b:save_cursor)
endfunction
