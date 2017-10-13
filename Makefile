# rosconf, RouterOS configuration tracker
# https://wiki.mikrotik.com/wiki/Manual:Configuration_Management


-include node.mk

RBNAME?=		router
RBNODE?=		${RBNODE_PREFIX}${RBNAME}
RBNODE_PREFIX?=		./

-include ${RBNODE}.mk

RBNODE_FREF?=		factory
RBNODE_CREF?=		# current ref
RBNODE_PAGER?=		less -RFX
RBHOST?=		192.168.88.1
RBHOST_SET?=		${RBHOST}
RBUSER?=		admin
RBUSER_PUBKEY?=		id_rsa.pub
RBUSER_SET?=		${RBUSER}
RBPASS_SET?=		${RBUSER}

DEF_JOIN_FILTER?=	sort | sed /^\#/d
DEF_PULL_FILTER?=	unix ros-comment ovpn-mac
DEF_PUSH_FILTER?=	dos
DEF_PUSH_APPEND?=	# list of rsc files
DEF_PUSH_PREPEND?=	delay admin hostkey webcert
DEF_PUSH_FILES?=	${RBUSER_PUBKEY} ${RBNODE}.hostkey \
			${RBNODE}.webcert ${RBNODE}.webkey

JOIN_FILTER?=		${DEF_JOIN_FILTER}
PULL_FILTER?=		${DEF_PULL_FILTER}
PUSH_FILTER?=		${DEF_PUSH_FILTER}
PUSH_APPEND?=		${DEF_PUSH_APPEND}
PUSH_PREPEND?=		${DEF_PUSH_PREPEND}
PUSH_FILES?=		${DEF_PUSH_FILES}

# rscat needs all the above
export

# main target
all: pull


${RBNODE}.export:
	ssh ${RBUSER}@${RBHOST} /export >$@
	set -e; for i in ${PULL_FILTER}; do \
		sed -rf lib/sed.$$i -i $@; done
	lib/join $@ | ${JOIN_FILTER} >$@,join

.PHONY: ${RBNODE}.export

${RBNODE}.export-verbose:
	ssh ${RBUSER}@${RBHOST} /export verbose >$@
	set -e; for i in ${PULL_FILTER}; do \
		sed -rf lib/sed.$$i -i $@; done
	lib/join $@ | ${JOIN_FILTER} >$@,join

.PHONY: ${RBNODE}.export-verbose

pull: ${RBNODE}.export
pull: ${RBNODE}.export-verbose


${RBNODE}.hostkey:
	ssh-keygen -t rsa -N '' -C $@ -f $@
	rm $@.pub

${RBNODE}.webcert:
	openssl req -x509 -newkey rsa:2048 -days 3650 -nodes \
		-keyout ${@:cert=key} -out $@ \
		-subj /CN=${RBHOST_SET}

${RBNODE}.webkey: ${RBNODE}.webcert

${RBNODE}.rsc:
	set -e; for i in ${PUSH_PREPEND} ${RBNODE}.export ${PUSH_APPEND}; do \
		lib/rscat $$i; done >$@
	set -e; for i in ${PUSH_FILTER}; do \
		sed -rf lib/sed.$$i -i $@; done

.PHONY: ${RBNODE}.rsc

push: ${PUSH_FILES} ${RBNODE}.rsc
	set -e; for i in $> $^; do \
		scp $$i ${RBUSER}@${RBHOST}:flash/; done
	rm ${RBNODE}.rsc

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
