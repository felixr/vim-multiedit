## About

Do you envy Sublime Text 2's multiple selection and editing? This plugin
tries to fill that text cursor shaped gap in your heart.

It works by adding selection "regions" and allowing you to edit them in sync,
and offers you a multitude of ways to select those regions.

*(This plugin is based on https://github.com/felixr/vim-multiedit by Felix
Riedel <felix.riedel at gmail.com>)*

## Usage

    <leader>mi      Add a disposable region before cursor
    <leader>ma      Add a disposable region after cursor
    <leader>mw      Add word under cursor as a region
    <leader>mm      Add current selection (or character) as a region
    <leader>M       Begin synchronized editing across all regions
    <leader>mr      Reset all regions
    <leader>md      Delete region under cursor
