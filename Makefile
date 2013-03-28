# Makefile for building gated.

GBUILD=@GTWSGBUILD@

IVERSION:=$(strip $(shell basename ${PWD}))
GVERSION:=$(strip $(shell basename $(shell dirname ${PWD})))
ifeq ($(wildcard bin/@GTWSBSP@),)
	IBINPATH=@GTWSBSP@
else
	IBINPATH=bin/@GTWSBSP@
endif

all: userspace

developer:
	@$(GBUILD) -parallel=12 -DNO_VALS -DGATED_DEBUG -DCHECK_GATED -top @GTWSBSP@/default.gpj gated-developer-dd

qdeveloper:
	@$(GBUILD) -parallel=12 -DNO_VALS -DGATED_DEBUG -top @GTWSBSP@/default.gpj gated-developer-dd

userspace:
	@$(GBUILD) -parallel=12 -DNO_VALS -DGATED_DEBUG -DCHECK_GATED -top @GTWSBSP@/default.gpj gated-userspace

quserspace:
	@$(GBUILD) -parallel=12 -DNO_VALS -DGATED_DEBUG -top @GTWSBSP@/default.gpj gated-userspace

ikernel:
	@$(GBUILD) -parallel=12 -DNO_VALS -DGATED_DEBUG -DCHECK_GATED -top @GTWSBSP@/default.gpj kernel

kernelspace:
	@$(GBUILD) -parallel=12 -DNO_VALS -DGATED_DEBUG -DCHECK_GATED -top @GTWSBSP@/default.gpj gated-kernelspace

integrity:
	@$(GBUILD) -parallel=12 -DNO_VALS -DGATED_DEBUG -DCHECK_GATED -top @GTWSBSP@/default.gpj

qintegrity:
	@$(GBUILD) -parallel=12 -DNO_VALS -DGATED_DEBUG -top @GTWSBSP@/default.gpj

linux:
	@$(GBUILD) -parallel=12 -DCHECK_GATED -top modules/ghs/gated/gated-linux.gpj

qlinux:
	@$(GBUILD) -parallel=12 -top modules/ghs/gated/gated-linux.gpj

test:
	@(cd modules/ghs/gated; $(MAKE) $@) || exit 5

docs:
	@(cd ../docs; dmltools/builddocset gated_products)

docclean:
	@(cd ../docs; rm */*.html */*.dmltag */*.hhc */*.hhk */*.ltx */*.oht */*.tit */*.pdf */*.tex */*.png)

clean:
	@$(GBUILD) -top @GTWSBSP@/default.gpj -clean
	@rm -rf bin libs

boot: userspace
	gt-boot -r $(r) -- $(IBINPATH)/gated-userspace

cf4:
	@/share/tools/vmdk/provision cf4-host.aa.ghs.com cf4-boxa cf4-boxb cf4-boxc cf4-boxd
