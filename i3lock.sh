#!/bin/bash

alpha='dd'
background='#191919'
selection='#404040'
comment='#f8f8f2'

green='#a2f300'
orange='#ffb247'
red='#ff025f'
purple='#9359ff'
blue='#35ddff'
cyan='#67ffeb'

font="Monocraft Nerd Font"
size="24"

i3lock \
  --insidever-color=$selection$alpha \
  --insidewrong-color=$selection$alpha \
  --inside-color=$selection$alpha \
  --ringver-color=$green$alpha \
  --ringwrong-color=$red$alpha \
  --ringver-color=$green$alpha \
  --ringwrong-color=$red$alpha \
  --ring-color=$cyan$alpha \
  --line-uses-ring \
  --keyhl-color=$purple$alpha \
  --bshl-color=$orange$alpha \
  --separator-color=$selection$alpha \
  --verif-color=$green \
  --wrong-color=$red \
  --modif-color=$red \
  --layout-color=$cyan \
  --date-color=$cyan \
  --time-color=$cyan \
  --blur 5 \
  --clock \
  --indicator \
  --time-str="%H:%M" \
  --date-str="%A %e %B %Y" \
  --verif-text="Checking..." \
  --wrong-text="Wrong password" \
  --noinput="No Input" \
  --lock-text="Locking..." \
  --lockfailed="Lock Failed" \
  --radius=250 \
  --ring-width=10 \
  --pass-media-keys \
  --pass-screen-keys \
  --pass-volume-keys \
 --time-font="$font" \
 --date-font="$font" \
 --layout-font="$font" \
 --verif-font="$font" \
 --wrong-font="$font" \
 --time-size="$size" \
 --date-size="$size" \
 --layout-size="$size" \
 --verif-size="$size" \
 --wrong-size="$size" \