# Makefile for building gated.

GBUILD=@GTWSGBUILD@

IVERSION:=$(strip $(shell basename ${PWD}))
GVERSION:=$(strip $(shell basename $(shell dirname ${PWD})))

all: developer

developer:
	@$(GBUILD) -parallel=12 -DNO_VALS -DGATED_DEBUG -DCHECK_GATED -top pcx86/default.gpj gated-developer-dd

qdeveloper:
	@$(GBUILD) -parallel=12 -DNO_VALS -DGATED_DEBUG -top pcx86/default.gpj gated-developer-dd

userspace:
	@$(GBUILD) -parallel=12 -DNO_VALS -DGATED_DEBUG -DCHECK_GATED -top pcx86/default.gpj gated-userspace

quserspace:
	@$(GBUILD) -parallel=12 -DNO_VALS -DGATED_DEBUG -top pcx86/default.gpj gated-userspace

ikernel:
	@$(GBUILD) -parallel=12 -DNO_VALS -DGATED_DEBUG -DCHECK_GATED -top pcx86/default.gpj kernel

kernelspace:
	@$(GBUILD) -parallel=12 -DNO_VALS -DGATED_DEBUG -DCHECK_GATED -top pcx86/default.gpj gated-kernelspace

integrity:
	@$(GBUILD) -parallel=12 -DNO_VALS -DGATED_DEBUG -DCHECK_GATED -top pcx86/default.gpj

qintegrity:
	@$(GBUILD) -parallel=12 -DNO_VALS -DGATED_DEBUG -top pcx86/default.gpj

linux:
	@$(GBUILD) -parallel=12 -DCHECK_GATED -top modules/ghs/gated/gated-linux.gpj

qlinux:
	@$(GBUILD) -parallel=12 -top modules/ghs/gated/gated-linux.gpj

test:
	@(cd modules/ghs/gated; $(MAKE) $@) || exit 5

docs:
	@dmltools/builddocset gated_products

docclean:
	@rm */*.html */*.dmltag */*.hhc */*.hhk */*.ltx */*.oht */*.tit */*.pdf */*.tex */*.png

clean:
	@$(GBUILD) -parallel=12 -DNO_VALS -DGATED_DEBUG -top pcx86/default.gpj libgated.gpj libcligated.gpj libhal.gpj libamiclient.gpj liballoc.gpj libcontainers.gpj libgcore.gpj libtrace.gpj libgaddr.gpj -clean

boot: ikernel quserspace kernelspace
	scp bin/pcx86/kernel bin/pcx86/gated-userspace bin/pcx86/gated-kernelspace tftp:/tftpboot/dang/$(GVERSION)/$(IVERSION)/

cf4:
	@/share/tools/vmdk/provision cf4-host.aa.ghs.com cf4-boxa cf4-boxb cf4-boxc cf4-boxd
