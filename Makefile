# rosconf, RouterOS configuration tracker
# https://wiki.mikrotik.com/wiki/Manual:Configuration_Management


-include node.mk

RBNAME?=		router
RBNODE?=		${RBNODE_PREFIX}${RBNAME}
RBNODE_PREFIX?=		./

-include ${RBNODE}.mk

RBNODE_FREF?=		factory
RBNODE_CREF?=		# current, empty
RBNODE_PAGER?=		less -RFX
RBHOST?=		192.168.88.1
RBUSER?=		admin
RBUSER_PUBKEY?=		id_rsa.pub
RBUSER_SET?=		${RBUSER}
RBPASS_SET?=		${RBUSER}
RBFILTER_PULL?=		unix ros-comment ovpn-mac
RBFILTER_PUSH?=		dos
JOIN_POSTPROCESS?=	sort | sed /^\#/d

# main target
all: pull


${RBNODE}.export:
	ssh ${RBUSER}@${RBHOST} /export >$@
	set -e; for i in ${RBFILTER_PULL}; do \
		sed -rf lib/sed.$$i -i $@; done
	lib/join $@ | ${JOIN_POSTPROCESS} >$@,join

.PHONY: ${RBNODE}.export

${RBNODE}.export-verbose:
	ssh ${RBUSER}@${RBHOST} /export verbose >$@
	set -e; for i in ${RBFILTER_PULL}; do \
		sed -rf lib/sed.$$i -i $@; done
	lib/join $@ | ${JOIN_POSTPROCESS} >$@,join

.PHONY: ${RBNODE}.export-verbose

pull: ${RBNODE}.export
pull: ${RBNODE}.export-verbose


${RBNODE}.hostkey-rsa:
	ssh-keygen -t rsa -N '' -C $@ -f $@
	rm $@.pub

${RBNODE}.export,push:
	@#
	@# On Thu, Jun 20, 2013, normis wrote:
	@# > yes, [run-after-reset script] needs a delay because it is
	@# > trying to do actions with interfaces not yet loaded. there
	@# > is no bug in this case
	@#
	@# https://forum.mikrotik.com/viewtopic.php?t=73663#p374221
	@#
	@echo :delay 5 >$@
	@echo /ip ssh import-host-key private-key-file=flash/${RBNAME}.key >>$@
	@echo /user set admin name=${RBUSER_SET} password=${RBPASS_SET} >>$@
	@echo /user ssh-keys import public-key-file=flash/${RBUSER_SET}.pubkey user=${RBUSER_SET} >>$@
	cat ${@:,push=} >>$@
	set -e; for i in ${RBFILTER_PUSH}; do \
		sed -rf lib/sed.$$i -i $@; done

.PHONY: ${RBNODE}.export,push

push: ${RBUSER_PUBKEY} ${RBNODE}.hostkey-rsa ${RBNODE}.export,push
	scp ${RBUSER_PUBKEY} ${RBUSER}@${RBHOST}:flash/${RBUSER_SET}.pubkey
	scp ${RBNODE}.hostkey-rsa ${RBUSER}@${RBHOST}:flash/${RBNAME}.key
	scp ${RBNODE}.export,push ${RBUSER}@${RBHOST}:flash/${RBNAME}.rsc
	rm ${RBNODE}.export,push

reset: push
	ssh ${RBUSER}@${RBHOST} /system reset-configuration \
		no-defaults=yes skip-backup=yes \
		run-after-reset=flash/${RBNAME}.rsc

shutdown reboot:; ssh ${RBUSER}@${RBHOST} /system $@


# show word-diff of joined export
wdiff:; git -C ${RBNODE_PREFIX} diff --color-words ${RBNODE_CREF} -- \
	${RBNAME}.export,join ${RBNAME}.export-verbose,join | ${RBNODE_PAGER}

# show factory word-diff of joined export
fwdiff:; git -C ${RBNODE_PREFIX} diff --color-words ${RBNODE_FREF} -- \
	${RBNAME}.export,join ${RBNAME}.export-verbose,join | ${RBNODE_PAGER}
