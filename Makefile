# rosconf, RouterOS configuration tracker
# https://wiki.mikrotik.com/wiki/Manual:Configuration_Management


-include node.mk

RBNAME?=		router
RBNODE?=		${RBNODE_PREFIX}${RBNAME}
RBNODE_PREFIX?=		./

-include ${RBNODE}.mk

RBNODE_FREF?=		factory
RBNODE_PAGER?=		less -RFX
RBHOST?=		192.168.88.1
RBUSER?=		admin
RBUSER_PUBKEY?=		id_rsa.pub
RBUSER_SET?=		${RBUSER}
RBPASS_SET?=		${RBUSER}
RBFILTER_PULL?=		unix ros-comment ovpn-mac
RBFILTER_PUSH?=		dos


all: pull ${RBNODE}.hostkey-rsa ${RBNODE}.rsc

pull: ${RBNODE}.export,n
pull: ${RBNODE}.export-verbose,n


#
# unmodified ("raw") exports

${RBNODE}.export,r:
	ssh ${RBUSER}@${RBHOST} /export >$@

${RBNODE}.export-verbose,r:
	ssh ${RBUSER}@${RBHOST} /export verbose >$@

#
# filtered ("reproducible") exports

${RBNODE}.export,f:         ${RBNODE}.export,r
${RBNODE}.export-verbose,f: ${RBNODE}.export-verbose,r

${RBNODE}.export,f ${RBNODE}.export-verbose,f:
	cp $< $@
	set -e; for i in ${RBFILTER_PULL}; do \
		sed -rf lib/sed.$$i -i $@; done

#
# normalised ("joined") exports

${RBNODE}.export,n:         ${RBNODE}.export,f
${RBNODE}.export-verbose,n: ${RBNODE}.export-verbose,f

${RBNODE}.export,n ${RBNODE}.export-verbose,n:
	lib/normalise $< >$@



${RBNODE}.hostkey-rsa:
	ssh-keygen -t rsa -N '' -C $@ -f $@
	rm $@.pub

${RBNODE}.rsc: ${RBNODE}.export,f
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
	cat $< >>$@
	set -e; for i in ${RBFILTER_PUSH}; do \
		sed -rf lib/sed.$$i -i $@; done

push: ${RBUSER_PUBKEY} ${RBNODE}.hostkey-rsa ${RBNODE}.rsc
	scp ${RBUSER_PUBKEY} ${RBUSER}@${RBHOST}:flash/${RBUSER_SET}.pubkey
	scp ${RBNODE}.hostkey-rsa ${RBUSER}@${RBHOST}:flash/${RBNAME}.key
	scp ${RBNODE}.rsc ${RBUSER}@${RBHOST}:flash/${RBNAME}.rsc

reset: push
	ssh ${RBUSER}@${RBHOST} /system reset-configuration \
		no-defaults=yes \
		skip-backup=yes \
		run-after-reset=flash/${RBNAME}.rsc

shutdown reboot:; ssh ${RBUSER}@${RBHOST} /system $@


# show word-diff of normalised export against tagged node config
wdiff:;  git -C ${RBNODE_PREFIX} diff --color-words ${RBNAME} -- \
	${RBNAME}.export,n ${RBNAME}.export-verbose,n | ${RBNODE_PAGER}

# show word-diff of normalised export against tagged factory default config
fwdiff:; git -C ${RBNODE_PREFIX} diff --color-words ${RBNODE_FREF} -- \
	${RBNAME}.export,n ${RBNAME}.export-verbose,n | ${RBNODE_PAGER}


clean:
	rm -f \
		${RBNODE}.export,f ${RBNODE}.export-verbose,f \
		${RBNODE}.export,n ${RBNODE}.export-verbose,n \

realclean: clean
	rm -f \
		${RBNODE}.export,r ${RBNODE}.export-verbose,r \
		${RBNODE}.rsc


.PHONY: all pull push reset shutdown reboot wdiff fwdiff clean realclean
