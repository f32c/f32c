# Diamond for Linux (Debian)

installing diamond on debian linux is possible
with some patching, after original installation RPM
s converted to DEB with "alien" command and installed,
it won't work.

All #!/bin/sh should be changed to #!/bin/bash
and all tar.gz should be unpacked where they are
and then probably deleted to save space.

Here are some scipts to automate this process,
but read them, edit and don't let them
rm -rf something important...
