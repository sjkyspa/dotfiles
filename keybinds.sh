#! /bin/bash


# TODO ??ds
# Make caps lock button generate caps lock when tapped or alt gr when held
# xcape_str=$xcape_str''
# or dollar maybe? &? smart depending on emacs mode?
# bind super keys as well? Figure out how to get alt gr to bind keys?


# Reset to standard keyboard layout (just in case...)
setxkbmap gb
killall xcape

# Keyboard map to force myself to press the right shift buttons
xmodmap ~/Dropbox/linux_setup/rcfiles/keyboard_force_correct_hands.xmm

# Make alt gr just normal alt:
xmodmap -e "clear mod5"
xmodmap -e "add mod2 = 0xfe03"


# String ready to store out xcape commands (so that we only run it once)
xcape_str=""


# # *Space to ctrl*
# # Map a new (currently non-existant) keysym to the spacebar's
# # keycode and make it a control modifier.
# xmodmap -e 'keycode 65 = 0x1234'
# xmodmap -e 'add control = 0x1234'

# # Map space to a new keycode which has no corresponding key (to
# # keep it around for xcape to use).
# xmodmap -e 'keycode any = space'

# # Finally use xcape to cause our new keysym to generate a space
# # when tapped.
# xcape_str=$xcape_str'#65=space;'

# Use keycodes for xcape keys so that rebinding those buttons doesn't break
# things, for example in keyboard_force_correct_hands.sh.

# Tapping shift buttons generates ( or ).
xcape_str=$xcape_str'#50=parenleft;'
xcape_str=$xcape_str'#62=parenright;'

# Tapping ctrl buttons generates " and _. ??ds use mode_switch key here if
# we use keyboard_force_correct_hands.sh, otherwise need to manually swap
# it to Shift_R!
xcape_str=$xcape_str'#37=Mode_switch|quotedbl;'
xcape_str=$xcape_str'#105=Shift_L|underscore;'

# TODO ??ds
# Make caps lock button generate caps lock when tapped or alt gr when held
# xcape_str=$xcape_str''


# # Symbols bound to something else using xcape, so don't press them!
# xmodmap -e "keysym 9 = 9 $UbKS $UBKS $UBKS"
# xmodmap -e "keysym 0 = 0 $UBKS $UBKS $UBKS"
# xmodmap -e "keysym minus = minus $UBKS $UBKS $UBKS"
# xmodmap -e "keysym 2 = 2 $UBKS $UBKS $UBKS"


# Execute all the xcape stuff we just set up:
$HOME/code/xcape/xcape -e $xcape_str
