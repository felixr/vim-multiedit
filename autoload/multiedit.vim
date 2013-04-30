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
    let sel = { 
        \ 'line': line, 
        \ 'col': startcol,
        \ 'len': endcol-startcol,
        \ 'suffix_length': col('$')-endcol
    \ }
    if !exists("b:regions")
        let b:regions = {}
        let b:first_region = sel
    endif

    if has_key(b:regions, line)
        " Check if this overlaps with any other region
        let overlapid = s:hasOverlap(sel)
        if overlapid == -1
            let b:regions[line] = b:regions[line] + [sel]
        else
            " If so, change this to the 'main' region
            let b:first_region = b:regions[line][overlapid]
            let new_first = 1
        endif
    else
        let b:regions[line] = [sel]
    endif

    " Highlight the region
    if exists("new_first")
        call s:rehighlight()
    else
        call s:highlight(line, startcol, endcol)
    endif

    " Exit visual mode
    normal! v
endfunc
" }}

" addMark() {{
func! multiedit#addMark(mode)
    let mark = g:multiedit_mark_character

    " Insert the marker character and select it
    let line = getline('.')
    let col = col('.')

    " Insert the markers, pre or post, depending on the mode
    let precol = a:mode ==# "i" ? 2 : 1
    let sufcol = a:mode ==# "i" ? 1 : 0

    let prefix = col > 1 ? line[0:col-precol] : ''
    let suffix = line[(col-sufcol):]
    call setline(line('.'), prefix.mark.suffix)
    if a:mode ==# "a"
        normal! l
    endif
    normal! v

    let line = line('.')
    if exists("b:regions") && has_key(b:regions, line)
        " Check for regions on the same line that follow this region and shift
        " them to the right.
        let col = col('.')
        for region in b:regions[line]
            let offset = strlen(mark)
            if region.col > col
                let region.col += offset
            else
                let region.suffix_length += offset
            endif
        endfor

        call s:rehighlight()
    endif

    " ...then make it a region
    call multiedit#addRegion()
endfunc
" }}

" start() {{
func! multiedit#start(bang, ...)
    if !exists("b:regions") 
        if g:multiedit_auto_restore == 0 || !multiedit#again()
            return
        endif
    endif

    let lastcol = b:first_region.col + b:first_region.len

    " If bang exists OR the first region is a marker, then clear it before
    " editing mode begins.
    if a:bang ==# '!'
        " Remove the word and update the highlights
        let linetext = getline(b:first_region.line)
        if b:first_region.col == 1
            let newline = g:multiedit_mark_character . linetext[(lastcol - 1):]
        else
            let newline = linetext[0:(b:first_region.col - 2)] . g:multiedit_mark_character . linetext[(lastcol - 1):]
        endif

        call setline(b:first_region.line, newline)
        call multiedit#update(0)

        " Refresh the lastcol (update() likely changed things!)
        let lastcol = b:first_region.col + b:first_region.len
    endif

    " Move cursor to the end of the word
    call cursor(b:first_region.line, lastcol)

    " Set up some 'abort' mappings, because they can't be accounted for. They
    " will unmap themselves once they're pressed.
    call s:maps(0)

    " Start insert mode. Since there's no way to mimic 'a' with :normal, we
    " have to do it manually:
    if col('$') == lastcol
        startinsert!
    else
        startinsert
    endif
    
    " Where the magic happens
    augroup multiedit
        au!
        " Update the highlights as you edit
        au CursorMovedI * call multiedit#update(0)

        " Once you leave INSERT, apply changes and delete this augroup
        au InsertLeave * call multiedit#update(1) | call s:maps(0) | au! multiedit

        if g:multiedit_auto_reset == 1
            " Clear all regions once you exit insert mode
            au InsertLeave * call multiedit#reset()
        endif
    augroup END
endfunc
" }}

" reset() {{
func! multiedit#reset(...)
    if exists("b:regions_last")
        unlet b:regions_last
    endif
    if exists("b:regions")
        if a:0 == 0
            let b:regions_last = {}
            let b:regions_last["regions"] = b:regions
            let b:regions_last["first"] = b:first_region
        endif

        unlet b:first_region
        unlet b:regions
    endif

    syn clear MultieditRegions
    syn clear MultieditFirstRegion

    call s:maps(1)
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
        let sel = {"col": col('v'), "len": 1, "line":line('.')}
    endif

    if !has_key(b:regions, sel.line)
        return
    endif

    " Iterate through all regions on this line
    let i = 0
    for region in b:regions[sel.line]
        " Does this cursor overlap with this region? If so, delete it.
        if s:isOverlapping(sel, region)

            " If you're deleting a main region, we need to pass on the role to
            " another region first!
            if region == b:first_region
                unlet b:first_region

                " Get the last specified region
                let keys = keys(b:regions)
                if len(keys)
                    let b:first_region = b:regions[keys(b:regions)[-1]][-1]
                endif
            endif

            unlet b:regions[sel.line][i]
        endif
        let i += 1
    endfor

    " The regions have changed. Update the highlights.
    call s:rehighlight()
endfunc
" }}

" update() {{
" Update highlights when changes are made
func! multiedit#update(change_mode)
    if !exists('b:regions')
        return
    endif

    " Column offset from start of main edit region to cursor (relevant when
    " restoring cursor location post-edit)
    let col = col('.')
    let cursor_col = col-b:first_region.col

    " Clear highlights so we can make changes
    syn clear MultieditRegions
    syn clear MultieditFirstRegion
    
    " Prepare the new, altered line
    let linetext = getline(b:first_region.line)
    let lineendlen = (len(linetext) - b:first_region.suffix_length)
    if lineendlen == 0
        let newtext = ""
    else
        let newtext = linetext[(b:first_region.col-1): (lineendlen-1)]
    endif

    " Iterate through the lines where regions exist. And sort them by
    " sequence.
    for line in sort(keys(b:regions))
        let regions = copy(b:regions[line])
        let regions = sort(regions, "s:entrySort")
        let s:offset = 0

        " Iterate through each region on this line
        for region in regions
            if a:change_mode

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

                if col >= b:first_region.col
                    let s:offset = s:offset + len(newtext) - region.len
                endif
                let region.len = len(newtext)

            else

                if region.line == b:first_region.line

                    " ...move the highlight offset of regions after it
                    if region.col >= b:first_region.col
                        let region.col += s:offset 
                        let s:offset = s:offset + len(newtext) - b:first_region.len
                    endif

                    " ...and update the length of the first_region.
                    " Remember, we're only affecting the main region and
                    " regions following it, on the same line
                    if region.col == b:first_region.col
                        if newtext ==# ""
                            if col < b:first_region.col
                                call multiedit#reset(1)
                                return
                            endif

                            " If newtext is blank, just make the len 0 (for
                            " now) otherwise it'll go crazy!
                            let region.len = 0
                        else
                            let region.len = len(newtext)
                        endif
                    endif

                endif

                " Rehighlight the lines
                call s:highlight(region.line, region.col, region.col+region.len)

            endif
        endfor
    endfor

    " Remeasure the strlen
    let b:first_region.suffix_length = col([b:first_region.line, '$']) - b:first_region.col - b:first_region.len
    
    " Restore cursor location
    call cursor(b:first_region.line, b:first_region.col + cursor_col)

endfunc
" }}

" again() {{
" Restore last region selections. Returns 1 on success, 0 on failure.
func! multiedit#again()
    if !exists("b:regions_last")
        echom "No regions to restore!"
        return
    endif

    let b:first_region = b:regions_last["first"]
    let b:regions = b:regions_last["regions"]

    call s:rehighlight()
    return 1
endfunc
" }}

" jump() {{
" Hop [-/+]N regions
func! multiedit#jump(n)
    let n = str2nr(a:n)
    if !exists("b:regions")
        echom "There are no regions to jump to."
        return
    elseif n == 0
        " n == 0 goes nowhere!
        return
    endif

    " This is the starting point of the search.
    let col = col('.')
    let line = line('.')

    " Sort the lines so that we can sequentially access them. If the jump is
    " going backwards, reverse the resulting keys.
    let region_keys = sort(keys(b:regions))
    if n < 0
        call reverse(region_keys)
    endif

    let i = 0
    for l in region_keys
        " Skip over irrelevant lines (before/after the start point, depending
        " on the jump direction)
        if (n>0 && l<line) || (n<0 && l>line)
            continue
        endif

        let regions = sort(copy(b:regions[l]), 's:entrySort')
        if n < 0
            call reverse(regions)
        endif

        for region in regions
            " If this is the line we're on, skip irrelevant regions
            " (before/after the start point, depending on jump direction)
            if l == line
                if ((n>0) && (region.col<=col)) || ((n<0) && (region.col>=col))
                    continue
                endif
            endif

            " Skip over n-1 matches, then move the cursor on the nth match
            let i += a:n > 0 ? 1 : -1
            if n == i
                call cursor(l, region.col)
                return 1
            endif
        endfor
    endfor

    echom "No more regions!"
    return
endfunc
" }}

""""""""""""""""""""""""""
" isOverlapping(selA, selB) {{
" Checks to see if selA overlaps with selB
func! s:isOverlapping(selA, selB)
    " Check for invalid input
    if type(a:selA) != 4 || type(a:selB) != 4
        return
    endif

    " If they're not on the same line, don't even try.
    if a:selA.line != a:selB.line
        return
    endif

    " Check for overlapping
    let selAend = a:selA.col + (a:selA.len - 1)
    let selBend = a:selB.col + (a:selB.len - 1)
    return a:selA.col == a:selB.col || selAend == selBend 
                \ || a:selA.col == selBend || selAend == a:selB.col
                \ || (a:selA.col > a:selB.col && a:selA.col < selBend)
                \ || (selAend < selBend && selAend > a:selB.col)
endfunc
" }}

" hasOverlap(sel) {{
" Checks to see if any other regions overlap with this one. Returns -1 if not,
" and the id of it otherwise (e.g. b:regions[line][id])
func! s:hasOverlap(sel)
    if type(a:sel) != 4 || !has_key(b:regions, a:sel.line)
        return -1
    endif

    for i in range(len(b:regions[a:sel.line]))
        if s:isOverlapping(a:sel, b:regions[a:sel.line][i])
            return i
        endif
    endfor
    return -1
endfunc
" }}

" highlight(line, start, end) {{
func! s:highlight(line, start, end)
    if a:start > a:end || a:end < a:start
        return
    endif
    if !exists("b:first_region") || (b:first_region.line == a:line && b:first_region.col == a:start)
        let synid = "MultieditFirstRegion"
    else
        let synid = "MultieditRegions"
    endif
    execute "syn match ".synid." '\\%".a:line."l\\%".a:start."c\\_.*\\%".a:line."l\\%".a:end."c' containedin=ALL"
endfunc
" }}

" rehighlight() {{
func! s:rehighlight()
    syn clear MultieditRegions
    syn clear MultieditFirstRegion

    " Go through regions and rehighlight them
    for line in keys(b:regions)
        for sel in b:regions[line]
            call s:highlight(line, sel.col, sel.col + sel.len)
        endfor
    endfor
endfunc
" }}

" map() {{
func! s:maps(unmap)
    if a:unmap
        silent! iunmap <buffer><silent> <CR>
        silent! iunmap <buffer><silent> <Up>
        silent! iunmap <buffer><silent> <Down>
    else
        inoremap <buffer><silent> <CR> <Esc><CR>:call s:maps(1)<CR>
        inoremap <buffer><silent> <Up> <Esc><Up>:call s:maps(1)<CR>
        inoremap <buffer><silent> <Down> <Esc><Down>:call s:maps(1)<CR>
    endif
endfunc
" }}

" entrySort() {{
func! s:entrySort(a, b)
    return a:a.col == a:b.col ? 0 : a:a.col > a:b.col ? 1 : -1
endfunc
" }}

" vim: set foldmarker={{,}} foldlevel=0 foldmethod=marker
