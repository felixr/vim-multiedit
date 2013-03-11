" *multiedit.txt* Multi-editing for Vim   

" addRegion() {{
func! multiedit#addRegion()
    if mode() != 'v'
        normal! gv
    endif

    " Get region parameters
    let line = line('.')
    let startcol = col('v')
    let endcol = col('.')+1

    " add selection to list
    let sel = {'line': line, 'col': startcol, 'end': endcol, 'len': endcol-startcol, 'suffix_length': col('$')-endcol}
    if !exists("b:regions")
        let b:regions = {}
        let b:first_region = sel
    endif

    if has_key(b:regions, line)
        if multiedit#hasOverlap(sel) == -1
            let b:regions[line] = b:regions[line] + [sel]
        endif
    else
        let b:regions[line] = [sel]
    endif

    " Highlight the region
    call multiedit#highlight(line, startcol, endcol)

    " Exit visual mode
    normal! v
endfunc
" }}

" addMark() {{
func! multiedit#addMark(mode)
    let mark = g:multiedit_mark_character

    " Insert the marker character and select it
    exe "normal! ".a:mode.g:multiedit_mark_character."v"

    let line = line('.')
    if exists("b:regions") && has_key(b:regions, line)
        " Check for regions on the same line that follow this region and shift
        " them to the right.
        let col = col('.')
        for region in b:regions[line]
            let offset = strlen(g:multiedit_mark_character)
            if region.col > col
                let region.col += offset
                let region.end += offset
            else
                let region.suffix_length += offset
            endif
        endfor

        call multiedit#rehighlight()
    endif

    " ...then make it a region
    call multiedit#addRegion()
endfunc
" }}

" addMatch(direction) {{
func! multiedit#addMatch(direction)
    if index(['?', '/'], a:direction) == -1
        return
    endif

    " Enter visual mode and select the word
    normal! viw
    call multiedit#addRegion()

    let word = escape(expand("<cword>"), a:direction)
    let wordlen = strlen(word)

    " Jump to next instance of the word
    exe "normal! ".a:direction."\\V".word.""
    if a:direction == "?"
        normal! n
    endif
endfunc
" }}

" set() {{
" Set the region under the cursor to be the new first_region
func! multiedit#set()
    if !exists("b:regions")
        return
    endif

    let sel = {"col": col('v'), "end": col('.'), "line":line('.')}

    for region in b:regions[sel.line]
        if multiedit#isOverlapping(sel, region)
            let b:first_region = region
        endif
    endfor

    call multiedit#rehighlight()
endfunc
" }}

" edit() {{
func! multiedit#edit(bang, ...)
    if !exists("b:regions")
        return
    endif

    let lastcol = b:first_region.col + b:first_region.len

    " If bang exists, clear the word (and replace it with a marker) before you
    " start editing
    if a:bang ==# '!'
        " Select the word
        call cursor(b:first_region.line, b:first_region.col)
        normal! v
        call cursor(b:first_region.line, lastcol-1)

        " Delete it, add the marker, and move the cursor ahead of it
        normal! d
        call multiedit#update(0)
        call cursor(b:first_region.line, b:first_region.col)

        " Refresh the lastcol (it's likely moved!)
        let lastcol = b:first_region.col + b:first_region.len
    else
        " Move cursor to the end of the word
        call cursor(b:first_region.line, lastcol)
    endif

    " Set up some 'abort' mappings, because they can't be accounted for. They
    " will unmap themselves once they're pressed.
    call multiedit#maps(0)

    " Start insert mode. Since there's no way to mimic 'a' with :normal, we
    " have to do it manually:
    if col('$') == lastcol
        startinsert!
    else
        startinsert
    endif
    
    augroup multiedit
        au!
        " Update the highlights as you edit
        au CursorMovedI * call multiedit#update(0)

        " Once you leave INSERT, apply changes and delete this augroup
        au InsertLeave * 
                    \ call multiedit#update(1) |
                    \ call multiedit#maps(1) |
                    \ au! multiedit

        if g:multiedit_auto_reset == 1
            " Clear all regions once you exit insert mode
            au InsertLeave * call multiedit#reset()
        endif
    augroup END
endfunc
" }}

" reset() {{
func! multiedit#reset()
    if exists("b:regions")
        unlet b:regions
    endif
    if exists("b:first_region")
        unlet b:first_region
    endif

    syn clear MultieditRegions
    syn clear MultieditFirstRegion

    silent! au! multiedit
endfunc
" }}

" clear() {{
func! multiedit#clear(...)
    if !exists("b:regions")
        return
    endif
    
    " The region to delete might have been provided as an argument.
    if a:0 == 1 && type(a:1) == 4
        let sel = a:1
    else
        let sel = {"col": col('v'), "end": col('.'), "line":line('.')}
    endif

    if !has_key(b:regions, sel.line)
        return
    endif

    " Iterate through all regions on this line
    let i = 0
    for region in b:regions[sel.line]
        " Does this cursor overlap with this region? If so, delete it.
        if multiedit#isOverlapping(sel, region)

            if region == b:first_region
                unlet b:first_region
                if len(b:regions[sel.line]) > 1
                    let b:first_region = b:regions[sel.line][-1]
                endif
            endif

            unlet b:regions[sel.line][i]
        endif
        let i += 1
    endfor

    " The regions have changed. Update the highlights.
    call multiedit#rehighlight()
endfunc
" }}

" update() {{
func! multiedit#update(change)
    if !exists('b:regions')
        return
    endif

    " Save cursor position
    let b:save_cursor = getpos('.')

    " Clear highlights so we can make changes and redo them later
    syn clear MultieditRegions
    syn clear MultieditFirstRegion

    " Prepare the new, altered line
    let linetext = getline(b:first_region.line)
    let linelen = len(linetext)
    let newtext = linetext[(b:first_region.col-1): (linelen-b:first_region.suffix_length-1)]

    " Iterate through the lines where regions exist. And sort them by
    " sequence.
    for line in sort(keys(b:regions))
        let regions = copy(b:regions[line])
        let regions = sort(regions, "multiedit#entrySort")
        let s:offset = 0

        " Iterate through each region on this line
        for region in regions

            " Is it time to commit the changes?
            if a:change 

                let region.col += s:offset 
                if region.line != b:first_region.line || region.col != b:first_region.col
                    
                    " Get the old line
                    let oldline = getline(region.line)

                    " ...and assemble a new one
                    let prefix = ''
                    if region.col > 1
                        let prefix = oldline[0:region.col-2]
                    endif
                    let suffix = oldline[(region.col+region.len-1):]

                    " Update the line
                    call setline(region.line, prefix.newtext.suffix) 
                endif

                let s:offset = s:offset + len(newtext) - region.len
                let region.len = len(newtext)

            else

                " Resize the highlight of first_region as it changes
                if region.line == b:first_region.line

                    " ...move the highlight offset of regions after it
                    if region.col >= b:first_region.col
                        let region.col += s:offset 
                        let s:offset = s:offset + len(newtext) - b:first_region.len
                    endif
                    
                    " ...and update the length of the first_region
                    if region.col == b:first_region.col
                        let region.len = len(newtext)
                    endif

                endif

                " Rehighlight it
                call multiedit#highlight(region.line, region.col, region.col+region.len)

            endif

        endfor
    endfor

    " Remeasure the strlen from first_region.end to $
    let b:first_region.suffix_length = col([b:first_region.line, '$']) - b:first_region.col - b:first_region.len

    " Restore cursor position
    call setpos('.', b:save_cursor)
endfunc
" }}

""""""""""""""""""""""""""(
" isOverlapping(selA, selB) {{
" Checks to see if selA overlaps with selB
func! multiedit#isOverlapping(selA, selB)
    " Check for invalid input
    if type(a:selA) != 4 || type(a:selB) != 4
        return
    endif

    " If they're not on the same line, don't even try.
    if a:selA.line != a:selB.line
        return
    endif

    return a:selA.col == a:selB.col || a:selA.end == a:selB.end 
                \ || a:selA.col == a:selB.end || a:selA.end == a:selB.col
                \ || (a:selA.col > a:selB.col && a:selA.col < a:selB.end)
                \ || (a:selA.end < a:selB.end && a:selA.end > a:selB.col)
endfunc
" }}

" hasOverlap(sel) {{
" Checks to see if any other regions overlap with this one. Returns -1 if not,
" and the id of it otherwise (e.g. b:regions[line][id])
func! multiedit#hasOverlap(sel)
    if type(a:sel) != 4 || !has_key(b:regions, a:sel.line)
        return -1
    endif

    for i in range(len(b:regions[a:sel.line]))
        if multiedit#isOverlapping(a:sel, b:regions[a:sel.line][i])
            return i
        endif
    endfor
    return -1
endfunc
" }}

" highlight(line, start, end) {{
func! multiedit#highlight(line, start, end)
    if !exists("b:first_region") || b:first_region.line == a:line && b:first_region.col == a:start
        let synid = "MultieditFirstRegion"
    else
        let synid = "MultieditRegions"
    endif
    execute "syn match ".synid." '\\%".a:line."l\\%".a:start."c\\_.*\\%".a:line."l\\%".a:end."c' containedin=ALL"
endfunc
" }}

" rehighlight() {{
func! multiedit#rehighlight()
    syn clear MultieditRegions
    syn clear MultieditFirstRegion

    " Go through regions and rehighlight them
    for line in keys(b:regions)
        for sel in b:regions[line]
            call multiedit#highlight(line, sel.col, sel.end)
        endfor
    endfor
endfunc
" }}

" unmap() {{
func! multiedit#maps(unmap)
    if a:unmap
        iunmap <buffer><silent> <CR>
        iunmap <buffer><silent> <Up>
        iunmap <buffer><silent> <Down>
    else
        inoremap <buffer><silent> <CR> <Esc><CR>:call multiedit#maps(1)<CR>
        inoremap <buffer><silent> <Up> <Esc><Up>:call multiedit#maps(1)<CR>
        inoremap <buffer><silent> <Down> <Esc><Down>:call multiedit#maps(1)<CR>
    endif
endfunc
" }}

" entrySort() {{
func! multiedit#entrySort(a, b)
    return a:a.col == a:b.col ? 0 : a:a.col > a:b.col ? 1 : -1
endfunc
" }}

" vim: set foldmarker={{,}} foldlevel=0 foldmethod=marker
