.include "constants.s"

.global BEGIN
BEGIN:
	movia   r8, LASTCMD									# After ENTER rewrite these addresses

/* Space to store last command */
LASTCMD:
.skip 0x100