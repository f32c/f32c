#
# MAKEFILES environment variable MUST point to the f32c/src/conf/f32c.mk file
# when invoking GNU make!
#

BASE_DIR = $(subst conf/f32c.mk,,${MAKEFILES})

LIBS_MK = $(join ${BASE_DIR},conf/libs.mk)
POST_MK = $(join ${BASE_DIR},conf/post.mk)
