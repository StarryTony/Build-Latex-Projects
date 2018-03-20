# Build-Latex-Projects
This lightweight script helps to build complicated latex projects.

[![MIT licensed](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE.md)

## Introduction

A lightweight shell script supports compiling latex source files to a pdf document. Has been tested on `MacOS` and can work with `Linux` in theory (might need slight changes). Because I do coding with different languages and need a consistent editing & building environment without any distraction, I use this script with my text editor to write latex documents. Both generating pdf and comparing to historical can choose either live mode or not.

- [Why]
    - Use any preferred text editor;
    - Easily manage complicated latex projects;
    - Without losing any advanced features for building a latex project;
    - Use tools provided by the MacTex installation package and do not want to install any extra tool except MacTex;
    - Do not distract your writing;
    - Fast.

- [Features]
    - Maintain a global configuration and a local configuration for each project;
    - Remember historical operations;
    - Maintain version history;
    - Easily load a latex project;
    - Rename a latex project;
    - Choose latex engine & bibliography backend;
    - Choose encoding for *.tex
    - Count words directly from the output pdf document;
    - Support live preview;
    - Support comparing to historical versions <s>in live mode</s> (live mode is not completed yet);
    - Clean dump files and compress for commit;
    - Highlighted error & warn tips;
    - Foldable menu;
    - Customisable theme;
    - Quickly install missing packages using the `tlmgr` tool provided by the MacTex;
    - Can easily expand new functions / configurations.

## Screenshot
![live preview pdf](screenshots/preview.GIF) ![diff with other version](screenshots/diff.GIF)

## Installation

Just put the script in a folder, the script will auto-create a profile folder at the current directory and another configuration folder in a specified project directory.

## Post Install


### Customise the profile & project configuration file

The script maintain default configurations lists for both all projects and each individual project. Extra configurations can be added in the function `init()`.

### Customise the menu and functions

All operations are registered in the function `showMenu()` in the form of `KEY::Function::Description::Menu_level::CAT_ENABLE_DISPLAY`.

### Customise latex engine & bibliography backend

Extra latex engine or bibliography backend can be added either in the list of the function `choose_pdf_compiler` or `choose_ref_compiler`.

### Customise the colour scheme

Colour scheme is maintained by the function `enable_color_theme` and `default_theme`.


## Thanks

Thanks to contributors of the excellent latex system and users using the script.
