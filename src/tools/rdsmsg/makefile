project=rdsmsg
parser=options
version=$(shell ./version.sh)
debrelease=18
#architecture=i386
#architecture=amd64
architecture=$(shell dpkg-architecture -qDEB_BUILD_ARCH)

package=$(project)_$(version)-$(debrelease)_$(architecture).deb

CLIBS= # -llockdev -lpthread -lbluetooth # -lhid
CFLAGS=-Wall -std=gnu99 -g -Os # -lm

debianproject=debian/usr/bin/$(project)
# debian parts that can be erased and rebuilt
debianparts=$(debianproject) debian/DEBIAN/control debian/usr/share/doc/$(project)/changelog.gz

rds=rds
objects=$(project).o $(parser).o $(rds).o
includes=$(parser).h
message=../../../rtl/soc/fm/message.vhd

all: $(project)

$(parser).c: $(parser).ggo
	gengetopt < $< --file-name=$(parser) --unamed-opts="TEXT"

$(parser).h: $(parser).ggo
	gengetopt < $< --file-name=$(parser) --unamed-opts="TEXT"

$(parser).o: $(parser).c $(parser).h
	gcc $(CFLAGS) -c $(parser).c # -DHAVE_CONFIG_H

$(rds).o: $(rds).c $(rds).h
	gcc $(CFLAGS) -c $(rds).c

$(project).o: $(project).c $(includes)
	gcc $(CFLAGS) -c $(project).c

$(project): $(objects)
	gcc $(CFLAGS) $(CLIBS) $(objects) -o $@

message: $(message)
$(message): $(project)
	./rdsmsg -i 0xCAFE --af=107.9 --ps="TEST1234" --rt="ABCDEFGHIJKLMNOPQRSTUVWXYZ    ABCDEFGHIJKLMNOPQRSTUVWXYZ    1234" > $@

$(debianproject): $(project)
	strip $< -o $@
	chmod og+rx $@

debian/usr/share/doc/$(project)/changelog.gz: changelog
	gzip -9 < $< > $@
	chmod og+r $@

#debian/control: control cmdline.ggo
#	sed \
#	   -e "s/VERSION/$(version)-$(debrelease)/" \
#	   -e "s/ARCHITECTURE/$(architecture)/" \
#	   control > $@

debian/DEBIAN/control: control cmdline.ggo
	sed \
	   -e "s/VERSION/$(version)-$(debrelease)/" \
	   -e "s/ARCHITECTURE/$(architecture)/" \
	   control > $@
	chmod 0644 $@

$(package): $(debianparts)
	#find debian -type f -exec chmod 0644 '{}' \;
	#find debian -type d -exec chmod 0755 '{}' \;
	#find debian/etc/bluenear -type f -exec chmod a+x '{}' \;
	find debian -name "*~" -exec rm -f {} \;
	#find debian/usr/bin -type f -exec chmod +x '{}' \;
	find debian/usr/share/doc -type f -exec chmod 0644 '{}' \;
	fakeroot dpkg-deb --build debian $(package)

package: $(package)
	lintian $<

run: $(project)
	./$< --device /dev/rfcomm23

clean:
	rm -f $(project) $(objects) $(parser).c $(parser).h $(package) $(debianparts) *~
