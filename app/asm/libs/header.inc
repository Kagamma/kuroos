org 0x08048000
use32

; KOS header executable (24 bytes).
    db    'K32',0                    ; Header.
    dd    1                          ; Version
    dd    image_end - 0x08048000     ; Image size.
    dd    0x400                      ; Stack size.
    dd    code_section               ; entry point
    dd    0                          ; Icon location.